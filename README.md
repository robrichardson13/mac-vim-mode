# mac-vim-mode

Vim modes for text fields in other Mac apps. Currently Slack only.

    swift test          # engine tests, no Slack needed
    swift run vim-mode  # needs Accessibility for the app running it

Press Escape in a Slack message box for normal mode. The menu bar shows the mode. Press Ctrl-C in the terminal to quit.

`VimCore` is the pure engine: text and selection in, effects out. `VimMode` applies those effects to the real field: Accessibility reads text and moves the caret, real keystrokes edit, because Slack reports success on Accessibility edits and then ignores them.

`probes/ax-probe.swift` checks what an app's focused text field actually supports.
