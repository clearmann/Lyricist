import Foundation

enum LRCParser {

    // Matches: [mm:ss.cc] text  or  [mm:ss.ccc] text
    private static let lineRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(
            pattern: #"^\[(\d{2}):(\d{2})\.(\d{2,3})\]\s*(.+)"#
        )
    }()

    static func parse(_ raw: String) -> [LyricsLine] {
        raw
            .components(separatedBy: .newlines)
            .compactMap(parseLine)
            .sorted { $0.time < $1.time }
    }

    private static func parseLine(_ line: String) -> LyricsLine? {
        let range = NSRange(line.startIndex..., in: line)
        guard let match = lineRegex.firstMatch(in: line, range: range),
              match.numberOfRanges == 5 else {
            return nil
        }

        guard
            let minutesRange = Range(match.range(at: 1), in: line),
            let secondsRange = Range(match.range(at: 2), in: line),
            let centisRange  = Range(match.range(at: 3), in: line),
            let textRange    = Range(match.range(at: 4), in: line)
        else {
            return nil
        }

        let minutes      = Double(line[minutesRange]) ?? 0
        let seconds      = Double(line[secondsRange]) ?? 0
        let centisStr    = String(line[centisRange])
        let centiseconds = Double(centisStr) ?? 0
        let divisor      = centisStr.count == 3 ? 1000.0 : 100.0

        let time = minutes * 60 + seconds + centiseconds / divisor
        let text = line[textRange].trimmingCharacters(in: .whitespaces)

        guard !text.isEmpty else { return nil }

        return LyricsLine(time: time, text: text)
    }
}
