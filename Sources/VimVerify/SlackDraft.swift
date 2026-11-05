import AppKit
import ApplicationServices

/// The self-DM message box named by `VIM_VERIFY_SLACK_TITLE`. Every key the driver posts is gated
/// on `confirmFocused`, because anywhere else a test could reach a real person.
struct SlackDraft: TypingTarget {
  static let bundleIdentifier = "com.tinyspeck.slackmacgap"

  let field: AppField
  let selfDMWindowTitle: String

  static func open() throws -> SlackDraft {
    guard let title = ProcessInfo.processInfo.environment["VIM_VERIFY_SLACK_TITLE"], !title.isEmpty else {
      throw Abort("set VIM_VERIFY_SLACK_TITLE to your self-DM's exact window title, e.g. \"you (DM) - Workspace - Slack\"")
    }
    guard let slack = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
      throw Abort("Slack isn't running")
    }
    activate(bundleIdentifier: bundleIdentifier)
    let draft = SlackDraft(field: AppField(processIdentifier: slack.processIdentifier), selfDMWindowTitle: title)
    try draft.confirmFocused()
    // Never overwrite a draft Rob is writing. An emoji-only draft reads as two newlines, so it fails this too.
    guard draft.field.isEmpty else { throw Abort("the self-DM has a draft; clear it first") }
    return draft
  }

  func confirmFocused() throws {
    guard focusedAppBundleIdentifier() == Self.bundleIdentifier else { throw Abort("Slack isn't frontmost") }
    let title = AppField.attribute(kAXTitleAttribute, of: field.focusedWindow) as? String
    guard title == selfDMWindowTitle else { throw Abort("Slack isn't showing the self-DM; open it first") }
    guard field.isFocusedElementATextArea else {
      throw Abort("the self-DM message box isn't focused; click into it first")
    }
  }

  func expectedAxValue(for scenario: Scenario) -> String? { scenario.axValue }

  func close() {}
}
