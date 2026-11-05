import AppKit
import Observation
import VimCore

/// What the settings window shows and changes.
@MainActor
@Observable
final class AppState {
  private static let optInsKey = "optedInBundleIdentifiers"

  var isActive = false
  var onOptInsChange: (() -> Void)?
  private(set) var optIns = OptInList(stored: UserDefaults.standard.stringArray(forKey: optInsKey))
  private(set) var appsToAdd: [AppChoice] = []

  func optIn(_ bundleIdentifier: String) {
    optIns.add(bundleIdentifier)
    optInsChanged()
  }

  func optOut(_ bundleIdentifier: String) {
    optIns.remove(bundleIdentifier)
    optInsChanged()
  }

  func refreshAppsToAdd() {
    appsToAdd = NSWorkspace.shared.runningApplications
      .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
      .compactMap(\.bundleIdentifier)
      .filter { !optIns.contains($0) }
      .map(AppChoice.init)
      .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }

  private func optInsChanged() {
    UserDefaults.standard.set(optIns.bundleIdentifiers, forKey: Self.optInsKey)
    refreshAppsToAdd()
    onOptInsChange?()
  }
}

/// An app as Settings shows it. An uninstalled app keeps its row, named by its bundle identifier.
struct AppChoice: Identifiable {
  let id: String
  let name: String
  let icon: NSImage?

  init(bundleIdentifier: String) {
    id = bundleIdentifier
    let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    name = url?.deletingPathExtension().lastPathComponent ?? bundleIdentifier
    icon = url.map { NSWorkspace.shared.icon(forFile: $0.path) }
  }
}
