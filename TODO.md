# TODO

Known behavior and measurements are in `CLAUDE.md`. Test with `/verify`.

## Now

- [x] Commit this work.
- [ ] Rob: run `scripts/rebuild.sh`, grant Accessibility, and try it on a real keyboard. All testing so far used synthetic key events.
- [ ] Rob: say whether it still feels "not perfect", and what doesn't feel right.

## Failing in `/verify`

- [x] `cw`: make Escape step the caret left everywhere, like real vim, not only at a line end.
- [x] `emoji-at-line-end`: an emoji plus a line break reads as two newlines, not the three `FieldTextMap` assumes. Find a way to tell it from an emoji with no break, then correct `anEmojiAtALineEndKeepsTheLineBreak`, whose input is assumed.
- [x] `emoji-x-before`: `x` before a leading emoji leaves `AXValue` as `"\nb"` and the edit check fails. The emoji survives: the tree still holds its `AXImage`.

## Suspected, needs a scenario

- [x] Indented text: the line-end check assumes a 13-point inset, so quotes and lists may misread a next-line start as a line end.
- [x] Emoji right before a line end: the one-short caret step may stop short of it.
- [x] Blank lines: `FieldTextMap` collapses them, so the engine sees one line fewer than the field.
- [x] A selection that starts at a line end: the fix only handles ranges that end there.
- [x] Caret on an empty line: the `caretCoversEmoji` fix passes unit tests but hasn't been seen in Slack.

## Known limits

- [x] Visual mode's `j` and `k` move by real lines, so they can't step through a wrapped line. Kept: real vim's `j` and `k` do the same.
- [x] Escape in normal mode no longer reaches Slack, so it can't close a thread or dismiss a menu. Kept, because reaching Slack can leave the conversation.
- [ ] Rob: say whether swallowed Escape gets in the way, including an open `:emoji` menu in insert mode.

## Verification loop

- [ ] Rob: grant Screen Recording, then look at a `vim-verify --screenshots` run. It's built and reports "not permitted" cleanly, but has never captured an image.
- [x] Add scenarios for untested commands: `C`, `cc`, `s`, `S`, `O`, `X`, `P`, `de`, `ciw`, `daw`, `k`, `V`, counts and Ctrl-R.
- [x] Test the driver's abort on input, plus its non-empty-draft refusal: `vim-verify --safety-check`. It fires the abort with a synthetic untagged key, so a physical key press and a mouse click are still unseen.
- [x] Fix the "will never be executed" build warning in `Sources/VimVerify/main.swift`.

## Later

- [ ] Prove more apps: run `probes/ax-probe.swift` on each first, because its answers decide how the app gets driven. Slack and TextEdit are proven; Notes, Safari, Chrome and Messages aren't.
- [x] Replace the hardcoded Slack bundle ID in `VimSession.supportedBundleIdentifier`.
- [x] Decide whether `VimCore` and nib's `ComposerVim.swift` ever share code. They stay separate.

## Housekeeping

- [ ] Rob: create a remote and push the branch. It has never been pushed, because no GitHub repo exists.
- [x] Update `~/CLAUDE.md`. It now says Tahoe 26.6 and no longer states free space.
