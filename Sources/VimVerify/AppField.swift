import AppKit
import ApplicationServices
import VimCore

/// The focused text field of one app, read directly from Accessibility.
struct AppField {
  let processIdentifier: pid_t

  var axValue: String {
    Self.attribute(kAXValueAttribute, of: focusedElement) as? String ?? ""
  }

  /// The emptied-field gap reads as one character in Slack, so emptiness allows it.
  var isEmpty: Bool {
    axValue.utf16.count <= 1 && axValue.allSatisfy(\.isNewline)
  }

  /// In the engine's offsets, so scenarios state carets in the text they typed.
  var selection: NSRange {
    let element = focusedElement
    let value = axValue
    let caretText = readFieldText(upperBound: value.utf16.count) { Self.string(in: $0, of: element) }
    return FieldTextMap(axValue: value, caretText: caretText).range(forCaretRange: Self.caretRange(of: element))
  }

  var isFocusedElementATextArea: Bool {
    Self.attribute(kAXRoleAttribute, of: focusedElement) as? String == kAXTextAreaRole
  }

  var focusedElement: AXUIElement? {
    Self.attribute(kAXFocusedUIElementAttribute, of: appElement).map { $0 as! AXUIElement }
  }

  var focusedWindow: AXUIElement? {
    Self.attribute(kAXFocusedWindowAttribute, of: appElement).map { $0 as! AXUIElement }
  }

  var windows: [AXUIElement] {
    Self.attribute(kAXWindowsAttribute, of: appElement) as? [AXUIElement] ?? []
  }

  private var appElement: AXUIElement {
    let element = AXUIElementCreateApplication(processIdentifier)
    AXUIElementSetAttributeValue(element, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    return element
  }

  static func attribute(_ name: String, of element: AXUIElement?) -> CFTypeRef? {
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

// lsappinfo, because NSWorkspace goes stale with no run loop and Accessibility's system-wide
// focused application returns -25204 here.
func focusedAppBundleIdentifier() -> String? {
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
