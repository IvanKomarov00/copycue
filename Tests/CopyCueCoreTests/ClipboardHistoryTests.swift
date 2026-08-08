import Testing
@testable import CopyCueCore

@Test
func capturesOnlyTwoDistinctValues() {
    var history = ClipboardHistory()

    let capturedFirst = history.capture("first")
    let capturedSecond = history.capture("second")
    let capturedThird = history.capture("third")

    #expect(capturedFirst)
    #expect(capturedSecond)
    #expect(capturedThird)
    #expect(history.current == "third")
    #expect(history.previous == "second")
}

@Test
func ignoresDuplicateCurrentValue() {
    var history = ClipboardHistory(current: "current", previous: "previous")

    let capturedDuplicate = history.capture("current")

    #expect(!capturedDuplicate)
    #expect(history.current == "current")
    #expect(history.previous == "previous")
}

@Test
func restorationSwapsCurrentAndPrevious() {
    var history = ClipboardHistory(current: "new", previous: "old")

    #expect(history.restorePrevious() == "old")
    #expect(history.current == "old")
    #expect(history.previous == "new")
}

@Test
func clearRemovesBothValues() {
    var history = ClipboardHistory(current: "new", previous: "old")

    history.clear()

    #expect(history.current == nil)
    #expect(history.previous == nil)
}

@Test
func doesNotRetainOversizedText() {
    var history = ClipboardHistory(current: "current", previous: "previous")
    let oversized = String(
        repeating: "a",
        count: ClipboardHistory.maximumRetainedTextUTF8Bytes + 1
    )
    let captured = history.capture(oversized)

    #expect(!captured)
    #expect(history.current == "current")
    #expect(history.previous == "previous")
}
