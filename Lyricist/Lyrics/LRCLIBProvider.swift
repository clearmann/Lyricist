import Foundation

final class LRCLIBProvider: LyricsProviding {

    private let session: URLSession
    private let baseURL = "https://lrclib.net/api/get"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchLyrics(trackName: String, artist: String) async throws -> Lyrics {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: trackName),
            URLQueryItem(name: "artist_name", value: artist),
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
}
