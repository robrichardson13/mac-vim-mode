import Foundation

extension VimEngine {
  mutating func enterVisual(_ target: Mode, _ buffer: VimBuffer) {
    visualAnchor = buffer.cursor
    visualHead = visualAnchor
    mode = target
    renderVisualSelection(buffer)
  }

  /// Collapses onto the moving end, which is where vim leaves the cursor.
  mutating func leaveVisual(_ buffer: VimBuffer) {
    mode = .normal
    buffer.setCursor(visualHead)
    buffer.clampCursorOntoCharacter()
  }

  mutating func handleVisual(_ key: String, count: Int, explicitCount: Bool, _ buffer: VimBuffer) {
    switch key {
    case "v": mode == .visual ? leaveVisual(buffer) : enterVisual(.visual, buffer)
    case "V": mode == .visualLine ? leaveVisual(buffer) : enterVisual(.visualLine, buffer)
    case "o":
      swap(&visualAnchor, &visualHead)
      renderVisualSelection(buffer)

    case "d", "x", "y", "c", "s":
      let range = visualRange(buffer)
      let isLinewise = mode == .visualLine
      let op: Operator = key == "y" ? .yank : (key == "d" || key == "x" ? .delete : .change)
      mode = .normal
      perform(op, over: range, linewise: isLinewise, buffer)

    case "p", "P": pasteOverSelection(buffer)

    case "u":
      mode = .normal
      buffer.record(.undo)

    default:
      guard let target = buffer.motionTarget(key, from: visualHead, count: count, explicitCount: explicitCount)
      else { return }
      setVisualHead(target, buffer)
    }
  }

  mutating func setVisualHead(_ index: Int, _ buffer: VimBuffer) {
    visualHead = buffer.snappedToCharacter(index)
    renderVisualSelection(buffer)
  }

  /// Vim's swap: the selection is replaced by the register, and what it replaced becomes the register.
  private mutating func pasteOverSelection(_ buffer: VimBuffer) {
    let range = visualRange(buffer)
    guard !register.isEmpty || registerIsLinewise, range.length > 0 else { return }
    let payload = register
    let body = registerIsLinewise && !payload.hasSuffix("\n") ? payload + "\n" : payload
    yank(buffer.substring(range), linewise: mode == .visualLine)
    mode = .normal
    buffer.replace(range, with: body)
    buffer.setCursor(range.location)
    buffer.clampCursorOntoCharacter()
  }

  /// Inclusive of the character under the moving end charwise; whole lines, newline included, linewise.
  private func visualRange(_ buffer: VimBuffer) -> NSRange {
    let low = min(visualAnchor, visualHead)
    let high = max(visualAnchor, visualHead)
    if mode == .visualLine {
      let start = buffer.lineRange(at: low).lowerBound
      return NSRange(location: start, length: buffer.lineRange(at: high).upperBound - start)
    }
    return NSRange(location: low, length: buffer.nextCharacter(after: high) - low)
  }

  private func renderVisualSelection(_ buffer: VimBuffer) {
    buffer.setSelection(visualRange(buffer))
  }
}
