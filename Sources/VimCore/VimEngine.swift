import Foundation

/// Modal editing as a pure state machine: given a key and the field's current text and
/// selection, it returns the effects the host must apply. It never touches a real field.
public struct VimEngine: Sendable {
  public enum Mode: Sendable {
    case insert, normal, visual, visualLine

    var isVisual: Bool { self == .visual || self == .visualLine }

    public var badge: String? {
      switch self {
      case .insert: nil
      case .normal: "NORMAL"
      case .visual: "VISUAL"
      case .visualLine: "V-LINE"
      }
    }
  }

  enum Operator { case delete, change, yank }

  public static let escape = "\u{1B}"

  public internal(set) var mode: Mode = .insert

  /// Deliberately not the system pasteboard: `y`/`p` must not clobber what ⌘V would paste.
  var register = ""
  var registerIsLinewise = false
  var pendingOperator: Operator?
  var pendingCount: Int?
  var pendingG = false
  var pendingWordObjectIsAround: Bool?
  var visualAnchor = 0
  var visualHead = 0

  public init() {}

  public mutating func resetToInsert() {
    mode = .insert
    resetPending()
  }

  public mutating func handle(key: String, control: Bool = false, in snapshot: TextSnapshot) -> VimResult {
    let buffer = VimBuffer(snapshot)
    // An arrow key from `j` or `k` can leave the real caret past a shorter line's last character.
    if mode == .normal, snapshot.selection.length == 0 { buffer.clampCursorOntoCharacter() }
    dispatch(key, control: control, buffer)
    return VimResult(effects: buffer.effects, snapshot: buffer.snapshot)
  }

  private mutating func dispatch(_ key: String, control: Bool, _ buffer: VimBuffer) {
    if key == Self.escape {
      handleEscape(buffer)
      return
    }
    guard mode != .insert else {
      buffer.record(.passThrough)
      return
    }
    if control {
      buffer.record(key == "r" ? .redo : .passThrough)
      return
    }
    if let isAround = pendingWordObjectIsAround {
      applyWordObject(key, isAround: isAround, buffer)
      return
    }
    if pendingG {
      handleAfterG(key, buffer)
      return
    }
    if let digit = Int(key), digit > 0 || pendingCount != nil {
      pendingCount = (pendingCount ?? 0) * 10 + digit
      return
    }
    if key == "g" {
      pendingG = true
      return
    }
    if mode.isVisual {
      let count = pendingCount ?? 1
      let explicitCount = pendingCount != nil
      resetPending()
      handleVisual(key, count: count, explicitCount: explicitCount, buffer)
      return
    }
    if let pendingOperator {
      applyOperator(pendingOperator, key: key, buffer)
      return
    }
    if let op = operatorForKey(key) {
      pendingOperator = op
      return
    }
    applySimple(key, buffer)
  }

  private mutating func handleEscape(_ buffer: VimBuffer) {
    switch mode {
    case .insert:
      mode = .normal
      stepLeftOutOfInsert(buffer)
    case .visual, .visualLine:
      leaveVisual(buffer)
    case .normal:
      // Swallowed: in Slack it can leave the conversation, and vim users press it out of habit.
      break
    }
    resetPending()
  }

  private func stepLeftOutOfInsert(_ buffer: VimBuffer) {
    guard buffer.selection.length == 0 else {
      buffer.clampCursorOntoCharacter()
      return
    }
    let lineStart = buffer.lineRange(at: buffer.cursor).lowerBound
    buffer.setCursor(max(buffer.previousCharacter(before: buffer.cursor), lineStart))
  }

  private mutating func handleAfterG(_ key: String, _ buffer: VimBuffer) {
    pendingG = false
    guard key == "g" else {
      resetPending()
      return
    }
    if mode.isVisual {
      setVisualHead(0, buffer)
    } else if let pendingOperator {
      let range = NSRange(location: 0, length: buffer.lineRange(at: buffer.cursor).upperBound)
      perform(pendingOperator, over: range, linewise: true, buffer)
    } else {
      buffer.setCursor(0)
    }
    resetPending()
  }

