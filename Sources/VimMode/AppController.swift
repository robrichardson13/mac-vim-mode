import AppKit
import ApplicationServices
import VimCore

/// Owns the app's lifetime: launching means active, as soon as Accessibility allows it.
@MainActor
final class AppController: NSObject {
  private let state: AppState
  private let session: VimSession
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
  private var settingsWindow: SettingsWindow?
  private var grantTimer: Timer?

  override init() {
    state = AppState()
    session = VimSession(state: state)
  }

  func start() {
    installStatusMenu()
    showInactive()
    session.onModeChange = { [weak self] mode in self?.show(mode) }
    KeyboardTap.shared.session = session
    state.onOptInsChange = { [weak self] in
      self?.session.resetEngine()
      self?.followFrontmostApp()
    }
    followFrontmostApp()
    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        if self?.settingsWindow?.isVisible == true { self?.state.refreshAppsToAdd() }
        self?.followFrontmostApp()
      }
    }
    if startVimIfAllowed() { return }
    // Not activating: this also runs when an agent rebuilds, and must not take focus.
    showSettings(activating: false)
    grantTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.retryAfterGrant() }
    }
  }

  private func installStatusMenu() {
    let menu = NSMenu()
    statusLine.isEnabled = false
    menu.addItem(statusLine)
    menu.addItem(.separator())
    let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
    settings.target = self
    menu.addItem(settings)
    menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    statusItem.menu = menu
  }

  @objc private func openSettings() {
    showSettings(activating: true)
  }

  private func showSettings(activating: Bool) {
    state.refreshAppsToAdd()
    let window = settingsWindow ?? SettingsWindow(state: state)
    settingsWindow = window
    window.show(activating: activating)
  }

  private func retryAfterGrant() {
    guard startVimIfAllowed() else { return }
    grantTimer?.invalidate()
    grantTimer = nil
  }

  private func startVimIfAllowed() -> Bool {
    guard AXIsProcessTrusted(), KeyboardTap.shared.start() else { return false }
    session.startOverlayUpdates()
    followFrontmostApp()
    state.isActive = true
    show(.insert)
    Log.write("Running. Press Escape in a text field of an opted-in app for normal mode.")
    return true
  }

  private func followFrontmostApp() {
    session.enableElectronAccessibility()
    KeyboardTap.shared.setOptedInAppFrontmost(session.isOptedInAppFrontmost)
  }

  private func showInactive() {
    statusItem.button?.title = "vim: off"
    statusLine.title = "Needs Accessibility"
  }

  private func show(_ mode: VimEngine.Mode) {
    switch mode {
    case .insert:
      statusItem.button?.title = "vim: I"
      statusLine.title = "Insert mode"
    case .normal:
      statusItem.button?.title = "vim: N"
      statusLine.title = "Normal mode"
    case .visual:
      statusItem.button?.title = "vim: V"
      statusLine.title = "Visual mode"
    case .visualLine:
      statusItem.button?.title = "vim: VL"
      statusLine.title = "Visual line mode"
    }
  }
}
