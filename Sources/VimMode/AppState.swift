import Observation

/// What the settings window shows and changes.
@MainActor
@Observable
final class AppState {
  var isActive = false
}
