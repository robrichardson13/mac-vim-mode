import CoreGraphics

/// Slack reports no width for a caret in text, about a square for an emoji, and the whole line's
/// width for a caret on an empty line, so width alone doesn't mean an emoji.
public func caretCoversEmoji(width: CGFloat, height: CGFloat) -> Bool {
  width > 0 && width <= height * 1.5
}
