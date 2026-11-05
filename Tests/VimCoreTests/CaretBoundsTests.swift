import Testing

@testable import VimCore

@Test func anEmojiSizedCaretCoversAnEmoji() {
  #expect(caretCoversEmoji(width: 25, height: 25))
}

@Test func aCaretInTextDoesNotCoverAnEmoji() {
  #expect(!caretCoversEmoji(width: 0, height: 21))
}

@Test func aLineWideCaretOnAnEmptyLineDoesNotCoverAnEmoji() {
  #expect(!caretCoversEmoji(width: 900, height: 25))
}
