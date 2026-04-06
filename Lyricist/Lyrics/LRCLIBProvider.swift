import Foundation

final class LRCLIBProvider: LyricsProviding {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchLyrics(trackName: String, artist: String) async throws -> Lyrics {
        let cleanedName = Self.cleanTrackName(trackName)

        // Try exact match first
        if let lyrics = try? await fetchExact(trackName: cleanedName, artist: artist) {
            return lyrics
        }

        // Fallback: search API with just the track name
        return try await fetchViaSearch(trackName: cleanedName)
    }

    // MARK: - Exact match

    private func fetchExact(trackName: String, artist: String) async throws -> Lyrics {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: trackName),
            URLQueryItem(name: "artist_name", value: artist),
        ]

        return try await request(url: components.url!)
    }

    // MARK: - Search fallback

    private func fetchViaSearch(trackName: String) async throws -> Lyrics {
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: trackName),
        ]

        guard let url = components.url else {
            throw LyricsError.parseError
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw LyricsError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LyricsError.notFound
        }

        guard let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw LyricsError.notFound
        }

        // Find the first result with synced lyrics
        for result in results {
            if let syncedLyrics = result["syncedLyrics"] as? String {
                let lines = LRCParser.parse(syncedLyrics)
                if !lines.isEmpty {
                    return Lyrics(lines: lines, source: "lrclib")
                }
            }
        }

        throw LyricsError.notFound
    }

    // MARK: - Shared request

    private func request(url: URL) async throws -> Lyrics {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw LyricsError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LyricsError.networkError(URLError(.badServerResponse))
        }

        guard httpResponse.statusCode == 200 else {
            throw LyricsError.notFound
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let syncedLyrics = json["syncedLyrics"] as? String else {
            throw LyricsError.notFound
        }

        let lines = LRCParser.parse(syncedLyrics)

        guard !lines.isEmpty else {
            throw LyricsError.notFound
        }

        return Lyrics(lines: lines, source: "lrclib")
    }

    // MARK: - Track name cleaning

    static func cleanTrackName(_ name: String) -> String {
        var cleaned = name

        // Remove common suffixes: "- Cover", "- Live", "- Remix", etc.
        let suffixPattern = #"\s*[-–—]\s*(Cover|Live|Remix|Remaster(ed)?|Acoustic|Demo|Radio Edit|Deluxe|Bonus Track).*$"#
        if let regex = try? NSRegularExpression(pattern: suffixPattern, options: .caseInsensitive) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = regex.stringByReplacingMatches(in: cleaned, range: range, withTemplate: "")
        }

        // Remove content in parentheses: "(feat. ...)", "(Live)", etc.
        let parenPattern = #"\s*\((?:feat\.?|ft\.?|Live|Cover|Remix|Remaster(ed)?|Acoustic|Demo).*?\)"#
        if let regex = try? NSRegularExpression(pattern: parenPattern, options: .caseInsensitive) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = regex.stringByReplacingMatches(in: cleaned, range: range, withTemplate: "")
        }

        return cleaned.trimmingCharacters(in: .whitespaces)
    }
}
