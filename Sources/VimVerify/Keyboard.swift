@preconcurrency import CoreGraphics
import Foundation

/// There's deliberately no plain Return here: it would send the message.
enum Key {
  case character(Character)
  case escape
  case softNewline
  case selectAll
  case delete
  case controlA
  case newDocument

  /// `<esc>` is Escape, `<c-a>` is Ctrl-A and a newline is Shift-Return; everything else is typed as itself.
  static func parse(_ text: String) -> [Key] {
    let tokens = text.replacingOccurrences(of: "<esc>", with: "\u{1B}").replacingOccurrences(of: "<c-a>", with: "\u{1}")
    return tokens.map { character in
      switch character {
      case "\u{1B}": .escape
      case "\u{1}": .controlA
      case "\n": .softNewline
      default: .character(character)
      }
    }
  }
}

struct Keyboard {
  // Must differ from vim-mode's own tag, or its tap would let these through unhandled.
  static let driverEventTag: Int64 = 0x7665_7269
  private static let secondsBetweenKeys = 0.03

  let beforeEachKey: () throws -> Void

  func press(_ keys: [Key]) throws {
    for key in keys {
      try beforeEachKey()
      post(key)
      Thread.sleep(forTimeInterval: Self.secondsBetweenKeys)
    }
  }

  private func post(_ key: Key) {
    switch key {
    case .character(let character): post(keyCode: 0, characters: String(character))
    case .escape: post(keyCode: 53)
    case .softNewline: post(keyCode: 36, flags: .maskShift)
    case .selectAll: post(keyCode: 0, flags: .maskCommand)
    case .delete: post(keyCode: 51)
    case .controlA: post(keyCode: 0, flags: .maskControl)
    case .newDocument: post(keyCode: 45, flags: .maskCommand)
    }
  }

  private func post(keyCode: CGKeyCode, flags: CGEventFlags = [], characters: String? = nil) {
    for isKeyDown in [true, false] {
      guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: isKeyDown) else { continue }
      event.flags = flags
      if let characters {
        let units = Array(characters.utf16)
        event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
      }
      event.setIntegerValueField(.eventSourceUserData, value: Self.driverEventTag)
      event.post(tap: .cghidEventTap)
    }
  }
}

/// Notices Rob using the machine, so a run stops instead of mixing his input with the test's.
/// Physical events carry no user data, while the driver's and vim-mode's own are tagged.
final class UserInputWatch: @unchecked Sendable {
  private let lock = NSLock()
  private var interrupted = false

  var wasInterrupted: Bool { lock.withLock { interrupted } }

  fileprivate func markInterrupted() {
    lock.withLock { interrupted = true }
  }

  func start() throws {
    let mask = CGEventMask(
      1 << CGEventType.keyDown.rawValue | 1 << CGEventType.leftMouseDown.rawValue | 1 << CGEventType.rightMouseDown.rawValue)
    guard
      let port = CGEvent.tapCreate(
        tap: .cghidEventTap, place: .headInsertEventTap, options: .listenOnly,
        eventsOfInterest: mask, callback: userInputCallback, userInfo: Unmanaged.passUnretained(self).toOpaque())
    else { throw Abort("couldn't watch for keyboard input") }
    let source = CFMachPortCreateRunLoopSource(nil, port, 0)
    Thread.detachNewThread {
      CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
      CFRunLoopRun()
    }
  }
}

private func userInputCallback(
  proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  if event.getIntegerValueField(.eventSourceUserData) == 0, let userInfo {
    Unmanaged<UserInputWatch>.fromOpaque(userInfo).takeUnretainedValue().markInterrupted()
  }
  return Unmanaged.passUnretained(event)
}
