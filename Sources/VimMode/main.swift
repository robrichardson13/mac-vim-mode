import AppKit
import ApplicationServices
import VimCore

setvbuf(stdout, nil, _IOLBF, 0)

guard AXIsProcessTrusted() else {
  print("Not trusted: grant Accessibility to the app running this binary, then relaunch that app.")
  exit(1)
}

let application = NSApplication.shared
application.setActivationPolicy(.accessory)

let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
statusItem.button?.title = statusTitle(for: .insert)
let statusMenu = NSMenu()
statusMenu.addItem(withTitle: "Quit Vim Mode", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
statusItem.menu = statusMenu

let session = VimSession()
session.onModeChange = { mode in statusItem.button?.title = statusTitle(for: mode) }
KeyboardTap.shared.session = session
session.startOverlayUpdates()

guard KeyboardTap.shared.start() else {
  print("Couldn't create the keyboard tap.")
  exit(1)
}

VimSession.enableElectronAccessibility()
KeyboardTap.shared.setSupportedAppFrontmost(VimSession.isSupportedAppFrontmost)
NSWorkspace.shared.notificationCenter.addObserver(
  forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
) { _ in
  MainActor.assumeIsolated {
    VimSession.enableElectronAccessibility()
    KeyboardTap.shared.setSupportedAppFrontmost(VimSession.isSupportedAppFrontmost)
  }
}

Log.write("Running. Only active in Slack. Press Escape in a message box for normal mode; Ctrl-C here to quit.")
application.run()

func statusTitle(for mode: VimEngine.Mode) -> String {
  switch mode {
  case .insert: "vim: I"
  case .normal: "vim: N"
  case .visual: "vim: V"
  case .visualLine: "vim: VL"
  }
}
