# mac-vim-mode

Vim modes for text fields in other Mac apps, driven from outside the app. Slack only so far. Commands and the module layout are in `README.md`.

## Testing

`swift test` covers `VimCore`. `/verify` (`.build/debug/vim-verify`) runs scripted keys in the real Slack message box and reads the field back, so agents can test real-field behavior without Rob pressing keys.

The driver only types in Rob's self-DM, in an empty draft. It checks the window title and focus before every key, never sends plain Return, and stops if he touches the keyboard or mouse. Everywhere else Slack stays read-only from your side: typing into another conversation could reach a real person. To see how a field reports its text, run read-only probes that mask letters, and tell him it's watching.

`vim-verify --textedit` runs the same scenarios in a new untitled TextEdit document the driver opens itself and closes without saving. Never script typing in any other non-Slack document.

`/tmp/ax-probe` is built from `probes/ax-probe.swift` with `swiftc`. Run it first on any new app, because its answers decide how that app gets driven.

## Invariants

Each of these caused a real bug or guards against a costly one.

- **Handle keys off the tap thread.** Our own posted keystrokes pass through the tap, so if handling a key blocks its thread, they can't reach the app until that handling ends, and an edit waited on from there never lands.
- **Confirm by re-reading the field.** Slack returns success for writes it ignores. Send each edit once: a retry that follows a wrong read deletes extra text.
- **Reposted keys are new events.** A copy of a tapped event keeps its original user data at the tap even after re-tagging, so the tap captures it again in a loop.
- **Newlines go out as Shift-Return.** Return sends the message in Slack, so typed text never carries a newline, and Return in normal mode is swallowed.
- **Insert mode makes no Accessibility calls**, except on Escape, so typing stays instant.
- **The log holds lengths, ranges and command keys only**, never message text.

## Slack's Accessibility behavior

Measured on Slack 4.52.155 (Electron 44), after setting `AXManualAccessibility`. Treat success codes and "settable" flags as unproven elsewhere too.

| Need | Works | Doesn't |
|---|---|---|
| Edit | Real key events after selecting | Setting `AXSelectedText` (returns success, changes nothing), `AXReplaceRangeWithText` (-25212) |
| Caret and selection | Reading and setting `AXSelectedTextRange` | |
| Caret position on screen | `AXBoundsForTextMarkerRange` on `AXSelectedTextMarkerRange` | `AXBoundsForRange` (constant `0,982,0x0`) |
| Lines | Rebuilding from both text sources (`FieldTextMap`) | `AXLineForIndex`, `AXRangeForLine` (changed only at blank lines) |

Two text sources disagree, and `FieldTextMap` reconciles them:

- `AXValue` has line breaks, but shows an emoji as two newlines. It also shows a blank line as one newline.
- `AXStringForRange` matches caret positions. It omits line breaks and emoji, but keeps a newline for a blank line. Asking past its end returns nothing, so `AXValue`'s length is only an upper bound.

Other quirks:

- A selection across an emoji reads back one longer than requested.
- A line's end and the next line's start share a caret position, and an emoji has no position of its own.
- Escape can leave the conversation: reaching Slack with a draft present, it moved a self-DM to the DMs view, so normal mode swallows it. ⌘[ goes back.
- Setting a caret shared by a line's end and the next line's start lands on the next line. Setting it one short and pressing a real → or ⇧→ stays on this line.
- Both spots read back as the same caret position, but their bounds differ: the message box starts text 13 points in from its frame.
- A new blank line leaves `AXValue` unchanged and only adds a newline to `AXStringForRange`. An emptied field reads `"\n"` from both.
- The system-wide `AXFocusedApplication` returns -25204, and `NSWorkspace.frontmostApplication` goes stale with no run loop. `lsappinfo` reports the frontmost app correctly.
- Caret bounds have zero width in text, about square on an emoji, and the full line width on an empty line.

## Known gaps

`/verify` fails these three scenarios in Slack 4.52.155:

- `cw`: Escape only steps the caret back at a line end. Real vim always steps left.
- `emoji-at-line-end`: an emoji with a line break after it reads as two newlines, not the three `FieldTextMap` assumes, so it can look like an emoji with no break.
- `emoji-x-before`: deleting a character before a leading emoji leaves `AXValue` as `"\nb"` and the edit check fails. Whether the emoji survived is unknown.

Not covered by a scenario:

- The line-end test assumes unindented text, so a quote or list may misread a next-line start as a line end.
- The one-short step assumes a character before the line end, so an emoji there may stop short of it.
- `FieldTextMap` collapses a blank line, so the engine's text has one line fewer than the field.
- Visual mode's `j` and `k` move by real lines, so they can't step through a wrapped line.

## Relationship to nib

`VimCore` began as a port of `ComposerVim.swift` in `~/repos/nib`, which stays separate for now. It deliberately differs by following real vim on `cw` and `de`, and treating an emoji as one character.
