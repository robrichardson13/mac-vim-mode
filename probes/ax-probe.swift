// Reports whether the focused text field of the frontmost app can support vim motions.
// Prints lengths and ranges only, never field contents, except --map, which prints the draft's code points.
//
//   swiftc -o /tmp/ax-probe probes/ax-probe.swift
//   /tmp/ax-probe                # 5s to focus a text field, then read-only
//   /tmp/ax-probe --write-test   # also moves the caret one character and puts it back
//   /tmp/ax-probe --walk         # steps the caret through the field, then restores it
//   /tmp/ax-probe --edit-test    # inserts and deletes "X", then leaves a "Y" in the draft
//   /tmp/ax-probe --keystroke-test  # tries AXReplaceRangeWithText, then real Delete and typing
//   /tmp/ax-probe --map          # read-only: compares AXValue with AXStringForRange, prints code points
import AppKit
import ApplicationServices

let isWriteTest = CommandLine.arguments.contains("--write-test")
let isWalk = CommandLine.arguments.contains("--walk")
let isEditTest = CommandLine.arguments.contains("--edit-test")
let isKeystrokeTest = CommandLine.arguments.contains("--keystroke-test")
let isMap = CommandLine.arguments.contains("--map")

guard AXIsProcessTrusted() else {
  print("Not trusted: grant Accessibility to the app running this binary, then relaunch that app.")
  exit(1)
}

print("Focus a text field with text in it. Reading in 5 seconds...")
Thread.sleep(forTimeInterval: 5)

guard let app = NSWorkspace.shared.frontmostApplication else {
  print("No frontmost app.")
  exit(1)
}
print("App: \(app.bundleIdentifier ?? "unknown")")

let appElement = AXUIElementCreateApplication(app.processIdentifier)
// Chromium builds its accessibility tree lazily; this is Electron's documented opt-in.
let manualResult = AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
print("AXManualAccessibility set: \(manualResult == .success ? "yes" : "no (\(manualResult.rawValue))")")
Thread.sleep(forTimeInterval: 1)

guard let field = focusedElement(of: appElement) else {
  print("VERDICT: no focused element exposed. Only keyboard-remap vim is possible here.")
  exit(0)
}
report(field)

func focusedElement(of appElement: AXUIElement) -> AXUIElement? {
  var value: CFTypeRef?
  let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &value)
  guard result == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
  return (value as! AXUIElement)
}

func report(_ field: AXUIElement) {
  let textLength = (copy(field, kAXValueAttribute) as? String)?.utf16.count
  let selection = selectedRange(of: field)

  print("Role: \(copy(field, kAXRoleAttribute) as? String ?? "none") / \(copy(field, kAXSubroleAttribute) as? String ?? "none")")
  print("Value readable: \(textLength.map { "yes, \($0) UTF-16 units" } ?? "no")")
  print("Selection readable: \(selection.map { "yes, location \($0.location) length \($0.length)" } ?? "no")")
  print("Value settable: \(isSettable(field, kAXValueAttribute))")
  print("Selection settable: \(isSettable(field, kAXSelectedTextRangeAttribute))")
  print("Selected text settable: \(isSettable(field, kAXSelectedTextAttribute))")
  print("Parameterized attributes: \(parameterizedAttributes(of: field).joined(separator: ", "))")

  if isWriteTest, let selection { runCaretWriteTest(field, from: selection, textLength: textLength ?? 0) }
  if isWalk, let selection { runCaretWalk(field, restoringTo: selection, textLength: textLength ?? 0) }
  if isEditTest, let selection { runEditTest(field, at: selection.location, textLength: textLength ?? 0) }
  if isKeystrokeTest, let selection { runKeystrokeTest(field, at: selection.location) }
  if isMap { printOffsetMap(field, textLength: textLength ?? 0) }
}

func runCaretWriteTest(_ field: AXUIElement, from original: CFRange, textLength: Int) {
  guard textLength > 0 else {
    print("Caret write test skipped: the field is empty.")
    return
  }
  let target = CFRange(location: original.location > 0 ? original.location - 1 : 1, length: 0)
  let writeResult = setSelectedRange(of: field, to: target)
  Thread.sleep(forTimeInterval: 0.2)
  let landed = selectedRange(of: field)
  _ = setSelectedRange(of: field, to: original)
  print("Caret write: result \(writeResult.rawValue), asked for \(target.location), landed on \(landed.map { String($0.location) } ?? "unreadable")")
}

