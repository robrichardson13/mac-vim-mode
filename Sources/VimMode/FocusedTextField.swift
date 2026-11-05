import ApplicationServices
import VimCore

/// The focused text field of an app, read and moved through Accessibility.
/// Success codes aren't evidence here: Slack reports success on writes it ignores.
@MainActor
struct FocusedTextField {
  let element: AXUIElement

  static func current(inProcess processIdentifier: pid_t) -> FocusedTextField? {
    let app = AXUIElementCreateApplication(processIdentifier)
    AXUIElementSetMessagingTimeout(app, 0.25)
    var focused: CFTypeRef?
    guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
      let focused, CFGetTypeID(focused) == AXUIElementGetTypeID()
    else { return nil }
    let element = focused as! AXUIElement
    AXUIElementSetMessagingTimeout(element, 0.25)
    let field = FocusedTextField(element: element)
    guard field.isEditableText else { return nil }
    return field
  }

  private var isEditableText: Bool {
    let role = copy(kAXRoleAttribute) as? String
    guard role == kAXTextAreaRole || role == kAXTextFieldRole else { return false }
    return (copy(kAXSubroleAttribute) as? String) != kAXSecureTextFieldSubrole
  }

  func isSameField(as other: FocusedTextField?) -> Bool {
    guard let other else { return false }
    return CFEqual(element, other.element)
  }

  var textMap: FieldTextMap? {
    readFieldTextMap(of: element)
  }

  var axValueLength: Int {
    (copy(kAXValueAttribute) as? String)?.utf16.count ?? -1
  }

  var selectedText: String? {
    copy(kAXSelectedTextAttribute) as? String
  }

  var caretSelection: NSRange? {
    guard let value = copy(kAXSelectedTextRangeAttribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    var range = CFRange()
    guard AXValueGetValue(value as! AXValue, .cfRange, &range) else { return nil }
    return NSRange(location: range.location, length: range.length)
  }

  var snapshot: TextSnapshot? {
    guard let textMap, let caretSelection else { return nil }
    var selection = textMap.range(forCaretRange: caretSelection)
    if selection.length == 0, isCaretPastLineStart, let lineEnd = textMap.lineEnd(sharingCaretWith: selection.location) {
      selection.location = lineEnd
    }
    return TextSnapshot(text: textMap.text, selection: selection)
  }

  func setCaretSelection(_ range: NSRange) {
    var cfRange = CFRange(location: range.location, length: range.length)
    guard let value = AXValueCreate(.cfRange, &cfRange) else { return }
    AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, value)
  }

  func copy(_ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
    return value
  }
}
