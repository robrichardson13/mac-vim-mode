import Foundation

/// Slack's caret positions skip an emoji, but a selection's reported length counts it, so a
/// selection across an emoji reads back longer than the range that was requested.
public func selectionLanded(_ actual: NSRange, on requested: NSRange) -> Bool {
  if requested.length == 0 { return actual == requested }
  return actual.location == requested.location && actual.length >= requested.length
}

/// True when the selection holds exactly the expected text, plus nothing but embedded objects
/// like an emoji. Any extra letter or digit means the selection is on the wrong text.
public func selectionCovers(_ selected: String, expected: String) -> Bool {
  // Slack may or may not report a line break inside a selection.
  var remaining = Substring(expected.filter { $0 != "\n" })
  for character in selected where character != "\n" {
    if character == remaining.first {
      remaining.removeFirst()
    } else if character.isLetter || character.isNumber {
      return false
    }
  }
  return remaining.isEmpty
}

/// True when an edit reached the field. A new blank line doesn't change AXValue, only the caret
/// text, so collapsed text alone would also match an edit that never landed.
public func editLanded(in map: FieldTextMap, expecting target: String, caretLengthBefore: Int) -> Bool {
  if map.text == target { return true }
  guard target.contains("\n\n"), map.caretLength != caretLengthBefore else { return false }
  return map.text == collapsingBlankLines(target)
}

private func collapsingBlankLines(_ text: String) -> String {
  text.replacingOccurrences(of: "\n+", with: "\n", options: .regularExpression)
}
