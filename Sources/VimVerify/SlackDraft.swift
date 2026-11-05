import AppKit
import ApplicationServices
import VimCore

/// Rob's self-DM message box, read directly from Accessibility. Every key the driver posts is
/// gated on `confirmSelfDMIsFocused`, because anywhere else a test could reach a real person.
struct SlackDraft {
  static let bundleIdentifier = "com.tinyspeck.slackmacgap"
  private static let selfDMWindowTitle = "rob (DM) - Rob Richardson - Slack"

  static func confirmedEmpty() throws -> SlackDraft {
    try confirmSelfDMIsFocused()
    let draft = SlackDraft()
    // Never overwrite a draft Rob is writing. An emoji-only draft reads as two newlines, so it fails this too.
    guard draft.isEmpty else { throw Abort("the self-DM has a draft; clear it first") }
    return draft
  }

  static func confirmSelfDMIsFocused() throws {
    guard focusedAppBundleIdentifier() == bundleIdentifier else { throw Abort("Slack isn't frontmost") }
    let title = attribute(kAXTitleAttribute, of: focusedWindow()) as? String
    guard title == selfDMWindowTitle else { throw Abort("Slack isn't showing the self-DM; open it first") }
    guard attribute(kAXRoleAttribute, of: focusedElement()) as? String == kAXTextAreaRole else {
      throw Abort("the self-DM message box isn't focused; click into it first")
    }
  }

  // lsappinfo, because NSWorkspace goes stale with no run loop and Accessibility's system-wide
  // focused application returns -25204 here.
  static func focusedAppBundleIdentifier() -> String? {
    let lookup = Process()
    let output = Pipe()
    lookup.executableURL = URL(fileURLWithPath: "/bin/sh")
    lookup.arguments = ["-c", "lsappinfo info -only bundleid \"$(lsappinfo front)\""]
    lookup.standardOutput = output
    guard (try? lookup.run()) != nil else { return nil }
    lookup.waitUntilExit()
    let line = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    return line.split(separator: "\"").last { !$0.contains("CFBundleIdentifier") && !$0.contains("=") && !$0.contains("\n") }.map(String.init)
  }

  var axValue: String {
    Self.attribute(kAXValueAttribute, of: Self.focusedElement()) as? String ?? ""
  }

  /// The emptied-field gap reads as one character, so emptiness allows it.
  var isEmpty: Bool {
    axValue.utf16.count <= 1 && axValue.allSatisfy(\.isNewline)
  }

  /// In the engine's offsets, so scenarios state carets in the text they typed.
  var selection: NSRange {
    let element = Self.focusedElement()
    let value = axValue
    let caretText = readFieldText(upperBound: value.utf16.count) { Self.string(in: $0, of: element) }
    return FieldTextMap(axValue: value, caretText: caretText).range(forCaretRange: Self.caretRange(of: element))
  }

  private static func slackElement() -> AXUIElement? {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else { return nil }
    let element = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetAttributeValue(element, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    return element
  }

  private static func focusedElement() -> AXUIElement? {
    attribute(kAXFocusedUIElementAttribute, of: slackElement()).map { $0 as! AXUIElement }
  }

  private static func focusedWindow() -> AXUIElement? {
    attribute(kAXFocusedWindowAttribute, of: slackElement()).map { $0 as! AXUIElement }
  }

  private static func attribute(_ name: String, of element: AXUIElement?) -> CFTypeRef? {
    guard let element else { return nil }
    AXUIElementSetMessagingTimeout(element, 0.25)
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value
  }

  private static func caretRange(of element: AXUIElement?) -> NSRange {
    guard let value = attribute(kAXSelectedTextRangeAttribute, of: element) else { return NSRange(location: 0, length: 0) }
    var range = CFRange()
    AXValueGetValue(value as! AXValue, .cfRange, &range)
    return NSRange(location: range.location, length: range.length)
  }

  private static func string(in length: Int, of element: AXUIElement?) -> String? {
    guard let element else { return nil }
    var range = CFRange(location: 0, length: length)
    guard let parameter = AXValueCreate(.cfRange, &range) else { return nil }
    var value: CFTypeRef?
    guard
      AXUIElementCopyParameterizedAttributeValue(
        element, kAXStringForRangeParameterizedAttribute as CFString, parameter, &value) == .success
    else { return nil }
    return value as? String
  }
}
