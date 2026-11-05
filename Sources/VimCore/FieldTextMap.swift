import Foundation

/// Rebuilds a field's real text for the engine and translates its offsets to caret positions.
/// Slack's caret positions skip line breaks and emoji, so the caret text alone can't give lines:
/// they come from the Accessibility tree, or failing that from AXValue, which shows emoji as newlines.
public struct FieldTextMap: Sendable {
  public let text: String
  private let caretForOffset: [Int]

  public init(axValue: String, caretText: String) {
    // A lone newline is how Slack reports a field that was emptied, from both sources.
    let value = axValue == "\n" ? [] : Array(axValue.utf16)
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
      // A guess for when no tree is available: an odd count reads as one real line break. Slack's
      // real counts vary with an emoji's neighbours, which is why the tree comes first.
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

  /// Nil unless the lines account for every caret position, so a tree that doesn't match falls back
  /// to the two-source reconcile.
  public init?(lines: [String], caretText: String) {
    let caret = Array(caretText.utf16)
    let newline = UInt16(0x0A)
    // How Slack reports an emptied field, or one holding only an emoji.
    if lines == [""] {
      guard caret.allSatisfy({ $0 == newline }), caret.count <= 1 else { return nil }
      text = ""
      caretForOffset = [0]
      return
    }
    var units: [UInt16] = []
    var carets: [Int] = []
    var caretIndex = 0
    var endCaret: Int?
    for (lineIndex, line) in lines.enumerated() {
      let isLast = lineIndex == lines.count - 1
      for unit in line.utf16 {
        guard caretIndex < caret.count, caret[caretIndex] == unit else { return nil }
        units.append(unit)
        carets.append(caretIndex)
        caretIndex += 1
      }
      if !isLast {
        units.append(newline)
        carets.append(caretIndex)
      }
      // Only a blank line takes a caret position of its own. A last one reads as the position
      // before its newline, the same as the line end above it.
      if line.isEmpty, caretIndex < caret.count, caret[caretIndex] == newline {
        caretIndex += 1
        if isLast { endCaret = caretIndex - 1 }
      }
    }
    guard caretIndex == caret.count else { return nil }
    text = String(utf16CodeUnits: units, count: units.count)
    caretForOffset = carets + [endCaret ?? caretIndex]
  }

  public var caretLength: Int { caretForOffset.last ?? 0 }

  public func caret(forOffset offset: Int) -> Int {
    caretForOffset[max(0, min(offset, caretForOffset.count - 1))]
  }

  /// A line's end and the next line's start share a caret position; this picks the next line's start.
  public func offset(forCaret caret: Int) -> Int {
    caretForOffset.lastIndex { $0 <= caret } ?? 0
  }

  /// True at a line's end whose caret position is the same as the next line's start.
  public func sharesCaretWithNextLine(_ offset: Int) -> Bool {
    guard offset >= 0, offset + 1 < caretForOffset.count else { return false }
    return (text as NSString).character(at: offset) == 0x0A && caretForOffset[offset] == caretForOffset[offset + 1]
  }

  /// The end of the previous line, when `offset` is a line start that shares its caret with it.
  public func lineEnd(sharingCaretWith offset: Int) -> Int? {
    sharesCaretWithNextLine(offset - 1) ? offset - 1 : nil
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
