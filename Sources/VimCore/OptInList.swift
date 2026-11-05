/// The apps vim mode runs in, by bundle identifier.
public struct OptInList: Equatable, Sendable {
  public static let firstRunApps = ["com.tinyspeck.slackmacgap"]

  public private(set) var bundleIdentifiers: [String]

  /// `stored` is nil only before the first change was ever saved. An empty list means Rob
  /// removed everything, so it must not bring the first-run apps back.
  public init(stored: [String]?) {
    bundleIdentifiers = stored ?? Self.firstRunApps
  }

  public func contains(_ bundleIdentifier: String?) -> Bool {
    guard let bundleIdentifier else { return false }
    return bundleIdentifiers.contains(bundleIdentifier)
  }

  public mutating func add(_ bundleIdentifier: String) {
    guard !contains(bundleIdentifier) else { return }
    bundleIdentifiers.append(bundleIdentifier)
  }

  public mutating func remove(_ bundleIdentifier: String) {
    bundleIdentifiers.removeAll { $0 == bundleIdentifier }
  }
}