// "aligned" compares AXStringForRange with AXValue, which diverge if rich text shifts offsets.
func runCaretWalk(_ field: AXUIElement, restoringTo original: CFRange, textLength: Int) {
  let value = (copy(field, kAXValueAttribute) as? String ?? "") as NSString
  print("index landed aligned rangeBounds line caretMarkerBounds")
  for index in 0..<textLength {
    _ = setSelectedRange(of: field, to: CFRange(location: index, length: 0))
    Thread.sleep(forTimeInterval: 0.4)
    let landed = selectedRange(of: field).map { String($0.location) } ?? "unreadable"
    let isAligned = string(of: field, at: index) == value.substring(with: NSRange(location: index, length: 1))
    let bounds = characterBounds(of: field, at: index)
    let line = lineNumber(of: field, at: index).map(String.init) ?? "none"
    print("\(index) \(landed) \(isAligned) \(describe(bounds)) \(line) \(describe(caretMarkerBounds(of: field)))")
  }
  _ = setSelectedRange(of: field, to: original)
}

func runEditTest(_ field: AXUIElement, at location: Int, textLength: Int) {
  let insertResult = setSelectedText(of: field, to: "X")
  Thread.sleep(forTimeInterval: 2)
  print("Insert X: result \(insertResult.rawValue), length \(textLength) -> \(currentLength(of: field))")

  _ = setSelectedRange(of: field, to: CFRange(location: location, length: 1))
  let deleteResult = setSelectedText(of: field, to: "")
  Thread.sleep(forTimeInterval: 1)
  print("Delete X: result \(deleteResult.rawValue), length now \(currentLength(of: field))")

  let keepResult = setSelectedText(of: field, to: "Y")
  print("Insert Y, left in the draft: result \(keepResult.rawValue), length now \(currentLength(of: field))")
}

func runKeystrokeTest(_ field: AXUIElement, at location: Int) {
  let replaceResult = replaceRange(of: field, at: location, with: "R")
  Thread.sleep(forTimeInterval: 1)
  print("AXReplaceRangeWithText R: result \(replaceResult.rawValue), length now \(currentLength(of: field))")

  let lengthBeforeDelete = currentLength(of: field)
  let target = max(min(location, lengthBeforeDelete - 1), 0)
  _ = setSelectedRange(of: field, to: CFRange(location: target, length: 1))
  Thread.sleep(forTimeInterval: 1)
  print("Selected one character at \(target): selection reads \(selectedRange(of: field).map { "\($0.location),\($0.length)" } ?? "unreadable")")

  guard isFrontmost(app) else {
    print("Slack lost focus, so no keystrokes were sent.")
    return
  }
  let deleteKeyCode: CGKeyCode = 51
  postKey(deleteKeyCode)
  Thread.sleep(forTimeInterval: 0.5)
  print("Real Delete: length \(lengthBeforeDelete) -> \(currentLength(of: field))")

  guard isFrontmost(app) else {
    print("Slack lost focus, so Y was not typed.")
    return
  }
  postText("Y")
  Thread.sleep(forTimeInterval: 0.5)
  print("Real typing of Y, left in the draft: length now \(currentLength(of: field))")
}

func isFrontmost(_ app: NSRunningApplication) -> Bool {
  NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier
}

func postKey(_ keyCode: CGKeyCode) {
  CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)?.post(tap: .cghidEventTap)
  CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)?.post(tap: .cghidEventTap)
}

func postText(_ text: String) {
  let units = Array(text.utf16)
  for isKeyDown in [true, false] {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: isKeyDown)
    event?.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
    event?.post(tap: .cghidEventTap)
  }
}

func replaceRange(of field: AXUIElement, at location: Int, with text: String) -> AXError {
  var range = CFRange(location: location, length: 0)
  guard let rangeValue = AXValueCreate(.cfRange, &range) else { return .failure }
  var result: CFTypeRef?
  return AXUIElementCopyParameterizedAttributeValue(
    field, "AXReplaceRangeWithText" as CFString, [rangeValue, text as CFString] as CFArray, &result)
}

func lineNumber(of field: AXUIElement, at index: Int) -> Int? {
  var value: CFTypeRef?
  let result = AXUIElementCopyParameterizedAttributeValue(
    field, kAXLineForIndexParameterizedAttribute as CFString, index as CFNumber, &value)
  return result == .success ? value as? Int : nil
}

