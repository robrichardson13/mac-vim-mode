import Foundation
import Testing

@testable import VimCore

@Test func aCaretMustLandExactly() {
  let requested = NSRange(location: 5, length: 0)
  #expect(selectionLanded(NSRange(location: 5, length: 0), on: requested))
  #expect(!selectionLanded(NSRange(location: 5, length: 1), on: requested))
}

@Test func aSelectionAcrossAnEmojiReadsBackLonger() {
  let requested = NSRange(location: 35, length: 10)
  #expect(selectionLanded(NSRange(location: 35, length: 11), on: requested))
  #expect(!selectionLanded(NSRange(location: 34, length: 11), on: requested))
  #expect(!selectionLanded(NSRange(location: 35, length: 9), on: requested))
}

@Test func selectionMayIncludeAnEmojiTheTextDoesNotShow() {
  #expect(selectionCovers("rob \u{FFFC} there", expected: "rob  there"))
  #expect(selectionCovers("rob 😄 there", expected: "rob  there"))
  #expect(selectionCovers("there", expected: "there"))
}

@Test func selectionOnTheWrongTextIsRefused() {
  #expect(!selectionCovers("rob xthere", expected: "rob there"))
  #expect(!selectionCovers("the", expected: "there"))
  #expect(!selectionCovers("where", expected: "there"))
}

@Test func selectionComparesAcrossLineBreaksEitherWay() {
  #expect(selectionCovers("onetwo", expected: "one\ntwo"))
  #expect(selectionCovers("one\ntwo", expected: "onetwo"))
}
