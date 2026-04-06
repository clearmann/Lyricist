import Foundation

struct LyricsLine: Equatable {
    let time: TimeInterval
    let text: String
}

struct Lyrics: Equatable {
    let lines: [LyricsLine]
    let source: String

    static let empty = Lyrics(lines: [], source: "")
}
