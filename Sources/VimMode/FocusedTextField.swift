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
    guard let value = copy(kAXValueAttribute) as? String else { return nil }
    let caretText = readFieldText(upperBound: value.utf16.count) { string(in: NSRange(location: 0, length: $0)) }
    return FieldTextMap(axValue: value, caretText: caretText)
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
    return TextSnapshot(text: textMap.text, selection: textMap.range(forCaretRange: caretSelection))
  }

  func setCaretSelection(_ range: NSRange) {
    var cfRange = CFRange(location: range.location, length: range.length)
    guard let value = AXValueCreate(.cfRange, &cfRange) else { return }
    AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, value)
  }

  private func string(in range: NSRange) -> String? {
    var cfRange = CFRange(location: range.location, length: range.length)
    guard let parameter = AXValueCreate(.cfRange, &cfRange) else { return nil }
    var value: CFTypeRef?
    guard
      AXUIElementCopyParameterizedAttributeValue(
        element, kAXStringForRangeParameterizedAttribute as CFString, parameter, &value) == .success
    else { return nil }
    return value as? String
  }

  func copy(_ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
    return value
  }
}