  private mutating func applySimple(_ key: String, _ buffer: VimBuffer) {
    let count = pendingCount ?? 1
    let explicitCount = pendingCount != nil
    resetPending()
    let cursor = buffer.cursor

    switch key {
    case "i": mode = .insert
    case "a":
      buffer.setCursor(min(buffer.nextCharacter(after: cursor), buffer.lineEnd(at: cursor)))
      mode = .insert
    case "I":
      buffer.setCursor(buffer.firstNonBlank(at: cursor))
      mode = .insert
    case "A":
      buffer.setCursor(buffer.lineEnd(at: cursor))
      mode = .insert
    case "o":
      let end = buffer.lineEnd(at: cursor)
      buffer.replace(NSRange(location: end, length: 0), with: "\n")
      mode = .insert
    case "O":
      let start = buffer.lineRange(at: cursor).lowerBound
      buffer.replace(NSRange(location: start, length: 0), with: "\n")
      buffer.setCursor(start)
      mode = .insert

    case "x": deleteForward(count: count, buffer)
    case "X":
      let lineStart = buffer.lineRange(at: cursor).lowerBound
      guard let start = buffer.motionTarget("h", from: cursor, count: count, explicitCount: false),
        start >= lineStart, start < cursor
      else { return }
      let range = NSRange(location: start, length: cursor - start)
      yank(buffer.substring(range), linewise: false)
      buffer.replace(range, with: "")

    case "D": deleteToLineEnd(buffer)
    case "C":
      deleteToLineEnd(buffer, clampingCursor: false)
      mode = .insert
    case "s":
      deleteForward(count: count, buffer, clampingCursor: false)
      mode = .insert
    case "S":
      let start = buffer.lineRange(at: cursor).lowerBound
      let body = NSRange(location: start, length: buffer.lineEnd(at: cursor) - start)
      yank(buffer.substring(body), linewise: false)
      buffer.replace(body, with: "")
      mode = .insert

    case "v": enterVisual(.visual, buffer)
    case "V": enterVisual(.visualLine, buffer)
    case "p", "P": paste(after: key == "p", count: count, buffer)
    case "u": buffer.record(.undo)

    // Arrow keys rather than offsets: only the app knows where a wrapped line breaks.
    case "j": for _ in 0..<count { buffer.record(.moveCaretDown) }
    case "k": for _ in 0..<count { buffer.record(.moveCaretUp) }

    default:
      guard let target = buffer.motionTarget(key, from: cursor, count: count, explicitCount: explicitCount)
      else { return }
      buffer.setCursor(target)
      if key != "$" { buffer.clampCursorOntoCharacter() }
    }
  }

  private func operatorForKey(_ key: String) -> Operator? {
    switch key {
    case "d": .delete
    case "c": .change
    case "y": .yank
    default: nil
    }
  }

  private mutating func applyOperator(_ op: Operator, key: String, _ buffer: VimBuffer) {
    defer { if pendingWordObjectIsAround == nil { resetPending() } }
    if key == "i" || key == "a" {
      pendingWordObjectIsAround = key == "a"
      return
    }
    let cursor = buffer.cursor
    if operatorForKey(key) == op {
      let line = buffer.lineRange(at: cursor)
      // `cc` clears the line but keeps it; `dd`/`yy` take the newline with it.
      let end = op == .change ? buffer.lineEnd(at: cursor) : line.upperBound
      perform(op, over: NSRange(location: line.lowerBound, length: end - line.lowerBound), linewise: op != .change, buffer)
      return
    }
    guard
      let target = buffer.motionTarget(
        key, from: cursor, count: pendingCount ?? 1, explicitCount: pendingCount != nil)
    else { return }
    var end = ["$", "e", "E"].contains(key) ? buffer.nextCharacter(after: target) : target
    // Vim's special case: `cw` on a word stops at the word's end and keeps the space after it.
    if op == .change, key == "w" || key == "W", !buffer.isWhitespace(at: cursor) {
      while end > cursor, buffer.isWhitespace(at: end - 1) { end -= 1 }
    }
    perform(op, over: NSRange(location: min(cursor, end), length: abs(end - cursor)), linewise: false, buffer)
  }

