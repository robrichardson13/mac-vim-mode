import Testing

@testable import VimCore

private func text(_ value: String) -> FieldNode { FieldNode(role: "AXStaticText", value: value) }
private let emoji = FieldNode(role: "AXImage")
private func paragraph(_ children: FieldNode...) -> FieldNode { FieldNode(role: "AXGroup", children: children) }
private func field(_ children: FieldNode...) -> FieldNode { FieldNode(role: "AXTextArea", children: children) }

// The shapes below are as measured in Slack 4.52.155.
@Test func anEmojiMidLineStaysOnOneLine() {
  #expect(fieldLines(in: field(paragraph(text("a"), emoji, text("b")))) == ["ab"])
}

@Test func anEmojiAtALineEndKeepsItsLineBreak() {
  #expect(fieldLines(in: field(paragraph(text("a"), emoji), paragraph(text("b")))) == ["a", "b"])
}

@Test func anEmptyGroupIsABlankLine() {
  #expect(fieldLines(in: field(paragraph(text("a")), FieldNode(role: "AXGroup"), paragraph(text("b")))) == ["a", "", "b"])
}

@Test func aLineOfOnlyAnEmojiIsAnEmptyLine() {
  #expect(fieldLines(in: field(paragraph(text("a")), paragraph(emoji))) == ["a", ""])
}

@Test func aLinkStaysInItsLine() {
  let link = FieldNode(role: "AXLink", children: [text("b")])
  #expect(fieldLines(in: field(paragraph(text("a "), link, text(" c")))) == ["a b c"])
}

@Test func inlineCodeStaysInItsLine() {
  let code = FieldNode(role: "AXGroup", subrole: "AXCodeStyleGroup", children: [text("a")])
  #expect(fieldLines(in: field(paragraph(code, text(" b")))) == ["a b"])
}

@Test func aFieldWithNoChildrenHasNoLines() {
  #expect(fieldLines(in: FieldNode(role: "AXTextArea", value: "a\nb")) == nil)
}
