import Testing

@testable import VimCore

@Test func newlinesNeverTravelAsTextBecauseReturnSendsInSlack() {
  #expect(textKeystrokes(for: "one\ntwo") == [.characters("one"), .softNewline, .characters("two")])
  #expect(textKeystrokes(for: "\n") == [.softNewline])
}

@Test func longTextIsChunkedWithoutSplittingAnEmoji() {
  let text = String(repeating: "a", count: 19) + "😄" + "b"
  #expect(textKeystrokes(for: text) == [.characters(String(repeating: "a", count: 19)), .characters("😄b")])
}
