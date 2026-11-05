import ApplicationServices
import Foundation

/// Reads an element's text map straight from Accessibility, preferring its tree's real lines.
public func readFieldTextMap(of element: AXUIElement) -> FieldTextMap? {
  AXUIElementSetMessagingTimeout(element, 0.25)
  var value: CFTypeRef?
  guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success,
    let axValue = value as? String
  else { return nil }
  let caretText = readFieldText(upperBound: axValue.utf16.count) { caretString(length: $0, of: element) }
  let tree = readFieldNode(element)
  if let lines = tree.flatMap(fieldLines), let map = FieldTextMap(lines: lines, caretText: caretText) {
    return map
  }
  // Slack means "emptied" by a lone newline, and has a tree. A field without one means a real newline.
  if axValue == "\n", tree?.children.isEmpty == true, let map = FieldTextMap(lines: ["", ""], caretText: caretText) {
    return map
  }
  return FieldTextMap(axValue: axValue, caretText: caretText)
}

private func caretString(length: Int, of element: AXUIElement) -> String? {
  var range = CFRange(location: 0, length: length)
  guard let parameter = AXValueCreate(.cfRange, &range) else { return nil }
  var value: CFTypeRef?
  guard
    AXUIElementCopyParameterizedAttributeValue(
      element, kAXStringForRangeParameterizedAttribute as CFString, parameter, &value) == .success
  else { return nil }
  return value as? String
}

private func readFieldNode(_ element: AXUIElement, depth: Int = 0) -> FieldNode? {
  guard depth < 8 else { return nil }
  AXUIElementSetMessagingTimeout(element, 0.25)
  let names = [kAXRoleAttribute, kAXSubroleAttribute, kAXValueAttribute, kAXChildrenAttribute] as CFArray
  var values: CFArray?
  guard AXUIElementCopyMultipleAttributeValues(element, names, [], &values) == .success,
    let attributes = values as? [Any], attributes.count == 4
  else { return nil }
  var children: [FieldNode] = []
  for child in attributes[3] as? [AXUIElement] ?? [] {
    guard let node = readFieldNode(child, depth: depth + 1) else { return nil }
    children.append(node)
  }
  return FieldNode(
    role: attributes[0] as? String ?? "",
    subrole: attributes[1] as? String ?? "",
    value: attributes[2] as? String ?? "",
    children: children)
}


/// Reads a field's text in caret coordinates. In Slack, AXValue can't be used for this: it shows
/// an emoji as two newlines, while caret positions skip it, so AXValue's length is only an upper
/// bound and asking for more than the real length returns nothing.
public func readFieldText(upperBound: Int, read: (Int) -> String?) -> String {
  guard upperBound > 0 else { return "" }
  if let text = read(upperBound) { return text }
  var best = ""
  var low = 1
  var high = upperBound - 1
  while low <= high {
    let middle = (low + high) / 2
    if let text = read(middle) {
      best = text
      low = middle + 1
    } else {
      high = middle - 1
    }
  }
  return best
}
