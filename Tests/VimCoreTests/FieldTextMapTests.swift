import Foundation
import Testing

@testable import VimCore

// Inputs are shapes captured from real Slack drafts, except where a test says otherwise.

@Test func consecutiveLinesGetTheirLineBreaksBack() {
  let map = FieldTextMap(axValue: "one\ntwo\nsix", caretText: "onetwosix")
  #expect(map.text == "one\ntwo\nsix")
}

@Test func offsetsTranslateAcrossALineBreakCaretsSkip() {
  let map = FieldTextMap(axValue: "one\ntwo", caretText: "onetwo")
  #expect(map.caret(forOffset: 5) == 4)
  #expect(map.offset(forCaret: 4) == 5)
  #expect(map.caretRange(forRange: NSRange(location: 4, length: 3)) == NSRange(location: 3, length: 3))
}

@Test func aLineEndAndTheNextLineStartShareACaretAndReadAsTheStart() {
  let map = FieldTextMap(axValue: "one\ntwo", caretText: "onetwo")
  #expect(map.caret(forOffset: 3) == 3)
  #expect(map.caret(forOffset: 4) == 3)
  #expect(map.offset(forCaret: 3) == 4)
}

@Test func anEmojiMidLineIsNotALineBreak() {
  let map = FieldTextMap(axValue: "hello @rob \n\n there", caretText: "hello @rob  there")
  #expect(map.text == "hello @rob  there")
  #expect(map.caret(forOffset: 12) == 12)
}

@Test func aBlankLineIsANewlineInBothSources() {
  let map = FieldTextMap(axValue: "six\nhere", caretText: "six\nhere")
  #expect(map.text == "six\nhere")
  #expect(map.caret(forOffset: 4) == 4)
}

@Test func anEmojiBeforeABlankLineLeavesOneLineBreak() {
  let map = FieldTextMap(axValue: "one\ntwo \n\nsix", caretText: "onetwo \nsix")
  #expect(map.text == "one\ntwo \nsix")
  #expect(map.caret(forOffset: 9) == 8)
}

// Assumed, not captured: an emoji at a line end with no blank line after it.
@Test func anEmojiAtALineEndKeepsTheLineBreak() {
  let map = FieldTextMap(axValue: "one\n\n\ntwo", caretText: "onetwo")
  #expect(map.text == "one\ntwo")
}

@Test func anEmptyFieldHasOneCaretPosition() {
  let map = FieldTextMap(axValue: "", caretText: "")
  #expect(map.text == "")
  #expect(map.caret(forOffset: 0) == 0)
  #expect(map.offset(forCaret: 0) == 0)
}
