import Foundation

public enum TextKeystroke: Equatable, Sendable {
  case characters(String)
  case softNewline
}

/// Splits text into events the host can post. A newline must never be posted as text or
/// Return: in Slack that sends the message, so it becomes a soft newline (Shift-Return).
public func textKeystrokes(for text: String) -> [TextKeystroke] {
  var keystrokes: [TextKeystroke] = []
  for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
    if index > 0 { keystrokes.append(.softNewline) }
    keystrokes += characterChunks(of: String(line)).map(TextKeystroke.characters)
  }
  return keystrokes
}

/// A keyboard event carries at most 20 UTF-16 units, and a split emoji would corrupt.
private func characterChunks(of line: String) -> [String] {
  let maximumUnits = 20
  var chunks: [String] = []
  var current = ""
  for character in line {
    if current.utf16.count + character.utf16.count > maximumUnits {
      chunks.append(current)
      current = ""
    }
    current.append(character)
  }
  if !current.isEmpty { chunks.append(current) }
  return chunks
}
