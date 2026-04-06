import Foundation

final class LyricsCache {

    private var cache: [String: Lyrics] = [:]

    func get(artist: String, trackName: String) -> Lyrics? {
        cache[cacheKey(artist: artist, trackName: trackName)]
    }

    func set(_ lyrics: Lyrics, artist: String, trackName: String) {
        cache[cacheKey(artist: artist, trackName: trackName)] = lyrics
    }

    func clear() {
        cache = [:]
    }

    private func cacheKey(artist: String, trackName: String) -> String {
        "\(artist.lowercased())-\(trackName.lowercased())"
    }
}
