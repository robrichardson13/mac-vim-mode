---
name: verify
description: Test vim-mode against the real Slack message box, or a new TextEdit document, by running scripted keys and reading the field back. Use after changing Sources/VimMode or Sources/VimCore, to reproduce a reported field bug, or when asked to verify or test in Slack.
---

# Verify in real Slack

    swift test                          # engine first: no Slack, no focus taken
    swift build && .build/debug/vim-verify          # every scenario
    .build/debug/vim-verify dd          # scenarios whose name contains "dd"
    .build/debug/vim-verify --textedit  # in a new untitled TextEdit document, instead of Slack
    .build/debug/vim-verify --safety-check  # sees the non-empty-draft refusal and input abort fire
    .build/debug/vim-verify --screenshots   # also saves the field's area per scenario to /tmp/vim-verify-screenshots

Exit codes: 0 all passed, 1 a scenario failed, 2 aborted by a safety check.

## Before running

A run takes Slack's focus for about a minute. Ask Rob first, unless he has said he's away from the machine. Tell him to quit any running `vim-mode`, because the driver starts its own, and that wipes `/tmp/vim-mode.log`.

The self-DM must already be open, with its message box focused and empty.

## TextEdit

The driver opens its own document, gates every key on that window, then closes it through the sheet's Delete and quits TextEdit if it launched it. Don't kill TextEdit mid-run: an abandoned untitled document comes back as a real file in Rob's iCloud TextEdit folder. Don't list or move files under `~/Library/Mobile Documents/` from a tab either, because that hangs on a permission prompt.

`--screenshots` needs Screen Recording for the app running it. Without that it says "not permitted" and runs the scenarios anyway.

`--safety-check` fires the abort with an untagged key, so a real keyboard press and any mouse click stay untested.

## Reading results

- `FAIL` shows the raw `AXValue`, the selection, and any `stopped:` line from vim-mode.
- `grep -E 'stopped:|not applied' /tmp/vim-mode.log` shows failed edit checks. The log's `key` lines show each key's timing, lengths and selection.
- Compare failures with Known gaps in `CLAUDE.md`. A failure listed there isn't new.

## Adding a scenario

Add one line to `Sources/VimVerify/Scenarios.swift`, and mark it `isSlackOnly` if it depends on how Slack misreports an emoji or formats a quote. Then confirm it can fail, by running it against the code without the fix.

- `axValue` is the raw field text: an emoji reads as newlines, an emptied field as `"\n"`, and a blank line doesn't show at all.
- `caretCoversEmoji` checks the caret's bounds, for what the overlay would draw.

## After an abort

The draft may hold test text. The driver refuses to start on a non-empty draft, so don't weaken that check.

- **Slack left the self-DM:** ⌘[ goes back.
- **Test text left in the draft:** clear it only after confirming that the window title is the self-DM and the draft is exactly the text you expect. Anything else may be Rob's, so ask him.
