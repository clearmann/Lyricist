import Foundation

final class NeteaseProvider: LyricsProviding {

    private let session: URLSession
    private let baseURL = "https://music.163.com"

    private lazy var headers: [String: String] = [
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
        "Referer": "https://music.163.com/",
    ]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchLyrics(trackName: String, artist: String) async throws -> Lyrics {
        let cleanedName = LRCLIBProvider.cleanTrackName(trackName)

        // 1. Search with track + artist
        if let songId = try? await searchSongId(trackName: cleanedName, artist: artist) {
            if let lyrics = try? await fetchLyricsById(songId) {
                return lyrics
            }
        }

        // 2. Fallback: search with track name only, take first with synced lyrics
        return try await fetchBestMatch(trackName: cleanedName)
    }

    // MARK: - Search

    private func searchSongId(trackName: String, artist: String) async throws -> Int {
        let query = "\(trackName) \(artist)"
        let results = try await search(query: query)

        // Prefer a result whose artist name contains the target artist
        let normalizedArtist = artist.lowercased()
        for song in results {
            let songArtists = song.artists.map { $0.lowercased() }.joined(separator: " ")
            if songArtists.contains(normalizedArtist) || normalizedArtist.contains(songArtists) {
                return song.id
            }
        }

        // Accept first result if artist name has at least one matching character token
        if let first = results.first {
            return first.id
        }

        throw LyricsError.notFound
    }

    private func fetchBestMatch(trackName: String) async throws -> Lyrics {
        let results = try await search(query: trackName)
        for song in results {
            if let lyrics = try? await fetchLyricsById(song.id) {
                return lyrics
            }
        }
        throw LyricsError.notFound
    }

    // MARK: - API calls

    private struct SongResult {
        let id: Int
        let name: String
        let artists: [String]
    }

    private func search(query: String) async throws -> [SongResult] {
        var components = URLComponents(string: "\(baseURL)/api/search/get")!
        components.queryItems = [
            URLQueryItem(name: "s", value: query),
            URLQueryItem(name: "type", value: "1"),
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "offset", value: "0"),
        ]

        guard let url = components.url else { throw LyricsError.parseError }

        var request = URLRequest(url: url)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LyricsError.notFound
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let songs = result["songs"] as? [[String: Any]]
        else {
            throw LyricsError.notFound
        }

        return songs.compactMap { song -> SongResult? in
            guard let id = song["id"] as? Int,
                  let name = song["name"] as? String,
                  let artists = song["artists"] as? [[String: Any]]
            else { return nil }

            let artistNames = artists.compactMap { $0["name"] as? String }
            return SongResult(id: id, name: name, artists: artistNames)
        }
    }

    private func fetchLyricsById(_ id: Int) async throws -> Lyrics {
        var components = URLComponents(string: "\(baseURL)/api/song/lyric")!
        components.queryItems = [
            URLQueryItem(name: "id", value: "\(id)"),
            URLQueryItem(name: "lv", value: "-1"),
            URLQueryItem(name: "tv", value: "-1"),
        ]

        guard let url = components.url else { throw LyricsError.parseError }

        var request = URLRequest(url: url)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LyricsError.notFound
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let lrc = json["lrc"] as? [String: Any],
              let lyric = lrc["lyric"] as? String,
              !lyric.isEmpty
        else {
            throw LyricsError.notFound
        }

        let lines = LRCParser.parse(lyric)
        guard !lines.isEmpty else { throw LyricsError.notFound }

        return Lyrics(lines: lines, source: "netease")
    }
}
