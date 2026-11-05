import Foundation

enum CharacterClass {
  case whitespace, word, punctuation
}

extension VimBuffer {
  /// Resolves a motion key to a target offset, or nil when the key isn't a motion.
  func motionTarget(_ key: String, from start: Int, count: Int, explicitCount: Bool) -> Int? {
    var index = start
    switch key {
    case "h":
      let lineStart = lineRange(at: index).lowerBound
      for _ in 0..<count { index = max(previousCharacter(before: index), lineStart) }
    case "l":
      let end = lineEnd(at: index)
      for _ in 0..<count { index = min(nextCharacter(after: index), end) }
    case "0": index = lineRange(at: index).lowerBound
    case "^": index = firstNonBlank(at: index)
    case "$": index = lastCharacter(at: index)
    case "j", "k":
      for _ in 0..<count { index = logicalLineStep(from: index, down: key == "j") }
    // Bare `G` is the end of the text; `<count>G` is that line, so `1G` reaches the top like `gg`.
    case "G": index = explicitCount ? firstNonBlank(at: lineStart(line: count)) : length
    case "w", "W":
      for _ in 0..<count { index = wordForward(from: index, bigWord: key == "W") }
    case "b", "B":
      for _ in 0..<count { index = wordBackward(from: index, bigWord: key == "B") }
    case "e", "E":
      for _ in 0..<count { index = wordEnd(from: index, bigWord: key == "E") }
    default: return nil
    }
    return index
  }

  /// The word under the cursor. `around` adds trailing whitespace, or leading when there is none.
  func wordObject(at index: Int, bigWord: Bool, around: Bool) -> NSRange {
    let line = lineRange(at: index)
    let end = lineEnd(at: index)
    guard index < end else { return NSRange(location: index, length: 0) }
    let target = characterClass(at: index, bigWord: bigWord)

    var low = index
    while low > line.lowerBound, characterClass(at: low - 1, bigWord: bigWord) == target { low -= 1 }
    var high = index
    while high < end, characterClass(at: high, bigWord: bigWord) == target { high += 1 }
    guard around else { return NSRange(location: low, length: high - low) }

    let wordEnd = high
    while high < end, characterClass(at: high, bigWord: bigWord) == .whitespace { high += 1 }
    if high == wordEnd {
      while low > line.lowerBound, characterClass(at: low - 1, bigWord: bigWord) == .whitespace { low -= 1 }
    }
    return NSRange(location: low, length: high - low)
  }

  func isWhitespace(at index: Int) -> Bool {
    index < length && characterClass(at: index, bigWord: false) == .whitespace
  }

  private func logicalLineStep(from index: Int, down: Bool) -> Int {
    let line = text.lineRange(for: NSRange(location: min(index, length), length: 0))
    let column = index - line.location
    if down {
      guard NSMaxRange(line) < length else { return index }
      let next = text.lineRange(for: NSRange(location: NSMaxRange(line), length: 0))
      return min(next.location + column, max(next.location, NSMaxRange(next) - 1))
    }
    guard line.location > 0 else { return index }
    let previous = text.lineRange(for: NSRange(location: line.location - 1, length: 0))
    return min(previous.location + column, max(previous.location, NSMaxRange(previous) - 1))
  }

  private func characterClass(at index: Int, bigWord: Bool) -> CharacterClass {
    // A surrogate is half of an emoji; UnicodeScalar can't represent it, and it isn't whitespace.
    guard let scalar = UnicodeScalar(text.character(at: index)) else {
      return bigWord ? .word : .punctuation
    }
    let character = Character(scalar)
    if character.isWhitespace { return .whitespace }
    if bigWord { return .word }
    if character.isLetter || character.isNumber || character == "_" { return .word }
    return .punctuation
  }

  private func wordForward(from index: Int, bigWord: Bool) -> Int {
    guard index < length else { return index }
    var i = index
    let startClass = characterClass(at: i, bigWord: bigWord)
    if startClass != .whitespace {
      while i < length, characterClass(at: i, bigWord: bigWord) == startClass { i += 1 }
    }
    while i < length, characterClass(at: i, bigWord: bigWord) == .whitespace { i += 1 }
    return i
  }

  private func wordBackward(from index: Int, bigWord: Bool) -> Int {
    guard index > 0 else { return 0 }
    var i = index - 1
    while i > 0, characterClass(at: i, bigWord: bigWord) == .whitespace { i -= 1 }
    let target = characterClass(at: i, bigWord: bigWord)
    guard target != .whitespace else { return i }
    while i > 0, characterClass(at: i - 1, bigWord: bigWord) == target { i -= 1 }
    return i
  }

  private func wordEnd(from index: Int, bigWord: Bool) -> Int {
    guard index < length else { return index }
    var i = index + 1
    while i < length, characterClass(at: i, bigWord: bigWord) == .whitespace { i += 1 }
    guard i < length else { return max(length - 1, 0) }
    let target = characterClass(at: i, bigWord: bigWord)
    while i + 1 < length, characterClass(at: i + 1, bigWord: bigWord) == target { i += 1 }
    return i
  }

  func firstNonBlank(at index: Int) -> Int {
    let end = lineEnd(at: index)
    var i = lineRange(at: index).lowerBound
    while i < end, characterClass(at: i, bigWord: false) == .whitespace { i += 1 }
    return i
  }

  /// Start offset of the 1-based `line`, clamped to the last line.
  private func lineStart(line: Int) -> Int {
    var offset = 0
    var current = 1
    while current < line {
      let range = text.lineRange(for: NSRange(location: offset, length: 0))
      guard NSMaxRange(range) < length else { return range.location }
      offset = NSMaxRange(range)
      current += 1
    }
    return text.lineRange(for: NSRange(location: min(offset, length), length: 0)).location
  }
}
