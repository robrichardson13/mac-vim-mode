import AppKit
import Foundation

setvbuf(stdout, nil, _IOLBF, 0)

let scenarioFilter = CommandLine.arguments.dropFirst().first
let watch = UserInputWatch()
var vimMode: Process?
var exitCode: Int32 = 0

do {
  let previousApp = try prepare()
  defer { if !watch.wasInterrupted { open(bundleIdentifier: previousApp) } }
  vimMode = try launchVimMode()
  defer { vimMode?.terminate() }
  let failures = try runScenarios(matching: scenarioFilter)
  print(failures == 0 ? "PASS" : "FAIL: \(failures) scenario(s)")
  exitCode = failures == 0 ? 0 : 1
} catch {
  print("ABORTED: \(error). Check the self-DM draft for leftover test text.")
  exitCode = 2
}
exit(exitCode)

func prepare() throws -> String? {
  guard AXIsProcessTrusted() else { throw Abort("the app running this needs Accessibility") }
  guard !isVimModeRunning() else { throw Abort("vim-mode is already running; quit it so two taps don't fight") }
  try watch.start()
  return SlackDraft.focusedAppBundleIdentifier()
}

func runScenarios(matching filter: String?) throws -> Int {
  open(bundleIdentifier: SlackDraft.bundleIdentifier)
  let draft = try SlackDraft.confirmedEmpty()
  let keyboard = Keyboard(beforeEachKey: {
    if watch.wasInterrupted { throw Abort("you touched the keyboard or mouse") }
    try SlackDraft.confirmSelfDMIsFocused()
  })
  var failures = 0
  for scenario in scenarios where filter.map({ scenario.name.contains($0) }) ?? true {
    let failure = try run(scenario, in: draft, with: keyboard)
    print(failure.map { "FAIL \(scenario.name): \($0)" } ?? "ok   \(scenario.name)")
    if failure != nil { failures += 1 }
    try clear(draft, with: keyboard)
  }
  return failures
}

func run(_ scenario: Scenario, in draft: SlackDraft, with keyboard: Keyboard) throws -> String? {
  try keyboard.press(Key.parse(scenario.seed))
  waitUntilStable { draft.axValue }
  let stoppedBefore = VimLog.stoppedCount
  try keyboard.press(Key.parse(scenario.keys))
  VimLog.waitUntilQuiet()
  return mismatch(scenario, in: draft, newStops: VimLog.stoppedCount - stoppedBefore)
}

func mismatch(_ scenario: Scenario, in draft: SlackDraft, newStops: Int) -> String? {
  var problems: [String] = []
  if newStops > 0 { problems.append("vim-mode stopped \(newStops) time(s): \(VimLog.lastStop ?? "")") }
  if draft.axValue != scenario.axValue {
    problems.append("AXValue \(draft.axValue.debugDescription), expected \(scenario.axValue.debugDescription)")
  }
  if let caret = scenario.caret, draft.selection != NSRange(location: caret, length: 0) {
    problems.append("selection \(draft.selection.location),\(draft.selection.length), expected caret \(caret)")
  }
  return problems.isEmpty ? nil : problems.joined(separator: "; ")
}

func clear(_ draft: SlackDraft, with keyboard: Keyboard) throws {
  try keyboard.press([.escape, .character("i"), .selectAll, .delete])
  for _ in 0..<40 where !draft.isEmpty {
    Thread.sleep(forTimeInterval: 0.05)
  }
  guard draft.isEmpty else { throw Abort("couldn't clear the draft between scenarios") }
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

func open(bundleIdentifier: String?) {
  guard let bundleIdentifier else { return }
  _ = runTool("/usr/bin/open", ["-b", bundleIdentifier])
  Thread.sleep(forTimeInterval: 0.5)
}

func isVimModeRunning() -> Bool {
  runTool("/usr/bin/pgrep", ["-x", "vim-mode"]) == 0
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

func launchVimMode() throws -> Process {
  try? FileManager.default.removeItem(atPath: VimLog.path)
  let process = Process()
  process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
    .appendingPathComponent("vim-mode")
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
