import AppKit
import ApplicationServices

struct FieldTextStyle: Equatable {
  let textColor: NSColor
  let backgroundColor: NSColor
  let font: NSFont
}

extension FocusedTextField {
  /// In global Accessibility coordinates, whose origin is the primary screen's top left.
  var frame: CGRect? {
    guard let position = copy(kAXPositionAttribute), let size = copy(kAXSizeAttribute) else { return nil }
    var origin = CGPoint.zero
    var extent = CGSize.zero
    guard AXValueGetValue(position as! AXValue, .cgPoint, &origin),
      AXValueGetValue(size as! AXValue, .cgSize, &extent)
    else { return nil }
    return CGRect(origin: origin, size: extent)
  }

  /// Tells a line's end from the next line's start, which report the same caret position.
  /// Slack's message box starts text 13 points in, so a caret further right has text before it.
  var isCaretPastLineStart: Bool {
    guard let caretBounds, let frame else { return false }
    return caretBounds.minX - frame.minX > 15
  }

  /// Text markers, because Slack's AXBoundsForRange returns the same empty rectangle for every range.
  var caretBounds: CGRect? {
    copy("AXSelectedTextMarkerRange").flatMap(bounds(ofMarkerRange:))
  }

  /// The width of the character after the caret, which Slack doesn't report directly.
  func characterWidth(atCaret caret: CGRect) -> CGFloat? {
    var point = CGPoint(x: caret.minX + 0.5, y: caret.midY)
    guard let pointValue = AXValueCreate(.cgPoint, &point),
      let start = copy(parameterized: "AXTextMarkerForPosition", pointValue),
      let next = copy(parameterized: "AXNextTextMarkerForTextMarker", start),
      let range = copy(parameterized: "AXTextMarkerRangeForUnorderedTextMarkers", [start, next] as CFArray),
      let width = bounds(ofMarkerRange: range)?.width,
      width > 0, width < caret.height * 2
    else { return nil }
    return width
  }

  /// Slack's own colors and font when it reports them, so the caret matches its theme.
  func textStyle(atCaret location: Int) -> FieldTextStyle {
    let attributes = styleAttributes(at: location)
    let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    let fontAttributes = attributes["AXFont"] as? [String: Any]
    let size = fontAttributes?["AXFontSize"] as? CGFloat ?? 15
    let font = (fontAttributes?["AXFontName"] as? String).flatMap { NSFont(name: $0, size: size) }
    return FieldTextStyle(
      textColor: color(attributes["AXForegroundColor"]) ?? (isDark ? .white : .black),
      backgroundColor: color(attributes["AXBackgroundColor"])
        ?? (isDark ? NSColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1) : .white),
      font: font ?? .systemFont(ofSize: size))
  }

  private func bounds(ofMarkerRange markerRange: CFTypeRef) -> CGRect? {
    guard let value = copy(parameterized: "AXBoundsForTextMarkerRange", markerRange),
      CFGetTypeID(value) == AXValueGetTypeID()
    else { return nil }
    var bounds = CGRect.zero
    guard AXValueGetValue(value as! AXValue, .cgRect, &bounds), bounds.height > 0 else { return nil }
    return bounds
  }

  private func styleAttributes(at location: Int) -> [String: Any] {
    var range = CFRange(location: location, length: 1)
    guard let parameter = AXValueCreate(.cfRange, &range),
      let styled = copy(parameterized: kAXAttributedStringForRangeParameterizedAttribute, parameter) as? NSAttributedString,
      styled.length > 0
    else { return [:] }
    return Dictionary(uniqueKeysWithValues: styled.attributes(at: 0, effectiveRange: nil).map { ($0.key.rawValue, $0.value) })
  }

  private func color(_ value: Any?) -> NSColor? {
    guard let value, CFGetTypeID(value as CFTypeRef) == CGColor.typeID else { return nil }
    return NSColor(cgColor: value as! CGColor)
  }

  private func copy(parameterized attribute: String, _ parameter: CFTypeRef) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyParameterizedAttributeValue(element, attribute as CFString, parameter, &value) == .success
    else { return nil }
    return value
  }
}
