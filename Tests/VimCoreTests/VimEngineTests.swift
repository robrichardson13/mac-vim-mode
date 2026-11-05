import Foundation
import Testing

@testable import VimCore

/// A field the tests drive like the host app does: each key sees the text the last key left.
private struct Field {
  var engine = VimEngine()
  var snapshot: TextSnapshot
  var lastEffects: [VimEffect] = []

  init(_ text: String, at cursor: Int, normal: Bool = true) {
    snapshot = TextSnapshot(text: text, selection: NSRange(location: cursor, length: 0))
    guard normal else { return }
    press(VimEngine.escape)
    // Escape steps left; tests state the cursor they want in normal mode.
    snapshot.selection = NSRange(location: cursor, length: 0)
  }

  mutating func press(_ key: String, control: Bool = false) {
    let result = engine.handle(key: key, control: control, in: snapshot)
    snapshot = result.snapshot
    lastEffects = result.effects
  }

  mutating func type(_ keys: String) {
    for key in keys { press(String(key)) }
  }

  var text: String { snapshot.text }
  var cursor: Int { snapshot.selection.location }
  var selection: NSRange { snapshot.selection }
}

@Test func escapeEntersNormalAndStepsOntoACharacter() {
  var field = Field("hello", at: 5, normal: false)
  #expect(field.engine.mode == .insert)
  field.press(VimEngine.escape)
  #expect(field.engine.mode == .normal)
  #expect(field.cursor == 4)
}

@Test func escapeStepsLeftInTheMiddleOfALine() {
  var field = Field("one two", at: 3, normal: false)
  field.press(VimEngine.escape)
  #expect(field.cursor == 2)
}

@Test func escapeStaysPutAtALineStart() {
  var first = Field("one", at: 0, normal: false)
  first.press(VimEngine.escape)
  #expect(first.cursor == 0)
  #expect(first.lastEffects == [])

  var second = Field("one\ntwo", at: 4, normal: false)
  second.press(VimEngine.escape)
  #expect(second.cursor == 4)
}

@Test func escapeStepsOverAWholeEmoji() {
  var field = Field("a😀", at: 3, normal: false)
  field.press(VimEngine.escape)
  #expect(field.cursor == 1)
}

@Test func insertModePassesKeysThrough() {
  var field = Field("hello", at: 0)
  field.type("ix")
  #expect(field.lastEffects == [.passThrough])
  #expect(field.text == "hello")
}

@Test func escapeInNormalModeStaysInVimMode() {
  var field = Field("stable", at: 0)
  field.press(VimEngine.escape)
  #expect(field.lastEffects == [])
  #expect(field.engine.mode == .normal)
}

@Test func unknownNormalKeysAndReturnAreSwallowed() {
  var field = Field("stable", at: 0)
  for key in ["z", "\r", "\t"] {
    field.press(key)
    #expect(field.lastEffects.isEmpty)
  }
  #expect(field.text == "stable")
}

@Test func controlRRedoesAndOtherControlKeysPassThrough() {
  var field = Field("stable", at: 0)
  field.press("r", control: true)
  #expect(field.lastEffects == [.redo])
  field.press("n", control: true)
  #expect(field.lastEffects == [.passThrough])
}

@Test func undoIsAnEffectForTheApp() {
  var field = Field("stable", at: 0)
  field.type("u")
  #expect(field.lastEffects == [.undo])
}

@Test func verticalMovesUseArrowsSoWrappedLinesWork() {
  var field = Field("one long wrapped line", at: 3)
  field.type("2j")
  #expect(field.lastEffects == [.moveCaretDown, .moveCaretDown])
  field.type("k")
  #expect(field.lastEffects == [.moveCaretUp])
}

@Test func zeroThenCapitalDClearsTheLine() {
  var field = Field("fix the tpyo here", at: 12)
  field.type("0D")
  #expect(field.text == "")
}

@Test func motions() {
  var field = Field("foo.bar baz", at: 0)
  field.type("w")
  #expect(field.cursor == 3)
  field.type("w")
  #expect(field.cursor == 4)
  field.type("w")
  #expect(field.cursor == 8)
  field.type("b")
  #expect(field.cursor == 4)
  field.type("$")
  #expect(field.cursor == 10)
  field.type("0")
  #expect(field.cursor == 0)
  field.type("W")
  #expect(field.cursor == 8)
}

@Test func endOfWordMotion() {
  var field = Field("alpha beta", at: 0)
  field.type("e")
  #expect(field.cursor == 4)
  field.type("e")
  #expect(field.cursor == 9)
}

@Test func caretMovesToFirstNonBlank() {
  var field = Field("    indented", at: 10)
  field.type("0")
  #expect(field.cursor == 0)
  field.type("^")
  #expect(field.cursor == 4)
}

@Test func countedGAndBareG() {
  var field = Field("one\ntwo\nthree", at: 5)
  field.type("1G")
  #expect(field.cursor == 0)
  field.type("2G")
  #expect(field.cursor == 4)
  field.type("G")
  #expect(field.cursor == 12)
  field.type("9G")
  #expect(field.cursor == 8)
}

@Test func xDeletesAndClampsAtLineEnd() {
  var field = Field("abc", at: 2)
  field.type("x")
  #expect(field.text == "ab")
  #expect(field.cursor == 1)
}

