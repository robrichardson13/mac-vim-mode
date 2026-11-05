import AppKit
import SwiftUI

@MainActor
final class SettingsWindow {
  private let window: NSWindow

  init(state: AppState) {
    window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(state: state)))
    window.title = "\(ProcessInfo.processInfo.processName) Settings"
    window.styleMask = [.titled, .closable]
    window.isReleasedWhenClosed = false
  }

  func show(activating: Bool) {
    if activating { NSApp.activate() }
    window.center()
    window.orderFrontRegardless()
    if activating { window.makeKey() }
  }
}

private struct SettingsView: View {
  let state: AppState

  var body: some View {
    Form {
      Section("Accessibility") {
        AccessibilityStatus(isActive: state.isActive)
      }
    }
    .formStyle(.grouped)
    .frame(width: 420)
    .fixedSize(horizontal: false, vertical: true)
  }
}

private struct AccessibilityStatus: View {
  let isActive: Bool

  var body: some View {
    if isActive {
      Label("Granted. Vim mode is active.", systemImage: "checkmark.circle.fill")
    } else {
      VStack(alignment: .leading, spacing: 8) {
        Label("Not granted. Vim mode starts as soon as it is.", systemImage: "exclamationmark.triangle.fill")
        Text("If this app is already listed and on, remove it and add it again: a rebuild invalidates the old grant.")
          .font(.caption)
          .foregroundStyle(.secondary)
        Button("Open Accessibility Settings", action: openAccessibilitySettings)
      }
    }
  }

  private func openAccessibilitySettings() {
    let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
    NSWorkspace.shared.open(url)
  }
}
