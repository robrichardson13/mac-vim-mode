/// `axValue` is the raw field text, so a bug in FieldTextMap can't hide itself: an emoji reads as
/// two newlines there, and an emptied field as one. `caret` is an engine offset, left nil where only
/// the text matters.
struct Scenario {
  let name: String
  let seed: String
  let keys: String
  let axValue: String
  var caret: Int?
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
  Scenario(name: "emoji-x-before", seed: "a😀b", keys: "<esc>0x", axValue: "\n\nb", isSlackOnly: true),
  Scenario(name: "emoji-at-line-end", seed: "a😀\nb", keys: "<esc>", axValue: "a\n\n\nb", isSlackOnly: true),
]
