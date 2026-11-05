import AppKit

/// Draws nib's vim indicators in a click-through window above the app, since nothing can be
/// drawn inside another app's own UI: a small mode badge and a solid block caret.
@MainActor
final class ModeOverlay {
  struct Caret: Equatable {
    let bounds: CGRect
    let width: CGFloat
    let character: String?
    /// An emoji has no character to knock out, so it gets an outline instead of a solid block.
    let isOverEmoji: Bool
  }

  struct Content: Equatable {
    let fieldFrame: CGRect
    let caret: Caret?
    let badge: String
    let style: FieldTextStyle
  }

  private let panel: NSPanel
  private let view = ModeOverlayView()
  private var shownContent: Content?

  init() {
    panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.ignoresMouseEvents = true
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    panel.contentView = view
  }

  func show(_ content: Content) {
    guard content != shownContent else { return }
    shownContent = content
    let frame = appKitRect(content.fieldFrame)
    panel.setFrame(frame, display: false)
    view.content = content
    view.caretRect = content.caret.map { localCaretRect($0, panelOrigin: frame.origin) }
    view.needsDisplay = true
    panel.orderFrontRegardless()
  }

  func hide() {
    shownContent = nil
    panel.orderOut(nil)
  }

  /// Accessibility's origin is the primary screen's top left; AppKit's is its bottom left.
  private func appKitRect(_ rect: CGRect) -> CGRect {
    let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
    return CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
  }

  private func localCaretRect(_ caret: Caret, panelOrigin: CGPoint) -> NSRect {
    let rect = appKitRect(caret.bounds)
    return NSRect(x: rect.minX - panelOrigin.x, y: rect.minY - panelOrigin.y, width: caret.width, height: rect.height)
  }
}

private final class ModeOverlayView: NSView {
  var content: ModeOverlay.Content?
  var caretRect: NSRect?

  override func draw(_ dirtyRect: NSRect) {
    NSColor.clear.setFill()
    bounds.fill()
    guard let content else { return }
    if let caret = content.caret, let caretRect { drawCaret(caret, in: caretRect, style: content.style) }
    drawBadge(content.badge, style: content.style)
  }

  private func drawCaret(_ caret: ModeOverlay.Caret, in rect: NSRect, style: FieldTextStyle) {
    if caret.isOverEmoji {
      style.textColor.setStroke()
      let outline = NSBezierPath(rect: rect.insetBy(dx: 0.75, dy: 0.75))
      outline.lineWidth = 1.5
      outline.stroke()
      return
    }
    style.textColor.setFill()
    rect.fill()
    guard let character = caret.character else { return }
    let glyph = NSAttributedString(
      string: character, attributes: [.font: style.font, .foregroundColor: style.backgroundColor])
    let size = glyph.size()
    glyph.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
  }

  /// nib's badge: small, quiet text on a faint capsule, with the field's own background behind it
  /// so long text wrapping underneath stays legible.
  private func drawBadge(_ badge: String, style: FieldTextStyle) {
    let label = NSAttributedString(
      string: badge,
      attributes: [
        .font: NSFont.systemFont(ofSize: 9, weight: .semibold),
        .foregroundColor: style.textColor.withAlphaComponent(0.6),
      ])
    let size = label.size()
    let capsule = NSRect(
      x: bounds.maxX - size.width - 18, y: bounds.maxY - size.height - 10, width: size.width + 10, height: size.height + 2)
    let path = NSBezierPath(roundedRect: capsule, xRadius: capsule.height / 2, yRadius: capsule.height / 2)
    style.backgroundColor.setFill()
    path.fill()
    style.textColor.withAlphaComponent(0.1).setFill()
    path.fill()
    label.draw(at: NSPoint(x: capsule.minX + 5, y: capsule.minY + 1))
  }
}
