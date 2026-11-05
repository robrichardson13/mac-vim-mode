import AppKit
import VimCore

/// Decides what happens to each key pressed in an opted-in app.
@MainActor
final class VimSession {
  private static let escapeKeyCode: Int64 = 53
  private static let deleteKeyCode: Int64 = 51
  private static let rKeyCode: Int64 = 15

  var onModeChange: ((VimEngine.Mode) -> Void)?

  private let state: AppState
  private var engine = VimEngine()
  private var currentField: FocusedTextField?
  private let overlay = ModeOverlay()
  private var overlayStyle: FieldTextStyle?
  private var overlayTimer: Timer?

  init(state: AppState) {
    self.state = state
  }

  /// Polling, because nothing reports the scrolls and window moves the overlay has to follow.
  /// It only reads anything outside insert mode, so typing never pays for it.
  func startOverlayUpdates() {
    overlayTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.refreshOverlay() }
    }
  }

  var isOptedInAppFrontmost: Bool {
    state.optIns.contains(NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
  }

  // Chromium builds its accessibility tree lazily; this is Electron's documented opt-in.
  func enableElectronAccessibility() {
    for bundleIdentifier in state.optIns.bundleIdentifiers {
      for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier) {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetAttributeValue(element, "AXManualAccessibility" as CFString, kCFBooleanTrue)
      }
    }
  }

  var isInsertMode: Bool { engine.mode == .insert }

  /// Returns true when the key was handled and must not reach the app.
  func handleKeyDown(_ event: CGEvent) -> Bool {
    guard isOptedInAppFrontmost, let app = NSWorkspace.shared.frontmostApplication else { return false }

    let flags = event.flags
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    // Typing must stay instant, so insert mode only pays for Accessibility calls on Escape.
    if engine.mode == .insert, keyCode != Self.escapeKeyCode { return false }

    let startedAt = Date()
    guard let field = FocusedTextField.current(inProcess: app.processIdentifier), let snapshot = field.snapshot else {
      resetEngine()
      return false
    }
    if !field.isSameField(as: currentField) {
      currentField = field
      resetEngine()
    }

    let isControl = flags.contains(.maskControl)
    if isControl, keyCode != Self.rKeyCode { return false }
    guard let key = keyName(for: event, keyCode: keyCode, isControl: isControl) else { return true }

    let result = engine.handle(key: key, control: isControl, in: snapshot)
    onModeChange?(engine.mode)
    if result.effects.contains(.passThrough) { return false }
    EffectPerformer(field: field).perform(result.effects, startingFrom: snapshot)
    Log.write(
      "key \(key == VimEngine.escape ? "esc" : key) in \(Int(Date().timeIntervalSince(startedAt) * 1000))ms: "
        + "text \(snapshot.text.utf16.count), axValue \(field.axValueLength), selection \(snapshot.selection.location),\(snapshot.selection.length), "
        + "newlines \(snapshot.text.filter { $0 == "\n" }.count), effects \(result.effects.count)")
    refreshOverlay()
    return true
  }

  private func refreshOverlay() {
    guard engine.mode != .insert,
      isOptedInAppFrontmost,
      let app = NSWorkspace.shared.frontmostApplication,
      let field = FocusedTextField.current(inProcess: app.processIdentifier),
      field.isSameField(as: currentField),
      let frame = field.frame,
      let badge = engine.mode.badge
    else {
      overlay.hide()
      return
    }
    let style = overlayStyle ?? field.textStyle(atCaret: field.caretSelection?.location ?? 0)
    overlayStyle = style
    overlay.show(
      ModeOverlay.Content(
        fieldFrame: frame,
        caret: engine.mode == .normal ? overlayCaret(in: field, style: style) : nil,
        badge: badge,
        style: style))
  }

  private func overlayCaret(in field: FocusedTextField, style: FieldTextStyle) -> ModeOverlay.Caret? {
    guard let bounds = field.caretBounds else { return nil }
    let character = field.snapshot.flatMap(characterUnderCaret)
    if caretCoversEmoji(width: bounds.width, height: bounds.height) {
      return ModeOverlay.Caret(bounds: bounds, width: bounds.width, character: nil, isOverEmoji: true)
    }
    let measured = character.map { ($0 as NSString).size(withAttributes: [.font: style.font]).width }
    return ModeOverlay.Caret(
      bounds: bounds,
      width: field.characterWidth(atCaret: bounds) ?? measured ?? style.font.pointSize * 0.55,
      character: character,
      isOverEmoji: false)
  }

  private func characterUnderCaret(_ snapshot: TextSnapshot) -> String? {
    let text = snapshot.text as NSString
    guard snapshot.selection.location < text.length else { return nil }
    let character = text.substring(with: text.rangeOfComposedCharacterSequence(at: snapshot.selection.location))
    return character == "\n" ? nil : character
  }

  func resetEngine() {
    engine.resetToInsert()
    onModeChange?(engine.mode)
    overlayStyle = nil
    overlay.hide()
  }

  private func keyName(for event: CGEvent, keyCode: Int64, isControl: Bool) -> String? {
    if keyCode == Self.escapeKeyCode { return VimEngine.escape }
    if keyCode == Self.deleteKeyCode { return "h" }
    if isControl { return "r" }
    var length = 0
    var units = [UniChar](repeating: 0, count: 4)
    event.keyboardGetUnicodeString(maxStringLength: units.count, actualStringLength: &length, unicodeString: &units)
    guard length > 0 else { return nil }
    return String(utf16CodeUnits: units, count: length)
  }
}