  private mutating func applyWordObject(_ key: String, isAround: Bool, _ buffer: VimBuffer) {
    defer { resetPending() }
    guard key == "w" || key == "W", let pendingOperator else { return }
    let range = buffer.wordObject(at: buffer.cursor, bigWord: key == "W", around: isAround)
    perform(pendingOperator, over: range, linewise: false, buffer)
  }

  mutating func perform(_ op: Operator, over range: NSRange, linewise: Bool, _ buffer: VimBuffer) {
    let isDeletingLastLine = linewise && op == .delete && range.location > 0 && NSMaxRange(range) == buffer.length
    guard range.length > 0 || op == .change || isDeletingLastLine else { return }
    yank(buffer.substring(range), linewise: linewise)
    switch op {
    case .yank:
      buffer.setCursor(range.location)
    case .delete where linewise:
      // The last line has no newline of its own, so it takes the one before it.
      let lines = isDeletingLastLine ? NSRange(location: range.location - 1, length: range.length + 1) : range
      buffer.replace(lines, with: "")
      buffer.setCursor(buffer.firstNonBlank(at: min(lines.location, buffer.length)))
    case .delete:
      buffer.replace(range, with: "")
      buffer.clampCursorOntoCharacter()
    case .change:
      buffer.replace(range, with: "")
      mode = .insert
    }
  }

  private mutating func deleteForward(count: Int, _ buffer: VimBuffer, clampingCursor: Bool = true) {
    let cursor = buffer.cursor
    let end = buffer.motionTarget("l", from: cursor, count: count, explicitCount: false) ?? cursor
    let range = NSRange(location: cursor, length: end - cursor)
    guard range.length > 0 else { return }
    yank(buffer.substring(range), linewise: false)
    buffer.replace(range, with: "")
    if clampingCursor { buffer.clampCursorOntoCharacter() }
  }

  private mutating func deleteToLineEnd(_ buffer: VimBuffer, clampingCursor: Bool = true) {
    let cursor = buffer.cursor
    let range = NSRange(location: cursor, length: buffer.lineEnd(at: cursor) - cursor)
    guard range.length > 0 else { return }
    yank(buffer.substring(range), linewise: false)
    buffer.replace(range, with: "")
    if clampingCursor { buffer.clampCursorOntoCharacter() }
  }

  mutating func yank(_ string: String, linewise: Bool) {
    register = string
    registerIsLinewise = linewise
  }

  private func paste(after: Bool, count: Int, _ buffer: VimBuffer) {
    guard !register.isEmpty else { return }
    let payload = String(repeating: register, count: count)
    let cursor = buffer.cursor
    if registerIsLinewise {
      let line = buffer.lineRange(at: cursor)
      var at = after ? line.upperBound : line.lowerBound
      var body = payload.hasSuffix("\n") ? payload : payload + "\n"
      // The last line has no newline to paste after, so the new line brings its own in front.
      if after, line.upperBound == buffer.length, buffer.lineEnd(at: cursor) == line.upperBound {
        at = line.upperBound
        body = "\n" + body.dropLast()
        buffer.replace(NSRange(location: at, length: 0), with: body)
        buffer.setCursor(at + 1)
        return
      }
      buffer.replace(NSRange(location: at, length: 0), with: body)
      buffer.setCursor(at)
      return
    }
    let at = after ? min(buffer.nextCharacter(after: cursor), buffer.lineEnd(at: cursor)) : cursor
    buffer.replace(NSRange(location: at, length: 0), with: payload)
    buffer.setCursor(at + (payload as NSString).length - 1)
  }

  mutating func resetPending() {
    pendingOperator = nil
    pendingCount = nil
    pendingG = false
    pendingWordObjectIsAround = nil
  }
}
