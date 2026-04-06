import Foundation

struct LyricsDisplay: Equatable {
    let previous: String?
    let current: String
    let next: String?
    let progress: Double
}

enum EngineState: Equatable {
    case idle
    case loading
    case playing
    case noLyrics
    case error(String)
}
