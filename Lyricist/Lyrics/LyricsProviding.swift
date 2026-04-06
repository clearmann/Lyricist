import Foundation

protocol LyricsProviding {
    func fetchLyrics(trackName: String, artist: String) async throws -> Lyrics
}

enum LyricsError: Error, LocalizedError {
    case notFound
    case networkError(Error)
    case parseError

    var errorDescription: String? {
        switch self {
        case .notFound: return "No lyrics found"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .parseError: return "Failed to parse lyrics"
        }
    }
}
