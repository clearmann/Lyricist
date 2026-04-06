import XCTest
@testable import Lyricist

final class LyricsEngineTests: XCTestCase {

    func testCurrentLineAtStart() {
        let lines = [
            LyricsLine(time: 5.0, text: "First"),
            LyricsLine(time: 10.0, text: "Second"),
            LyricsLine(time: 15.0, text: "Third"),
        ]
        let result = LyricsEngine.findCurrentIndex(position: 0, lines: lines)
        XCTAssertNil(result)
    }

    func testCurrentLineAtExactTime() {
        let lines = [
            LyricsLine(time: 5.0, text: "First"),
            LyricsLine(time: 10.0, text: "Second"),
            LyricsLine(time: 15.0, text: "Third"),
        ]
        let result = LyricsEngine.findCurrentIndex(position: 10.0, lines: lines)
        XCTAssertEqual(result, 1)
    }

    func testCurrentLineBetweenTimes() {
        let lines = [
            LyricsLine(time: 5.0, text: "First"),
            LyricsLine(time: 10.0, text: "Second"),
            LyricsLine(time: 15.0, text: "Third"),
        ]
        let result = LyricsEngine.findCurrentIndex(position: 12.0, lines: lines)
        XCTAssertEqual(result, 1)
    }

    func testCurrentLineAtLastLine() {
        let lines = [
            LyricsLine(time: 5.0, text: "First"),
            LyricsLine(time: 10.0, text: "Second"),
        ]
        let result = LyricsEngine.findCurrentIndex(position: 999.0, lines: lines)
        XCTAssertEqual(result, 1)
    }

    func testCurrentLineEmptyLines() {
        let result = LyricsEngine.findCurrentIndex(position: 5.0, lines: [])
        XCTAssertNil(result)
    }

    func testBuildDisplay() {
        let lines = [
            LyricsLine(time: 5.0, text: "First"),
            LyricsLine(time: 10.0, text: "Second"),
            LyricsLine(time: 15.0, text: "Third"),
        ]
        let display = LyricsEngine.buildDisplay(index: 1, lines: lines, position: 12.0)

        XCTAssertEqual(display?.previous, "First")
        XCTAssertEqual(display?.current, "Second")
        XCTAssertEqual(display?.next, "Third")
    }

    func testBuildDisplayFirstLine() {
        let lines = [
            LyricsLine(time: 5.0, text: "First"),
            LyricsLine(time: 10.0, text: "Second"),
        ]
        let display = LyricsEngine.buildDisplay(index: 0, lines: lines, position: 6.0)

        XCTAssertNil(display?.previous)
        XCTAssertEqual(display?.current, "First")
        XCTAssertEqual(display?.next, "Second")
    }

    func testBuildDisplayLastLine() {
        let lines = [
            LyricsLine(time: 5.0, text: "First"),
            LyricsLine(time: 10.0, text: "Last"),
        ]
        let display = LyricsEngine.buildDisplay(index: 1, lines: lines, position: 11.0)

        XCTAssertEqual(display?.previous, "First")
        XCTAssertEqual(display?.current, "Last")
        XCTAssertNil(display?.next)
    }
}
