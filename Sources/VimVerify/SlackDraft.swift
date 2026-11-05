import AppKit
import ApplicationServices

/// Rob's self-DM message box. Every key the driver posts is gated on `confirmFocused`, because
/// anywhere else a test could reach a real person.
struct SlackDraft: TypingTarget {
  static let bundleIdentifier = "com.tinyspeck.slackmacgap"
  private static let selfDMWindowTitle = "rob (DM) - Rob Richardson - Slack"

  let field: AppField

  static func open() throws -> SlackDraft {
    guard let slack = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
      throw Abort("Slack isn't running")
    }
    activate(bundleIdentifier: bundleIdentifier)
    let draft = SlackDraft(field: AppField(processIdentifier: slack.processIdentifier))
    try draft.confirmFocused()
    // Never overwrite a draft Rob is writing. An emoji-only draft reads as two newlines, so it fails this too.
    guard draft.field.isEmpty else { throw Abort("the self-DM has a draft; clear it first") }
    return draft
  }

  func confirmFocused() throws {
    guard focusedAppBundleIdentifier() == Self.bundleIdentifier else { throw Abort("Slack isn't frontmost") }
    let title = AppField.attribute(kAXTitleAttribute, of: field.focusedWindow) as? String
    guard title == Self.selfDMWindowTitle else { throw Abort("Slack isn't showing the self-DM; open it first") }
    guard field.isFocusedElementATextArea else {
      throw Abort("the self-DM message box isn't focused; click into it first")
    }
  }

  func expectedAxValue(for scenario: Scenario) -> String? { scenario.axValue }

  func close() {}
}
