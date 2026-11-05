import Foundation

/// Reads a field's text in caret coordinates. In Slack, AXValue can't be used for this: it shows
/// an emoji as two newlines, while caret positions skip it, so AXValue's length is only an upper
/// bound and asking for more than the real length returns nothing.
public func readFieldText(upperBound: Int, read: (Int) -> String?) -> String {
  guard upperBound > 0 else { return "" }
  if let text = read(upperBound) { return text }
  var best = ""
  var low = 1
  var high = upperBound - 1
  while low <= high {
    let middle = (low + high) / 2
    if let text = read(middle) {
      best = text
      low = middle + 1
    } else {
      high = middle - 1
    }
  }
  return best
}
