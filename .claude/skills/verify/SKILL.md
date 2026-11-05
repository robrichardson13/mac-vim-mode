---
name: verify
description: Test vim-mode against the real Slack message box by running scripted keys and reading the field back. Use after changing Sources/VimMode or Sources/VimCore, to reproduce a reported field bug, or when asked to verify or test in Slack.
---

# Verify in real Slack

    swift test                          # engine first: no Slack, no focus taken
    swift build && .build/debug/vim-verify          # every scenario
    .build/debug/vim-verify dd          # scenarios whose name contains "dd"

Exit codes: 0 all passed, 1 a scenario failed, 2 aborted by a safety check.

## Before running

A run takes Slack's focus for about a minute. Ask Rob first, unless he has said he's away from the machine. Tell him to quit any running `vim-mode`, because the driver starts its own, and that wipes `/tmp/vim-mode.log`.

The self-DM must already be open, with its message box focused and empty.

## Reading results

- `FAIL` shows the raw `AXValue`, the selection, and any `stopped:` line from vim-mode.
- `grep -E 'stopped:|not applied' /tmp/vim-mode.log` shows failed edit checks. The log's `key` lines show each key's timing, lengths and selection.
- Compare failures with Known gaps in `CLAUDE.md`. A failure listed there isn't new.

## Adding a scenario

Add one line to `Sources/VimVerify/Scenarios.swift`. Then confirm it can fail, by running it against the code without the fix.

- `axValue` is the raw field text: an emoji reads as newlines, an emptied field as `"\n"`, and a blank line doesn't show at all.

## After an abort

The draft may hold test text. The driver refuses to start on a non-empty draft, so don't weaken that check.

- **Slack left the self-DM:** ⌘[ goes back.
- **Test text left in the draft:** clear it only after confirming that the window title is the self-DM and the draft is exactly the text you expect. Anything else may be Rob's, so ask him.
