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

  var isVisible: Bool { window.isVisible }

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
      Section("Apps") {
        ForEach(state.optIns.bundleIdentifiers.map(AppChoice.init)) { app in
          OptedInAppRow(app: app) { state.optOut(app.id) }
        }
        AddAppControls(state: state)
      }
    }
    .formStyle(.grouped)
    .frame(width: 420)
    .fixedSize(horizontal: false, vertical: true)
  }
}

private struct OptedInAppRow: View {
  let app: AppChoice
  let remove: () -> Void

  var body: some View {
    HStack {
      if let icon = app.icon {
        Image(nsImage: icon).resizable().frame(width: 18, height: 18)
      }
      Text(app.name)
      Spacer()
      Button("Remove \(app.name)", systemImage: "minus.circle", action: remove)
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }
  }
}

private struct AddAppControls: View {
  let state: AppState

  var body: some View {
    HStack {
      Menu("Add Running App") {
        ForEach(state.appsToAdd) { app in
          Button(app.name) { state.optIn(app.id) }
        }
      }
      .disabled(state.appsToAdd.isEmpty)
      Button("Choose App…", action: chooseApp)
    }
  }

  private func chooseApp() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.application]
    panel.directoryURL = URL(fileURLWithPath: "/Applications")
    guard panel.runModal() == .OK, let url = panel.url else { return }
    guard let bundleIdentifier = Bundle(url: url)?.bundleIdentifier else { return }
    state.optIn(bundleIdentifier)
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
