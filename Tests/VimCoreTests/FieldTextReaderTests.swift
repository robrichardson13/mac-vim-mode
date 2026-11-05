import Testing

@testable import VimCore

private func reader(for text: String) -> (Int) -> String? {
  { length in length <= text.utf16.count ? String(text.prefix(length)) : nil }
}

@Test func readsTextShorterThanTheUpperBound() {
  #expect(readFieldText(upperBound: 19, read: reader(for: "hello @rob  thYre")) == "hello @rob  thYre")
}

@Test func readsTextExactlyAtTheUpperBound() {
  #expect(readFieldText(upperBound: 5, read: reader(for: "hello")) == "hello")
}

@Test func aFieldWithOnlyAnEmojiReadsAsEmpty() {
  #expect(readFieldText(upperBound: 2, read: reader(for: "")) == "")
}

@Test func anEmptyFieldNeverReads() {
  #expect(readFieldText(upperBound: 0, read: { _ in Issue.record("read an empty field"); return nil }) == "")
}
