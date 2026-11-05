import Testing

@testable import VimCore

private let slack = "com.tinyspeck.slackmacgap"
private let textEdit = "com.apple.TextEdit"

@Test func theFirstRunStartsWithSlack() {
  #expect(OptInList(stored: nil).contains(slack))
}

@Test func removingEverythingDoesNotBringSlackBack() {
  var list = OptInList(stored: nil)
  list.remove(slack)
  let relaunched = OptInList(stored: list.bundleIdentifiers)
  #expect(!relaunched.contains(slack))
}

@Test func addedAppsSurviveARelaunch() {
  var list = OptInList(stored: nil)
  list.add(textEdit)
  let relaunched = OptInList(stored: list.bundleIdentifiers)
  #expect(relaunched.bundleIdentifiers == [slack, textEdit])
}

@Test func addingAnAppTwiceListsItOnce() {
  var list = OptInList(stored: [textEdit])
  list.add(textEdit)
  #expect(list.bundleIdentifiers == [textEdit])
}

@Test func anAppWithNoBundleIdentifierIsNeverOptedIn() {
  #expect(!OptInList(stored: nil).contains(nil))
}
