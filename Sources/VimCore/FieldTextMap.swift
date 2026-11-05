import Foundation

/// Rebuilds a field's real text for the engine and translates its offsets to caret positions.
/// Slack's caret positions skip line breaks and emoji, so neither source is enough alone: AXValue
/// has the line breaks but also shows an emoji as two newlines, and the caret text has neither.
public struct FieldTextMap: Sendable {
  public let text: String
  private let caretForOffset: [Int]

  public init(axValue: String, caretText: String) {
    let value = Array(axValue.utf16)
    let caret = Array(caretText.utf16)
    let newline = UInt16(0x0A)
    var units: [UInt16] = []
    var carets: [Int] = []
    var valueIndex = 0
    var caretIndex = 0

    while valueIndex < value.count {
      guard value[valueIndex] == newline else {
        if caretIndex < caret.count, value[valueIndex] == caret[caretIndex] {
          units.append(value[valueIndex])
          carets.append(caretIndex)
          caretIndex += 1
        }
        valueIndex += 1
        continue
      }
      var valueRun = 0
      while valueIndex + valueRun < value.count, value[valueIndex + valueRun] == newline { valueRun += 1 }
      var caretRun = 0
      while caretIndex + caretRun < caret.count, caret[caretIndex + caretRun] == newline { caretRun += 1 }

      for offset in 0..<caretRun {
        units.append(newline)
        carets.append(caretIndex + offset)
      }
      // An emoji accounts for two unmatched newlines, so an odd count leaves one real line break.
      if caretRun == 0, !(valueRun - caretRun).isMultiple(of: 2) {
        units.append(newline)
        carets.append(caretIndex)
      }
      valueIndex += valueRun
      caretIndex += caretRun
    }

    text = String(utf16CodeUnits: units, count: units.count)
    caretForOffset = carets + [caretIndex]
  }

  public func caret(forOffset offset: Int) -> Int {
    caretForOffset[max(0, min(offset, caretForOffset.count - 1))]
  }

  /// A line's end and the next line's start share a caret position; this picks the next line's start.
  public func offset(forCaret caret: Int) -> Int {
    caretForOffset.lastIndex { $0 <= caret } ?? 0
  }

  public func range(forCaretRange range: NSRange) -> NSRange {
    let start = offset(forCaret: range.location)
    guard range.length > 0 else { return NSRange(location: start, length: 0) }
    let end = max(start, offset(forCaret: NSMaxRange(range)))
    return NSRange(location: start, length: end - start)
  }

  public func caretRange(forRange range: NSRange) -> NSRange {
    let start = caret(forOffset: range.location)
    return NSRange(location: start, length: caret(forOffset: NSMaxRange(range)) - start)
  }
}