func caretMarkerBounds(of field: AXUIElement) -> CGRect {
  var bounds = CGRect.zero
  guard let markerRange = copy(field, "AXSelectedTextMarkerRange") else { return bounds }
  var value: CFTypeRef?
  let result = AXUIElementCopyParameterizedAttributeValue(
    field, "AXBoundsForTextMarkerRange" as CFString, markerRange, &value)
  guard result == .success, let value, CFGetTypeID(value) == AXValueGetTypeID() else { return bounds }
  AXValueGetValue(value as! AXValue, .cgRect, &bounds)
  return bounds
}

func describe(_ bounds: CGRect) -> String {
  "\(Int(bounds.minX)),\(Int(bounds.minY)),\(Int(bounds.width))x\(Int(bounds.height))"
}

func printOffsetMap(_ field: AXUIElement, textLength: Int) {
  let value = copy(field, kAXValueAttribute) as? String ?? ""
  print("AXValue code points: \(codePoints(value))")
  print("AXNumberOfCharacters: \((copy(field, kAXNumberOfCharactersAttribute) as? Int).map(String.init) ?? "none")")
  print("AXSelectedText code points: \((copy(field, kAXSelectedTextAttribute) as? String).map(codePoints) ?? "none")")
  print("AXStringForRange of whole field: \(wholeFieldString(field, upperBound: textLength).map(codePoints) ?? "none")")
  print("index stringForRange")
  for index in 0..<textLength {
    print("\(index) \(string(of: field, at: index).map(codePoints) ?? "none")")
  }
}

func wholeFieldString(_ field: AXUIElement, upperBound: Int) -> String? {
  var length = upperBound
  while length > 0 {
    var range = CFRange(location: 0, length: length)
    guard let parameter = AXValueCreate(.cfRange, &range) else { return nil }
    var value: CFTypeRef?
    let result = AXUIElementCopyParameterizedAttributeValue(
      field, kAXStringForRangeParameterizedAttribute as CFString, parameter, &value)
    if result == .success, let text = value as? String { return text }
    length -= 1
  }
  return nil
}

func codePoints(_ text: String) -> String {
  text.unicodeScalars.map { String($0.value, radix: 16) }.joined(separator: " ")
}

func currentLength(of field: AXUIElement) -> Int {
  (copy(field, kAXValueAttribute) as? String)?.utf16.count ?? -1
}

func setSelectedText(of field: AXUIElement, to text: String) -> AXError {
  AXUIElementSetAttributeValue(field, kAXSelectedTextAttribute as CFString, text as CFString)
}

func string(of field: AXUIElement, at index: Int) -> String? {
  copyForRange(field, kAXStringForRangeParameterizedAttribute, at: index) as? String
}

func characterBounds(of field: AXUIElement, at index: Int) -> CGRect {
  var bounds = CGRect.zero
  guard let value = copyForRange(field, kAXBoundsForRangeParameterizedAttribute, at: index) else { return bounds }
  AXValueGetValue(value as! AXValue, .cgRect, &bounds)
  return bounds
}

func copyForRange(_ field: AXUIElement, _ attribute: String, at index: Int) -> CFTypeRef? {
  var range = CFRange(location: index, length: 1)
  guard let parameter = AXValueCreate(.cfRange, &range) else { return nil }
  var value: CFTypeRef?
  guard AXUIElementCopyParameterizedAttributeValue(field, attribute as CFString, parameter, &value) == .success else { return nil }
  return value
}

func copy(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
  var value: CFTypeRef?
  guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
  return value
}

func isSettable(_ element: AXUIElement, _ attribute: String) -> Bool {
  var settable = DarwinBoolean(false)
  guard AXUIElementIsAttributeSettable(element, attribute as CFString, &settable) == .success else { return false }
  return settable.boolValue
}

func selectedRange(of field: AXUIElement) -> CFRange? {
  guard let value = copy(field, kAXSelectedTextRangeAttribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
  var range = CFRange()
  return AXValueGetValue(value as! AXValue, .cfRange, &range) ? range : nil
}

func setSelectedRange(of field: AXUIElement, to range: CFRange) -> AXError {
  var range = range
  guard let value = AXValueCreate(.cfRange, &range) else { return .failure }
  return AXUIElementSetAttributeValue(field, kAXSelectedTextRangeAttribute as CFString, value)
}

func parameterizedAttributes(of element: AXUIElement) -> [String] {
  var names: CFArray?
  guard AXUIElementCopyParameterizedAttributeNames(element, &names) == .success else { return [] }
  return names as? [String] ?? []
}
