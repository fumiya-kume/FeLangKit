import Testing
@testable import FeLangCore

@Suite("PositionTracker Tests")
struct PositionTrackerTests {

    // MARK: - Initial State Tests

    @Test func testInitialPosition() throws {
        let tracker = TokenizerUtilities.PositionTracker()
        let pos = tracker.currentPosition
        #expect(pos.line == 1)
        #expect(pos.column == 1)
        #expect(pos.offset == 0)
    }

    // MARK: - advance(past:) Tests

    @Test func testAdvancePastASCIICharacter() throws {
        var tracker = TokenizerUtilities.PositionTracker()
        tracker.advance(past: "a")
        let pos = tracker.currentPosition
        #expect(pos.line == 1)
        #expect(pos.column == 2)
        #expect(pos.offset == 1)
    }

    @Test func testAdvancePastNewline() throws {
        var tracker = TokenizerUtilities.PositionTracker()
        tracker.advance(past: "a")
        tracker.advance(past: "\n")
        let pos = tracker.currentPosition
        #expect(pos.line == 2)
        #expect(pos.column == 1)
        #expect(pos.offset == 2)
    }

    @Test func testAdvancePastMultipleNewlines() throws {
        var tracker = TokenizerUtilities.PositionTracker()
        tracker.advance(past: "\n")
        tracker.advance(past: "\n")
        tracker.advance(past: "\n")
        let pos = tracker.currentPosition
        #expect(pos.line == 4)
        #expect(pos.column == 1)
        #expect(pos.offset == 3)
    }

    @Test func testAdvancePastUnicodeCharacter() throws {
        var tracker = TokenizerUtilities.PositionTracker()
        // "あ" (U+3042) is 1 Unicode scalar
        tracker.advance(past: "あ")
        var pos = tracker.currentPosition
        #expect(pos.column == 2)
        #expect(pos.offset == 1)

        // Flag emoji "🇯🇵" is 2 Unicode scalars (regional indicators)
        tracker.advance(past: "🇯🇵")
        pos = tracker.currentPosition
        #expect(pos.column == 3)
        #expect(pos.offset == 3)
    }

    @Test func testAdvancePastMultiScalarCharacter() throws {
        var tracker = TokenizerUtilities.PositionTracker()
        // "é" composed as e + combining acute accent = 2 Unicode scalars
        let composed = Character("e\u{0301}")
        tracker.advance(past: composed)
        let pos = tracker.currentPosition
        #expect(pos.column == 2)
        #expect(pos.offset == 2)
    }

    // MARK: - advance(through:) Tests

    @Test func testAdvanceThroughSubstring() throws {
        var tracker = TokenizerUtilities.PositionTracker()
        let str = "abc"
        tracker.advance(through: str[...])
        let pos = tracker.currentPosition
        #expect(pos.line == 1)
        #expect(pos.column == 4)
        #expect(pos.offset == 3)
    }

    @Test func testAdvanceThroughSubstringWithNewlines() throws {
        var tracker = TokenizerUtilities.PositionTracker()
        let str = "ab\ncd"
        tracker.advance(through: str[...])
        let pos = tracker.currentPosition
        #expect(pos.line == 2)
        #expect(pos.column == 3)
        #expect(pos.offset == 5)
    }

    @Test func testAdvanceThroughEmptySubstring() throws {
        var tracker = TokenizerUtilities.PositionTracker()
        let str = ""
        tracker.advance(through: str[...])
        let pos = tracker.currentPosition
        #expect(pos.line == 1)
        #expect(pos.column == 1)
        #expect(pos.offset == 0)
    }

    // MARK: - Comprehensive Tests

    @Test func testMultiLineTracking() throws {
        var tracker = TokenizerUtilities.PositionTracker()
        let str = "line1\nline2\nline3"
        tracker.advance(through: str[...])
        let pos = tracker.currentPosition
        #expect(pos.line == 3)
        #expect(pos.column == 6)
        #expect(pos.offset == 17)
    }
}
