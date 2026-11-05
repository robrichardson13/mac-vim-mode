import CoreGraphics
import Foundation

/// Saves the field's area after each scenario, overlay included. Only the field, so the rest of
/// the conversation never lands in a file.
struct ScenarioScreenshots {
  static let directory = "/tmp/vim-verify-screenshots"

  /// Nil without Screen Recording. Preflight only: asking would put a prompt in front of the run.
  static func prepare() -> ScenarioScreenshots? {
    guard CGPreflightScreenCaptureAccess() else {
      print("screenshots: not permitted, grant Screen Recording to the app running this")
      return nil
    }
    try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
    return ScenarioScreenshots()
  }

  func capture(_ scenarioName: String, of field: AppField) {
    guard let frame = field.focusedFrame else { return }
    let region = "\(Int(frame.minX)),\(Int(frame.minY)),\(Int(frame.width)),\(Int(frame.height))"
    let status = runTool("/usr/sbin/screencapture", ["-x", "-R", region, "\(Self.directory)/\(scenarioName).png"])
    if status != 0 { print("screenshots: screencapture exited \(status) on \(scenarioName)") }
  }
}
