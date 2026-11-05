import Foundation

/// The field's text as the engine sees it while handling one key: edits apply here
/// immediately and are recorded as effects for the host to replay on the real field.
final class VimBuffer {
  private(set) var text: NSString
  private(set) var selection: NSRange
  private(set) var effects: [VimEffect] = []

  init(_ snapshot: TextSnapshot) {
    text = snapshot.text as NSString
    selection = snapshot.selection
  }

  var snapshot: TextSnapshot { TextSnapshot(text: text as String, selection: selection) }
  var length: Int { text.length }
  var cursor: Int { selection.location }

  func record(_ effect: VimEffect) {
    effects.append(effect)
  }

  func setCursor(_ index: Int) {
    setSelection(NSRange(location: snappedToCharacter(index), length: 0))
  }

  func setSelection(_ range: NSRange) {
    guard range != selection else { return }
    selection = range
    if case .setSelection = effects.last { effects.removeLast() }
    effects.append(.setSelection(range))
  }

  /// Leaves the caret right after the new text, which is where typing leaves it in the real field.
  func replace(_ range: NSRange, with string: String) {
    guard range.length > 0 || !string.isEmpty else { return }
    let edited = NSMutableString(string: text)
    edited.replaceCharacters(in: range, with: string)
    text = edited
    selection = NSRange(location: range.location + (string as NSString).length, length: 0)
    effects.append(.replace(range, with: string))
  }

  func substring(_ range: NSRange) -> String {
    text.substring(with: range)
  }

  func snappedToCharacter(_ index: Int) -> Int {
    let clamped = max(0, min(index, length))
    guard clamped < length else { return clamped }
    return text.rangeOfComposedCharacterSequence(at: clamped).location
  }

  func nextCharacter(after index: Int) -> Int {
    guard index < length else { return length }
    return NSMaxRange(text.rangeOfComposedCharacterSequence(at: index))
  }

  func previousCharacter(before index: Int) -> Int {
    guard index > 0 else { return 0 }
    return text.rangeOfComposedCharacterSequence(at: min(index, length) - 1).location
  }

  /// The full line under `index`, newline included.
  func lineRange(at index: Int) -> Range<Int> {
    let range = text.lineRange(for: NSRange(location: max(0, min(index, length)), length: 0))
    return range.location..<NSMaxRange(range)
  }

  /// End of the line's content, before its newline.
  func lineEnd(at index: Int) -> Int {
    let line = lineRange(at: index)
    let hasNewline = line.upperBound > line.lowerBound && text.character(at: line.upperBound - 1) == 0x0A
    return hasNewline ? line.upperBound - 1 : line.upperBound
  }

  func lastCharacter(at index: Int) -> Int {
    let line = lineRange(at: index)
    let end = lineEnd(at: index)
    return end > line.lowerBound ? previousCharacter(before: end) : line.lowerBound
  }

  /// Vim's cursor sits on a character, so it never rests past the last one of a line.
  func clampCursorOntoCharacter() {
    let limit = lastCharacter(at: cursor)
    if cursor > limit { setCursor(limit) }
  }
}
