/// `axValue` is the raw field text, so a bug in FieldTextMap can't hide itself: an emoji reads as
/// newlines there (see CLAUDE.md), and an emptied field as one. `caret` is an engine offset, left nil where only
/// the text matters.
struct Scenario {
  let name: String
  let seed: String
  let keys: String
  let axValue: String
  var caret: Int?
  /// True when the caret should look like it covers an emoji, read from its bounds.
  var caretCoversEmoji: Bool?
  /// Its expectation depends on how Slack misreports an emoji.
  var isSlackOnly = false
}

let scenarios = [
  Scenario(name: "x", seed: "hello", keys: "<esc>0x", axValue: "ello", caret: 0),
  Scenario(name: "esc-in-normal", seed: "one", keys: "<esc><esc>iX", axValue: "onXe"),
  Scenario(name: "ctrl-passes-through", seed: "one", keys: "<esc><c-a>x", axValue: "ne", caret: 0),
  Scenario(name: "dw", seed: "one two three", keys: "<esc>0dw", axValue: "two three", caret: 0),
  Scenario(name: "cw", seed: "one two", keys: "<esc>0cwNEW<esc>", axValue: "NEW two", caret: 2),
  Scenario(name: "dd-only-line", seed: "hello world", keys: "<esc>dd", axValue: "\n", caret: 0),
  Scenario(name: "dd-middle-line", seed: "one\ntwo\nthree", keys: "<esc>ggjdd", axValue: "one\nthree", caret: 4),
  Scenario(name: "A-first-line", seed: "one\ntwo", keys: "<esc>ggAX<esc>", axValue: "oneX\ntwo", caret: 3),
  Scenario(name: "D-first-line", seed: "one\ntwo", keys: "<esc>ggllD", axValue: "on\ntwo"),
  Scenario(name: "line-end-x", seed: "one\ntwo", keys: "<esc>gg$x", axValue: "on\ntwo", caret: 1),
  Scenario(name: "line-end-o", seed: "one\ntwo", keys: "<esc>ggoX", axValue: "one\nX\ntwo"),
  Scenario(name: "line-end-j-to-shorter", seed: "long line\nab\nzz", keys: "<esc>gg$jx", axValue: "long line\na\nzz"),
  Scenario(name: "o", seed: "one", keys: "<esc>oTWO<esc>", axValue: "one\nTWO", caret: 6),
  Scenario(name: "yy-p", seed: "one", keys: "<esc>yyp", axValue: "one\none"),
  Scenario(name: "yy-p-keeps-case", seed: "Ab Cd", keys: "<esc>yyp", axValue: "Ab Cd\nAb Cd"),
  Scenario(name: "u", seed: "one two", keys: "<esc>0dwu", axValue: "one two"),
  Scenario(name: "visual-delete", seed: "one two", keys: "<esc>0ved", axValue: " two", caret: 0),
  Scenario(name: "emoji-x-before", seed: "a😀b", keys: "<esc>0x", axValue: "\nb", caret: 0, isSlackOnly: true),
  // `yy` takes only b's line if the break after the emoji was seen, and "ab" if it wasn't.
  Scenario(name: "emoji-at-line-end", seed: "a😀\nb", keys: "<esc>yyp", axValue: "a\n\nb\nb", isSlackOnly: true),
  Scenario(name: "C", seed: "one two", keys: "<esc>0wCX", axValue: "one X"),
  Scenario(name: "cc", seed: "one\ntwo", keys: "<esc>ggccX", axValue: "X\ntwo"),
  Scenario(name: "s", seed: "one", keys: "<esc>0sX", axValue: "Xne"),
  Scenario(name: "S", seed: "one\ntwo", keys: "<esc>ggSX", axValue: "X\ntwo"),
  Scenario(name: "O-only-line", seed: "one", keys: "<esc>OX", axValue: "X\none"),
  Scenario(name: "O-second-line", seed: "one\ntwo", keys: "<esc>OX", axValue: "one\nX\ntwo"),
  Scenario(name: "X", seed: "one", keys: "<esc>$X", axValue: "oe"),
  Scenario(name: "P", seed: "one two", keys: "<esc>0dw$P", axValue: "twone o"),
  Scenario(name: "de", seed: "one two", keys: "<esc>0de", axValue: " two"),
  Scenario(name: "ciw", seed: "one two", keys: "<esc>0ciwX", axValue: "X two"),
  Scenario(name: "daw", seed: "one two", keys: "<esc>0daw", axValue: "two"),
  Scenario(name: "k", seed: "one\ntwo", keys: "<esc>0kx", axValue: "ne\ntwo"),
  Scenario(name: "V", seed: "one\ntwo\nthree", keys: "<esc>ggjVd", axValue: "one\nthree"),
  Scenario(name: "count-dw", seed: "a b c d", keys: "<esc>02dw", axValue: "c d"),
  Scenario(name: "count-x", seed: "abcd", keys: "<esc>03x", axValue: "d"),
  Scenario(name: "ctrl-r", seed: "one two", keys: "<esc>0dwu<c-r>", axValue: "two"),
  Scenario(name: "u-after-dd-last-line", seed: "one\ntwo", keys: "<esc>ddu", axValue: "one\ntwo"),
  Scenario(name: "dd-last-line", seed: "one\ntwo", keys: "<esc>dd", axValue: "one", caret: 0),
  Scenario(name: "V-d-last-line", seed: "one\ntwo", keys: "<esc>Vd", axValue: "one", caret: 0),
  Scenario(name: "dd-trailing-blank", seed: "one\n", keys: "<esc>dd", axValue: "one"),
  Scenario(name: "quote-next-line-start", seed: "> one\ntwo", keys: "<esc>ggjx", axValue: " one\nwo", isSlackOnly: true),
  Scenario(name: "quote-line-end", seed: "> one\ntwo", keys: "<esc>gg$x", axValue: " on\ntwo", isSlackOnly: true),
  Scenario(name: "inline-code-dd", seed: "`code` b", keys: "<esc>dd", axValue: "\n", isSlackOnly: true),
  Scenario(name: "emoji-before-line-end-A", seed: "a😀\nb", keys: "<esc>ggAX", axValue: "a\n\nX\nb", isSlackOnly: true),
  Scenario(name: "blank-line-jj", seed: "one\n\ntwo", keys: "<esc>ggjjx", axValue: "one\nwo", isSlackOnly: true),
  Scenario(name: "blank-line-dd", seed: "one\n\ntwo", keys: "<esc>ggjddx", axValue: "one\nwo", isSlackOnly: true),
  Scenario(name: "blank-line-caret-isnt-emoji", seed: "one\n\ntwo", keys: "<esc>ggj", axValue: "one\ntwo", caretCoversEmoji: false, isSlackOnly: true),
]
