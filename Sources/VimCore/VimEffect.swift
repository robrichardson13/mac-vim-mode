import Foundation

public struct TextSnapshot: Equatable, Sendable {
  public var text: String
  public var selection: NSRange

  public init(text: String, selection: NSRange) {
    self.text = text
    self.selection = selection
  }
}

/// What the host app must do to the real text field, in order.
public enum VimEffect: Equatable, Sendable {
  case passThrough
  case setSelection(NSRange)
  case replace(NSRange, with: String)
  case moveCaretUp
  case moveCaretDown
  case undo
  case redo
}

public struct VimResult: Equatable, Sendable {
  public let effects: [VimEffect]
  public let snapshot: TextSnapshot
}
