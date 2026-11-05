# mac-vim-mode

Vim modes for text fields in other Mac apps. A menu bar app: launching it turns it on, and Settings chooses the apps. Proven in Slack and TextEdit; other apps can opt in but haven't been tested.

## How to use

1. Build and launch: `scripts/rebuild.sh`. The app lands in `.build/app/vim-mode.app` and shows up in the menu bar.
2. Grant Accessibility when the settings window asks (System Settings → Privacy & Security → Accessibility). It's ad-hoc signed, so a rebuilt bundle may need granting again.
3. Choose apps under Settings in the menu bar. Slack is opted in on first run.
4. In a text field of an opted-in app, press Escape for normal mode. `i`, `a`, `o` and the rest go back to insert mode. The menu bar shows the current mode.

Supported: `h j k l w b e W B E 0 ^ $ gg G`, counts, `d c y` with motions, `dd cc yy`, `iw aw`, `x X D C s S p P`, `u` and Ctrl-R, `v` and `V`. Return in normal mode is swallowed, so it never sends a message. Secure fields are never handled.

The app never logs what you type: its log at `/tmp/vim-mode.log` holds lengths, ranges and command keys only.

## Development

    swift test          # engine tests, no Slack needed
    scripts/rebuild.sh  # build and relaunch vim-mode[-<feature>].app; --no-launch to only build
    swift build && .build/debug/vim-verify  # real-field scenarios; see .claude/skills/verify

`VimCore` is the pure engine: text and selection in, effects out. `VimMode` applies those effects to the real field: Accessibility reads text and moves the caret, real keystrokes edit, because Slack reports success on Accessibility edits and then ignores them. Lines come from the field's Accessibility tree when it has one, checked against caret positions.

`probes/ax-probe.swift` checks what an app's focused text field actually supports.

`VimVerify` is a dev tool that posts real keystrokes. It types in your Slack self-DM, or a new untitled TextEdit document, and checks the field by re-reading it. For Slack, set `VIM_VERIFY_SLACK_TITLE` to the self-DM's exact window title (`you (DM) - Workspace - Slack`); the driver refuses to run without it, and stops before any key if the focused window's title differs.
