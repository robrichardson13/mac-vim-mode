# mac-vim-mode

Vim modes for text fields in other Mac apps, driven from outside the app. Any app can opt in; only Slack and TextEdit are proven. Commands and the module layout are in `README.md`.

## Testing

`swift test` covers `VimCore`. `/verify` (`.build/debug/vim-verify`) runs scripted keys in the real Slack message box and reads the field back, so agents can test real-field behavior without Rob pressing keys.

The driver only types in Rob's self-DM, in an empty draft. It checks the window title and focus before every key, never sends plain Return, and stops if he touches the keyboard or mouse. Everywhere else Slack stays read-only from your side: typing into another conversation could reach a real person. To see how a field reports its text, run read-only probes that mask letters, and tell him it's watching.

`vim-verify --safety-check` sees the non-empty-draft refusal and the input abort fire. `vim-verify --textedit` runs the same scenarios in a new untitled TextEdit document the driver opens itself and closes without saving. Never script typing in any other non-Slack document.

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
| Lines | The field's Accessibility tree (`fieldLines`), checked against `AXStringForRange` | `AXLineForIndex`, `AXRangeForLine` (changed only at blank lines) |

The tree is the only source that tells lines apart. Each line is an `AXGroup` of `AXStaticText` and `AXImage` (an emoji); a blank line is an `AXEmptyGroup`. A field with no children, as in TextEdit, or lines that don't match the caret text, falls back to reconciling the two text sources:

- `AXValue` has line breaks, but an emoji reads as newlines whose count depends on its neighbours: `a😀b` and `a😀\nb` both read `"a\n\nb"`, `😀b` reads `"\nb"`, `a😀` reads `"a\n"`, `a😀😀b` reads `"a\n\n\nb"`. A blank line reads as one newline.
- `AXStringForRange` matches caret positions. It omits line breaks and emoji, but keeps a newline for a blank line. Asking past its end returns nothing, so `AXValue`'s length is only an upper bound.

Other quirks:

- A selection across an emoji reads back one longer than requested.
- A line's end and the next line's start share a caret position, and an emoji has no position of its own.
- Escape can leave the conversation: reaching Slack with a draft present, it moved a self-DM to the DMs view, so normal mode swallows it. ⌘[ goes back.
- Setting a caret shared by a line's end and the next line's start lands on the next line. Setting it one short and pressing a real → or ⇧→ stays on this line.
- Both spots read back as the same caret position, but their bounds differ. Compare with the row's first text in the tree, because a quote indents further than plain text.
- A caret on a last blank line reads as the position before that line's newline in `AXStringForRange`.
- A real → from one short of a line end stops before a trailing emoji; ⌘→ passes it.
- Inline code is an `AXGroup` inside its line, with subrole `AXCodeStyleGroup`.
- A new blank line leaves `AXValue` unchanged and only adds a newline to `AXStringForRange`. An emptied field reads `"\n"` from both.
- The system-wide `AXFocusedApplication` returns -25204, and `NSWorkspace.frontmostApplication` goes stale with no run loop. `lsappinfo` reports the frontmost app correctly.
- Caret bounds have zero width in text, about square on an emoji, and the full line width on an empty line.

## Known gaps

`/verify` passes every scenario in Slack 4.52.155 and TextEdit. All of them use synthetic key events.

Not covered by a scenario:

- A line holding only an emoji: the one-short step lands on the line above.
- `x` on the last letter before a trailing emoji leaves the emoji, and so does `D`: a selection stops before it on purpose.
- Fields that fall back to reconciling text sources still collapse a blank line and can misread adjacent emoji as a line break.
- Links, bold and real lists in Slack: the tree shape hasn't been measured, because typing `- ` from the driver doesn't start a list.
- `--screenshots` has never captured an image: Screen Recording isn't granted.
- The driver's abort has only seen a synthetic key, not a physical key press or mouse click.

Decided limits:

- Visual mode's `j` and `k` move by real lines, as real vim's do. Normal mode's move by rows only because they're arrow keys: only the app knows where a line wraps.
- Escape never reaches the app from normal mode, and Escape from insert mode only enters normal mode, so it can't close a thread or dismiss an open menu. Rob hasn't said yet whether this gets in the way.

## Relationship to nib

`VimCore` began as a port of `ComposerVim.swift` in `~/repos/nib`. Decided: they stay separate, with no shared code. It deliberately differs by following real vim on `cw` and `de`, and treating an emoji as one character.
