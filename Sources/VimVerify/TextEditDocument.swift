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
    if !wasRunning { try waitForWindowsToSettle(field) }
    let windowsBefore = field.windows
    let frontmostOnly = Keyboard(beforeEachKey: {
      guard focusedAppBundleIdentifier() == bundleIdentifier else { throw Abort("TextEdit isn't frontmost") }
    })
    try frontmostOnly.press([.newDocument])
    var newWindows: [AXUIElement] = []
    try waitFor("the new TextEdit document") {
      newWindows = field.windows.filter { window in !windowsBefore.contains { CFEqual($0, window) } }
      return !newWindows.isEmpty
    }
    guard newWindows.count == 1 else { throw Abort("more than one new TextEdit window appeared; closing none") }
    let document = TextEditDocument(field: field, window: newWindows[0], launchedTextEdit: !wasRunning)
    // Never close on these failures: the window may be Rob's restored document, and closing presses Delete.
    try waitFor("the new document to take focus") { (try? document.confirmFocused()) != nil }
    guard field.isEmpty else { throw Abort("the new TextEdit document isn't empty") }
    return document
  }

  /// A launching TextEdit restores Rob's documents after it comes to the front. Any window that
  /// arrives after the driver's snapshot would pass for the driver's own.
  private static func waitForWindowsToSettle(_ field: AppField) throws {
    var count = field.windows.count
    var stablePolls = 0
    try waitFor("TextEdit's windows to settle") {
      let current = field.windows.count
      stablePolls = current == count ? stablePolls + 1 : 0
      count = current
      return stablePolls >= 40
    }
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
