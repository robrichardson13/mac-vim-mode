# TODO

Known behavior and measurements are in `CLAUDE.md`. Test with `/verify`.

## Now

- [x] Commit this work.
- [ ] Rob: restart `swift run vim-mode` and try it on a real keyboard. All Slack testing so far used synthetic key events.
- [ ] Rob: say whether it still feels "not perfect", and what doesn't feel right.

## Failing in `/verify`

- [ ] `cw`: make Escape step the caret left everywhere, like real vim, not only at a line end.
- [ ] `emoji-at-line-end`: an emoji plus a line break reads as two newlines, not the three `FieldTextMap` assumes. Find a way to tell it from an emoji with no break, then correct `anEmojiAtALineEndKeepsTheLineBreak`, whose input is assumed.
- [ ] `emoji-x-before`: `x` before a leading emoji leaves `AXValue` as `"\nb"` and the edit check fails. Find out whether the emoji survived.

## Suspected, needs a scenario

- [ ] Indented text: the line-end check assumes a 13-point inset, so quotes and lists may misread a next-line start as a line end.
- [ ] Emoji right before a line end: the one-short caret step may stop short of it.
- [ ] Blank lines: `FieldTextMap` collapses them, so the engine sees one line fewer than the field.
- [ ] A selection that starts at a line end: the fix only handles ranges that end there.
- [ ] Caret on an empty line: the `caretCoversEmoji` fix passes unit tests but hasn't been seen in Slack.

## Known limits

- [ ] Visual mode's `j` and `k` move by real lines, so they can't step through a wrapped line.
- [ ] Escape in normal mode no longer reaches Slack, so it can't close a thread or dismiss a menu. Check whether that gets in the way.

## Verification loop

- [ ] Add a screenshot check, for the overlay and for cases Accessibility can't settle like the emoji ones. Needs Screen Recording permission.
- [ ] Add scenarios for untested commands: `C`, `cc`, `s`, `S`, `O`, `X`, `P`, `de`, `ciw`, `daw`, `k`, `V`, counts and Ctrl-R.
- [ ] Test the driver's abort on keyboard or mouse input, plus its non-empty-draft refusal. Neither has been seen firing in a real run.
- [ ] Fix the "will never be executed" build warning in `Sources/VimVerify/main.swift`.

## Later

- [ ] Support other apps: run `probes/ax-probe.swift` on each first, because its answers decide how the app gets driven.
- [ ] Replace the hardcoded Slack bundle ID in `VimSession.supportedBundleIdentifier`.
- [ ] Decide whether `VimCore` and nib's `ComposerVim.swift` ever share code. They stay separate for now.

## Housekeeping

- [ ] Push the branch. It has never been pushed.
- [ ] Update `~/CLAUDE.md`, which is out of date: it says Sequoia and about 390 GB free, but this Mac is on macOS 26.6 with 179 GB free.
