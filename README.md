# mac-vim-mode

Vim modes for text fields in other Mac apps. A menu bar app: launching it turns it on, and Settings chooses the apps. Proven in Slack and TextEdit; other apps can opt in but haven't been tested.

    swift test          # engine tests, no Slack needed
    scripts/rebuild.sh  # build and relaunch vim-mode[-<feature>].app; --no-launch to only build
    swift build && .build/debug/vim-verify  # real-field scenarios; see .claude/skills/verify

The app asks for Accessibility in its settings window. It's ad-hoc signed, so a rebuilt bundle may need granting again.

Press Escape in a text field of an opted-in app for normal mode. The menu bar shows the mode, and holds Settings and Quit. Slack is opted in on first run. Secure fields are never handled.

`VimCore` is the pure engine: text and selection in, effects out. `VimMode` applies those effects to the real field: Accessibility reads text and moves the caret, real keystrokes edit, because Slack reports success on Accessibility edits and then ignores them. Lines come from the field's Accessibility tree when it has one, checked against caret positions.

`probes/ax-probe.swift` checks what an app's focused text field actually supports.

`VimVerify` is a dev tool that posts real keystrokes. It types in your Slack self-DM, or a new untitled TextEdit document, and checks the field by re-reading it. For Slack, set `VIM_VERIFY_SLACK_TITLE` to the self-DM's exact window title (`you (DM) - Workspace - Slack`); the driver refuses to run without it, and stops before any key if the focused window's title differs.
