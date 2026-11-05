import AppKit
import Foundation

setvbuf(stdout, nil, _IOLBF, 0)

let usesTextEdit = CommandLine.arguments.contains("--textedit")
let scenarioFilter = CommandLine.arguments.dropFirst().first { !$0.hasPrefix("--") }
let watch = UserInputWatch()
var vimMode: Process?
var exitCode: Int32 = 0

do {
  let previousApp = try prepare()
  defer { if !watch.wasInterrupted { activate(bundleIdentifier: previousApp) } }
  vimMode = try launchVimMode(optingIn: usesTextEdit ? TextEditDocument.bundleIdentifier : SlackDraft.bundleIdentifier)
  defer { vimMode?.terminate() }
  let target: TypingTarget = usesTextEdit ? try TextEditDocument.open() : try SlackDraft.open()
  defer { target.close() }
  let failures = try runScenarios(matching: scenarioFilter, in: target)
  print(failures == 0 ? "PASS" : "FAIL: \(failures) scenario(s)")
  exitCode = failures == 0 ? 0 : 1
} catch {
  print("ABORTED: \(error). Check the draft or document for leftover test text.")
  exitCode = 2
}
exit(exitCode)

func prepare() throws -> String? {
  guard AXIsProcessTrusted() else { throw Abort("the app running this needs Accessibility") }
  guard !isVimModeRunning() else { throw Abort("vim-mode is already running; quit it so two taps don't fight") }
  try watch.start()
  return focusedAppBundleIdentifier()
}

func runScenarios(matching filter: String?, in target: TypingTarget) throws -> Int {
  let keyboard = Keyboard(beforeEachKey: {
    if watch.wasInterrupted { throw Abort("you touched the keyboard or mouse") }
    try target.confirmFocused()
  })
  var failures = 0
  for scenario in scenarios where filter.map({ scenario.name.contains($0) }) ?? true {
    guard let expected = target.expectedAxValue(for: scenario) else { continue }
    let failure = try run(scenario, expecting: expected, in: target.field, with: keyboard)
    print(failure.map { "FAIL \(scenario.name): \($0)" } ?? "ok   \(scenario.name)")
    if failure != nil { failures += 1 }
    try clear(target.field, with: keyboard)
  }
  return failures
}

func run(_ scenario: Scenario, expecting axValue: String, in field: AppField, with keyboard: Keyboard) throws -> String? {
  try keyboard.press(Key.parse(scenario.seed))
  waitUntilStable { field.axValue }
  let stoppedBefore = VimLog.stoppedCount
  try keyboard.press(Key.parse(scenario.keys))
  VimLog.waitUntilQuiet()
  var problems: [String] = []
  let newStops = VimLog.stoppedCount - stoppedBefore
  if newStops > 0 { problems.append("vim-mode stopped \(newStops) time(s): \(VimLog.lastStop ?? "")") }
  if field.axValue != axValue {
    problems.append("AXValue \(field.axValue.debugDescription), expected \(axValue.debugDescription)")
  }
  if let caret = scenario.caret, field.selection != NSRange(location: caret, length: 0) {
    problems.append("selection \(field.selection.location),\(field.selection.length), expected caret \(caret)")
  }
  return problems.isEmpty ? nil : problems.joined(separator: "; ")
}

func clear(_ field: AppField, with keyboard: Keyboard) throws {
  try keyboard.press([.escape, .character("i"), .selectAll, .delete])
  for _ in 0..<40 where !field.isEmpty {
    Thread.sleep(forTimeInterval: 0.05)
  }
  guard field.isEmpty else { throw Abort("couldn't clear the draft between scenarios") }
}

func waitUntilStable(_ read: () -> String) {
  var last = read()
  for _ in 0..<40 {
    Thread.sleep(forTimeInterval: 0.05)
    let current = read()
    if current == last, !current.isEmpty { return }
    last = current
  }
}

func activate(bundleIdentifier: String?) {
  guard let bundleIdentifier else { return }
  _ = runTool("/usr/bin/open", ["-b", bundleIdentifier])
  Thread.sleep(forTimeInterval: 0.5)
}

func isVimModeRunning() -> Bool {
  // Any build counts, not just this checkout's: a second tap in Slack fights the driver's.
  runTool("/usr/bin/pgrep", ["^vim-mode(-|$)"]) == 0
}

func runTool(_ path: String, _ arguments: [String]) -> Int32 {
  let tool = Process()
  tool.executableURL = URL(fileURLWithPath: path)
  tool.arguments = arguments
  tool.standardOutput = FileHandle.nullDevice
  guard (try? tool.run()) != nil else { return -1 }
  tool.waitUntilExit()
  return tool.terminationStatus
}

func launchVimMode(optingIn bundleIdentifier: String) throws -> Process {
  try? FileManager.default.removeItem(atPath: VimLog.path)
  let process = Process()
  process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
    .appendingPathComponent("vim-mode")
  // The argument domain overrides the saved list for this run and never writes to it.
  process.arguments = ["-optedInBundleIdentifiers", "(\(bundleIdentifier))"]
  process.standardOutput = FileHandle.nullDevice
  try process.run()
  for _ in 0..<40 where !VimLog.hasStarted {
    Thread.sleep(forTimeInterval: 0.05)
  }
  guard VimLog.hasStarted else { throw Abort("vim-mode didn't start") }
  return process
}

struct Abort: Error, CustomStringConvertible {
  let description: String
  init(_ description: String) { self.description = description }
}

/// A field the driver is allowed to type into, and the checks that keep it that way.
protocol TypingTarget {
  var field: AppField { get }
  func confirmFocused() throws
  /// Nil when the scenario doesn't apply here.
  func expectedAxValue(for scenario: Scenario) -> String?
  func close()
}
