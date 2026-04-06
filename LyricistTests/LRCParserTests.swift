import XCTest
@testable import Lyricist

final class LRCParserTests: XCTestCase {

    func testParsesBasicLRC() {
        let lrc = """
        [00:12.34]I've been reading books of old
        [00:16.78]The legends and the myths
        [00:21.45]Achilles and his gold
        """
        let lines = LRCParser.parse(lrc)

        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0].time, 12.34, accuracy: 0.01)
        XCTAssertEqual(lines[0].text, "I've been reading books of old")
        XCTAssertEqual(lines[1].time, 16.78, accuracy: 0.01)
        XCTAssertEqual(lines[2].time, 21.45, accuracy: 0.01)
    }

    func testIgnoresMetadataTags() {
        let lrc = """
        [ti:Something Just Like This]
        [ar:Coldplay]
        [00:12.34]Actual lyric line
        """
        let lines = LRCParser.parse(lrc)

        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].text, "Actual lyric line")
    }

    func testIgnoresEmptyLines() {
        let lrc = """
        [00:12.34]First line

        [00:16.78]Second line
        """
        let lines = LRCParser.parse(lrc)

        XCTAssertEqual(lines.count, 2)
    }

    func testSortsByTime() {
        let lrc = """
        [00:20.00]Second
        [00:10.00]First
        """
        let lines = LRCParser.parse(lrc)

        XCTAssertEqual(lines[0].text, "First")
        XCTAssertEqual(lines[1].text, "Second")
    }

    func testHandlesEmptyInput() {
        let lines = LRCParser.parse("")
        XCTAssertTrue(lines.isEmpty)
    }

    func testIgnoresLinesWithEmptyText() {
        let lrc = """
        [00:12.34]
        [00:16.78]Real lyric
        """
        let lines = LRCParser.parse(lrc)

        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].text, "Real lyric")
    }
}