@Test func deleteWord() {
  var field = Field("delete this word", at: 7)
  field.type("dw")
  #expect(field.text == "delete word")
  #expect(field.lastEffects == [.replace(NSRange(location: 7, length: 5), with: "")])
}

@Test func changeWordKeepsTheFollowingSpaceLikeVim() {
  var field = Field("change this word", at: 7)
  field.type("cw")
  #expect(field.text == "change  word")
  #expect(field.engine.mode == .insert)
}

@Test func deleteToEndOfWordIsInclusive() {
  var field = Field("alpha beta", at: 0)
  field.type("de")
  #expect(field.text == " beta")
}

@Test func countsMultiplyMotionsAndOperators() {
  var moved = Field("one two three four", at: 0)
  moved.type("3w")
  #expect(moved.cursor == 14)

  var deleted = Field("one two three four", at: 0)
  deleted.type("d2w")
  #expect(deleted.text == "three four")
}

@Test func changeInnerWordFromTheMiddleOfAWord() {
  var field = Field("fix the tpyo here", at: 9)
  field.type("ciw")
  #expect(field.text == "fix the  here")
  #expect(field.cursor == 8)
  #expect(field.engine.mode == .insert)
}

@Test func deleteAroundWordTakesTheTrailingSpace() {
  var field = Field("fix the tpyo here", at: 5)
  field.type("daw")
  #expect(field.text == "fix tpyo here")
}

@Test func deleteAroundLastWordTakesTheLeadingSpace() {
  var field = Field("fix here", at: 5)
  field.type("daw")
  #expect(field.text == "fix")
}

@Test func yankInnerWordThenPaste() {
  var field = Field("alpha beta", at: 2)
  field.type("yiw$p")
  #expect(field.text == "alpha betaalpha")
}

@Test func ddRemovesTheWholeLine() {
  var field = Field("first\nsecond\nthird", at: 8)
  field.type("dd")
  #expect(field.text == "first\nthird")
}

@Test func yankLineThenPasteBelow() {
  var field = Field("one\ntwo", at: 0)
  field.type("yyp")
  #expect(field.text == "one\none\ntwo")
}

@Test func yankLastLineThenPasteBelowAddsItsOwnNewline() {
  var field = Field("one", at: 0)
  field.type("yyp")
  #expect(field.text == "one\none")
  #expect(field.cursor == 4)
}

@Test func characterwiseYankAndPaste() {
  var field = Field("abc", at: 0)
  field.type("y$$p")
  #expect(field.text == "abcabc")
}

@Test func openLineAboveAndBelowInsertANewlineEffect() {
  var below = Field("one", at: 1)
  below.type("o")
  #expect(below.text == "one\n")
  #expect(below.cursor == 4)
  #expect(below.engine.mode == .insert)

  var above = Field("one", at: 1)
  above.type("O")
  #expect(above.text == "\none")
  #expect(above.cursor == 0)
}

@Test func visualCharwiseChangeReplacesTheSelection() {
  var field = Field("fix the tpyo", at: 8)
  field.type("vll")
  #expect(field.engine.mode == .visual)
  #expect(field.selection == NSRange(location: 8, length: 3))
  field.type("c")
  #expect(field.engine.mode == .insert)
  #expect(field.text == "fix the o")
}

@Test func visualLineSelectsWholeLinesAndDeletesThem() {
  var field = Field("one\ntwo\nthree", at: 5)
  field.type("V")
  #expect(field.selection == NSRange(location: 4, length: 4))
  field.type("j")
  #expect(field.selection == NSRange(location: 4, length: 9))
  field.type("d")
  #expect(field.text == "one\n")
  #expect(field.engine.mode == .normal)
}

@Test func escapeLeavesVisualWithoutChangingText() {
  var field = Field("hello world", at: 0)
  field.type("vw")
  field.press(VimEngine.escape)
  #expect(field.engine.mode == .normal)
  #expect(field.text == "hello world")
  #expect(field.selection == NSRange(location: 6, length: 0))
}

@Test func visualPasteSwapsTheRegister() {
  var field = Field("alpha beta", at: 0)
  field.type("yw")
  field.type("wvep")
  #expect(field.text == "alpha alpha ")
}

@Test func charactersMoveOverAnEmojiInOneStep() {
  var field = Field("a😄b", at: 0)
  field.type("l")
  #expect(field.cursor == 1)
  field.type("l")
  #expect(field.cursor == 3)
  field.type("h")
  #expect(field.cursor == 1)
}

@Test func xDeletesAWholeEmoji() {
  var field = Field("a😄b", at: 1)
  field.type("x")
  #expect(field.text == "ab")
}

@Test func wordMotionTreatsAnEmojiAsAWordNotWhitespace() {
  var field = Field("hi 😄 there", at: 0)
  field.type("w")
  #expect(field.cursor == 3)
  field.type("w")
  #expect(field.cursor == 6)
}

@Test func editsRecordOnlyTheFinalSelection() {
  var field = Field("alpha beta gamma", at: 0)
  field.type("wwb")
  #expect(field.lastEffects == [.setSelection(NSRange(location: 6, length: 0))])
}

@Test func normalModeActsOnTheLastCharacterWhenAnArrowLeftTheCaretPastIt() {
  var field = Field("ab\nzz", at: 0)
  field.snapshot.selection = NSRange(location: 2, length: 0)
  field.press("x")
  #expect(field.text == "a\nzz")
}
