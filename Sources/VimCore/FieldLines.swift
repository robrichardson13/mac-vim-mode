/// One element of a field's Accessibility tree.
public struct FieldNode: Sendable {
  public let role: String
  public let value: String
  public let children: [FieldNode]

  public init(role: String, value: String = "", children: [FieldNode] = []) {
    self.role = role
    self.value = value
    self.children = children
  }
}

/// The field's real lines, emoji left out because they have no caret position. Nil when the tree
/// has no structure to read, as in a plain native text view.
public func fieldLines(in root: FieldNode) -> [String]? {
  guard !root.children.isEmpty else { return nil }
  var collector = LineCollector()
  for child in root.children { collector.add(child) }
  collector.finishLine()
  return collector.lines
}

private struct LineCollector {
  var lines: [String] = []
  private var currentLine: String?

  mutating func add(_ node: FieldNode) {
    switch node.role {
    case "AXStaticText":
      currentLine = (currentLine ?? "") + node.value
    case "AXImage":
      currentLine = currentLine ?? ""
    case "AXGroup", "AXList":
      finishLine()
      if node.children.isEmpty { lines.append("") }
      for child in node.children { add(child) }
      finishLine()
    default:
      for child in node.children { add(child) }
    }
  }

  mutating func finishLine() {
    if let currentLine { lines.append(currentLine) }
    currentLine = nil
  }
}
