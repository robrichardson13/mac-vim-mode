import Foundation

/// vim-mode's log: the only place its failed edit checks are visible from outside.
enum VimLog {
  // Named for the sibling debug binary the driver launches, never a suffixed app bundle.
  static let path = "/tmp/vim-mode.log"
  // Longer than EffectPerformer.editTimeout, so a failing edit has finished before anyone reads the result.
  private static let quietSeconds = 0.7

  static var hasStarted: Bool { contents.contains("Running.") }
  static var stoppedCount: Int { stops.count }
  static var lastStop: String? { stops.last }

  static func waitUntilQuiet() {
    var size = contents.utf8.count
    var quietSince = Date()
    while Date().timeIntervalSince(quietSince) < quietSeconds {
      Thread.sleep(forTimeInterval: 0.05)
      let current = contents.utf8.count
      if current != size {
        size = current
        quietSince = Date()
      }
    }
  }

  private static var stops: [String] {
    contents.split(separator: "\n").filter { $0.hasPrefix("stopped:") }.map(String.init)
  }

  private static var contents: String {
    (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
  }
}
