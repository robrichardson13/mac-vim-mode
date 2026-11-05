import AppKit
import VimCore

/// Replays engine effects on the real field: Accessibility moves the caret, real keystrokes edit.
/// Each step is confirmed by re-reading the field, so a selection that didn't land can't delete
/// the wrong text.
@MainActor
struct EffectPerformer {
  static let settleTimeout: TimeInterval = 0.15
  static let editTimeout: TimeInterval = 0.5

  let field: FocusedTextField

  func perform(_ effects: [VimEffect], startingFrom snapshot: TextSnapshot) {
    var expectedText = snapshot.text
    for effect in effects {
      guard perform(effect, expectedText: &expectedText) else {
        NSSound.beep()
        Log.write("stopped: the field didn't reach the expected state after \(effect.logName); \(diagnostics(for: effect, expectedText: expectedText))")
        return
      }
    }
  }

  private func diagnostics(for effect: VimEffect, expectedText: String) -> String {
    let selection = field.caretSelection.map { "\($0.location),\($0.length)" } ?? "unreadable"
    var requested = "none"
    if case .replace(let range, _) = effect { requested = "\(range.location),\(range.length)" }
    if case .setSelection(let range) = effect { requested = "\(range.location),\(range.length)" }
    return "requested \(requested), selection \(selection), selectedTextLength \(field.selectedText?.utf16.count ?? -1), expectedLength \(expectedText.utf16.count), actualLength \(field.textMap?.text.utf16.count ?? -1)"
  }

  private func perform(_ effect: VimEffect, expectedText: inout String) -> Bool {
    switch effect {
    case .passThrough:
      return true
    case .setSelection(let range):
      return select(range)
    case .replace(let range, let replacement):
      guard select(range), selectionHolds(range, of: expectedText) else { return false }
      let caretLengthBefore = field.textMap?.caretLength ?? 0
      if replacement.isEmpty {
        Keystrokes.post(.delete)
      } else {
        postText(replacement)
      }
      let edited = NSMutableString(string: expectedText)
      edited.replaceCharacters(in: range, with: replacement)
      expectedText = edited as String
      let target = expectedText
      let startedAt = Date()
      let didApply = waitUntil(timeout: Self.editTimeout) {
        field.textMap.map { editLanded(in: $0, expecting: target, caretLengthBefore: caretLengthBefore) } ?? false
      }
      Log.write("edit \(didApply ? "applied" : "not applied") after \(Int(Date().timeIntervalSince(startedAt) * 1000))ms")
      return didApply
    case .moveCaretUp:
      Keystrokes.post(.upArrow)
    case .moveCaretDown:
      Keystrokes.post(.downArrow)
    case .undo:
      Keystrokes.post(.z, flags: .maskCommand)
    case .redo:
      Keystrokes.post(.z, flags: [.maskCommand, .maskShift])
    }
    return true
  }

  private func select(_ range: NSRange) -> Bool {
    guard let textMap = field.textMap else { return false }
    let caretRange = textMap.caretRange(forRange: range)
    if textMap.sharesCaretWithNextLine(NSMaxRange(range)), let shortRange = oneShort(of: caretRange, requestedLength: range.length) {
      // Setting a shared caret lands on the next line. A real key from one short stays on this one.
      field.setCaretSelection(shortRange)
      guard landed(on: shortRange) else { return false }
      Keystrokes.post(.rightArrow, flags: caretRange.length > 0 ? .maskShift : [])
    } else {
      field.setCaretSelection(caretRange)
    }
    return landed(on: caretRange)
  }

  private func oneShort(of caretRange: NSRange, requestedLength: Int) -> NSRange? {
    if caretRange.length > 0 { return NSRange(location: caretRange.location, length: caretRange.length - 1) }
    guard requestedLength == 0, caretRange.location > 0 else { return nil }
    return NSRange(location: caretRange.location - 1, length: 0)
  }

  private func landed(on caretRange: NSRange) -> Bool {
    waitUntil(timeout: Self.settleTimeout) {
      field.caretSelection.map { selectionLanded($0, on: caretRange) } ?? false
    }
  }

  private func selectionHolds(_ range: NSRange, of text: String) -> Bool {
    guard range.length > 0 else { return true }
    let expected = (text as NSString).substring(with: range)
    return waitUntil(timeout: Self.settleTimeout) {
      guard let selected = field.selectedText, !selected.isEmpty else {
        return field.caretSelection == field.textMap?.caretRange(forRange: range)
      }
      return selectionCovers(selected, expected: expected)
    }
  }

  private func postText(_ text: String) {
    for keystroke in textKeystrokes(for: text) {
      switch keystroke {
      case .characters(let characters): Keystrokes.post(characters)
      case .softNewline: Keystrokes.post(.returnKey, flags: .maskShift)
      }
    }
  }

  private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if condition() { return true }
      Thread.sleep(forTimeInterval: 0.005)
    }
    return condition()
  }
}

extension VimEffect {
  fileprivate var logName: String {
    switch self {
    case .passThrough: "pass-through"
    case .setSelection: "move"
    case .replace: "edit"
    case .moveCaretUp, .moveCaretDown: "vertical move"
    case .undo, .redo: "undo"
    }
  }
}
