@preconcurrency import CoreGraphics
import Foundation

/// Sees every key press before apps do. Runs on its own thread because our own posted keystrokes
/// pass through this tap: if handling a key blocked this thread, they couldn't reach the app until
/// it finished, so the app would never see an edit it was waiting for.
///
/// Keys are captured here and handled in order on the main thread. While any are in flight, later
/// keys queue behind them, so text typed right after `ciw` lands after the edit.
final class KeyboardTap: @unchecked Sendable {
  static let shared = KeyboardTap()

  private static let escapeKeyCode: Int64 = 53

  nonisolated(unsafe) var session: VimSession?

  private let lock = NSLock()
  private var machPort: CFMachPort?
  private var isOptedInAppFrontmost = false
  private var isInsertMode = true
  private var isDraining = false
  private var pending: [CGEvent] = []

  func start() -> Bool {
    let started = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var didStart = false
    Thread.detachNewThread {
      let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
      guard
        let port = CGEvent.tapCreate(
          tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
          eventsOfInterest: mask, callback: keyboardTapCallback, userInfo: nil)
      else {
        started.signal()
        return
      }
      self.machPort = port
      let source = CFMachPortCreateRunLoopSource(nil, port, 0)
      CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
      CGEvent.tapEnable(tap: port, enable: true)
      didStart = true
      started.signal()
      CFRunLoopRun()
    }
    started.wait()
    return didStart
  }

  func setOptedInAppFrontmost(_ isFrontmost: Bool) {
    lock.withLock { isOptedInAppFrontmost = isFrontmost }
  }

  fileprivate func reenable() {
    guard let machPort else { return }
    CGEvent.tapEnable(tap: machPort, enable: true)
  }

  /// Returns true when the key was taken and must not reach the app directly.
  fileprivate func capture(_ event: CGEvent) -> Bool {
    let flags = event.flags
    if flags.contains(.maskCommand) || flags.contains(.maskAlternate) || flags.contains(.maskSecondaryFn) {
      return false
    }
    let isEscape = event.getIntegerValueField(.keyboardEventKeycode) == Self.escapeKeyCode
    return lock.withLock {
      guard isOptedInAppFrontmost, isDraining || !isInsertMode || isEscape, let copy = event.copy() else {
        return false
      }
      pending.append(copy)
      if !isDraining {
        isDraining = true
        DispatchQueue.main.async { MainActor.assumeIsolated { self.drain() } }
      }
      return true
    }
  }

  @MainActor
  private func drain() {
    while let event = nextPendingEvent() {
      let wasHandled = session?.handleKeyDown(event) ?? false
      if !wasHandled { Keystrokes.repost(event) }
      let isInsert = session?.isInsertMode ?? true
      lock.withLock { isInsertMode = isInsert }
    }
  }

  private func nextPendingEvent() -> CGEvent? {
    lock.withLock {
      guard !pending.isEmpty else {
        isDraining = false
        return nil
      }
      return pending.removeFirst()
    }
  }
}

private func keyboardTapCallback(
  proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
    KeyboardTap.shared.reenable()
    return Unmanaged.passUnretained(event)
  }
  guard type == .keyDown,
    event.getIntegerValueField(.eventSourceUserData) != Keystrokes.syntheticEventTag,
    KeyboardTap.shared.capture(event)
  else { return Unmanaged.passUnretained(event) }
  return nil
}
