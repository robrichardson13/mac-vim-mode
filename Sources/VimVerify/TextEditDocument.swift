import AppKit
import ApplicationServices

/// A new untitled TextEdit document the driver opens itself and closes without saving. Every key is
/// gated on that exact window being focused, so a test can never type into Rob's own documents.
struct TextEditDocument: TypingTarget {
  static let bundleIdentifier = "com.apple.TextEdit"

  let field: AppField
  private let window: AXUIElement
  private let launchedTextEdit: Bool

  static func open() throws -> TextEditDocument {
    let wasRunning = textEditProcessIdentifier() != nil
    // The system would capitalize the scenarios' lowercase seeds. Applies only if this launches TextEdit.
    _ = runTool("/usr/bin/open", ["-a", "TextEdit", "--args", "-NSAutomaticCapitalizationEnabled", "NO"])
    try waitFor("TextEdit to come to the front") {
      focusedAppBundleIdentifier() == bundleIdentifier && textEditProcessIdentifier() != nil
    }
    let field = AppField(processIdentifier: textEditProcessIdentifier()!)
    let windowsBefore = field.windows
    let frontmostOnly = Keyboard(beforeEachKey: {
      guard focusedAppBundleIdentifier() == bundleIdentifier else { throw Abort("TextEdit isn't frontmost") }
    })
    try frontmostOnly.press([.newDocument])
    var newWindow: AXUIElement?
    try waitFor("the new TextEdit document") {
      newWindow = field.windows.first { window in !windowsBefore.contains { CFEqual($0, window) } }
      return newWindow != nil
    }
    let document = TextEditDocument(field: field, window: newWindow!, launchedTextEdit: !wasRunning)
    do {
      try waitFor("the new document to take focus") { (try? document.confirmFocused()) != nil }
      guard field.isEmpty else { throw Abort("the new TextEdit document isn't empty") }
    } catch {
      document.close()
      throw error
    }
    return document
  }

  func confirmFocused() throws {
    guard focusedAppBundleIdentifier() == Self.bundleIdentifier else { throw Abort("TextEdit isn't frontmost") }
    guard let focused = field.focusedWindow, CFEqual(focused, window) else {
      throw Abort("the driver's TextEdit document isn't the focused window")
    }
    guard field.isFocusedElementATextArea else { throw Abort("the document's text area isn't focused") }
  }

  /// Scenarios state Slack's raw text. A native field shows an emptied field as empty, not as a newline.
  func expectedAxValue(for scenario: Scenario) -> String? {
    guard !scenario.isSlackOnly else { return nil }
    return scenario.axValue == "\n" ? "" : scenario.axValue
  }

  func close() {
    guard let closeButton = AppField.attribute(kAXCloseButtonAttribute, of: window) else { return }
    AXUIElementPerformAction(closeButton as! AXUIElement, kAXPressAction as CFString)
    pressDeleteOnKeepDocumentSheet()
    if launchedTextEdit {
      NSRunningApplication(processIdentifier: field.processIdentifier)?.terminate()
    }
  }

  // Delete is what removes the autosaved copy: TextEdit keeps untitled documents in Rob's iCloud
  // folder, so a document abandoned at this sheet comes back as a real file.
  private func pressDeleteOnKeepDocumentSheet() {
    for _ in 0..<40 {
      Thread.sleep(forTimeInterval: 0.05)
      let children = AppField.attribute(kAXChildrenAttribute, of: window) as? [AXUIElement] ?? []
      guard let sheet = children.first(where: { AppField.attribute(kAXRoleAttribute, of: $0) as? String == kAXSheetRole }) else { continue }
      if let delete = Self.button(titled: "Delete", in: sheet) { AXUIElementPerformAction(delete, kAXPressAction as CFString) }
      return
    }
  }

  private static func button(titled title: String, in element: AXUIElement) -> AXUIElement? {
    if AppField.attribute(kAXRoleAttribute, of: element) as? String == kAXButtonRole,
      AppField.attribute(kAXTitleAttribute, of: element) as? String == title
    {
      return element
    }
    let children = AppField.attribute(kAXChildrenAttribute, of: element) as? [AXUIElement] ?? []
    return children.lazy.compactMap { button(titled: title, in: $0) }.first
  }

  private static func textEditProcessIdentifier() -> pid_t? {
    let lookup = Process()
    let output = Pipe()
    lookup.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    lookup.arguments = ["-x", "TextEdit"]
    lookup.standardOutput = output
    guard (try? lookup.run()) != nil else { return nil }
    lookup.waitUntilExit()
    let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    return text.split(separator: "\n").first.flatMap { pid_t($0) }
  }

  private static func waitFor(_ what: String, _ condition: () -> Bool) throws {
    for _ in 0..<100 {
      if condition() { return }
      Thread.sleep(forTimeInterval: 0.05)
    }
    throw Abort("timed out waiting for \(what)")
  }
}
