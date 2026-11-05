import CoreGraphics

/// Posts real key events. Tagged so the tap lets our own events through instead of handling them again.
enum Keystrokes {
  enum Key: CGKeyCode {
    case z = 6
    case returnKey = 36
    case delete = 51
    case downArrow = 125
    case upArrow = 126
  }

  static let syntheticEventTag: Int64 = 0x7669_6D6D

  // Explicit flags: otherwise a physically held Shift (from `D` or `X`) merges into the event.
  static func post(_ key: Key, flags: CGEventFlags = []) {
    for isKeyDown in [true, false] {
      guard let event = CGEvent(keyboardEventSource: nil, virtualKey: key.rawValue, keyDown: isKeyDown) else { continue }
      event.flags = flags
      send(event)
    }
  }

  static func post(_ characters: String) {
    let units = Array(characters.utf16)
    for isKeyDown in [true, false] {
      guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: isKeyDown) else { continue }
      event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
      event.flags = []
      send(event)
    }
  }

  /// Hands a captured key to the app unchanged, because it turned out not to be ours.
  static func repost(_ event: CGEvent) {
    send(event)
  }

  private static func send(_ event: CGEvent) {
    event.setIntegerValueField(.eventSourceUserData, value: syntheticEventTag)
    event.post(tap: .cghidEventTap)
  }
}
