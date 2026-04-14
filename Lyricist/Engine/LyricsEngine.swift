import Combine
import Foundation

final class LyricsEngine: ObservableObject {

    @Published private(set) var display: LyricsDisplay?
    @Published private(set) var state: EngineState = .idle

    var offset: TimeInterval = 0
    var convertToSimplified: Bool = false

    private let bridge: SpotifyBridge
    private let provider: LyricsProviding
    private let cache: LyricsCache

    private var currentLyrics: Lyrics = .empty
    private var lastLineIndex: Int?
    private var cancellables = Set<AnyCancellable>()

    init(bridge: SpotifyBridge, provider: LyricsProviding, cache: LyricsCache = LyricsCache()) {
        self.bridge = bridge
        self.provider = provider
        self.cache = cache

        setupBindings()
    }

    private func setupBindings() {
        bridge.trackChanged
            .sink { [weak self] state in
                self?.handleTrackChange(state)
            }
            .store(in: &cancellables)

        bridge.$playbackState
            .sink { [weak self] state in
                self?.handlePositionUpdate(state)
            }
            .store(in: &cancellables)
    }

    private func handleTrackChange(_ playback: PlaybackState) {
        lastLineIndex = nil
        display = nil

        if let cached = cache.get(artist: playback.artist, trackName: playback.trackName) {
            currentLyrics = cached
            state = .playing
            return
        }

        state = .loading

        Task { @MainActor in
            do {
                let lyrics = try await provider.fetchLyrics(
                    trackName: playback.trackName,
                    artist: playback.artist
                )
                cache.set(lyrics, artist: playback.artist, trackName: playback.trackName)
                currentLyrics = lyrics
                state = lyrics.lines.isEmpty ? .noLyrics : .playing
            } catch {
                currentLyrics = .empty
                state = .noLyrics
            }
        }
    }

    private func handlePositionUpdate(_ playback: PlaybackState) {
        guard playback.isPlaying, state == .playing, !currentLyrics.lines.isEmpty else {
            return
        }

        guard let index = Self.findCurrentIndex(
            position: playback.position + offset,
            lines: currentLyrics.lines
        ) else {
            if lastLineIndex != nil {
                lastLineIndex = nil
                display = nil
            }
            return
        }

        guard index != lastLineIndex else { return }

        lastLineIndex = index
        display = Self.buildDisplay(
            index: index,
            lines: currentLyrics.lines,
            position: playback.position,
            convertToSimplified: convertToSimplified
        )
    }

    // MARK: - Pure functions (testable)

    static func findCurrentIndex(position: TimeInterval, lines: [LyricsLine]) -> Int? {
        guard !lines.isEmpty else { return nil }

        var low = 0
        var high = lines.count - 1
        var result: Int?

        while low <= high {
            let mid = (low + high) / 2
            if lines[mid].time <= position {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        return result
    }

    static func buildDisplay(index: Int, lines: [LyricsLine], position: TimeInterval, convertToSimplified: Bool = false) -> LyricsDisplay? {
        guard index >= 0, index < lines.count else { return nil }

        let convert: (String) -> String = convertToSimplified
            ? { $0.applyingTransform(StringTransform("Hant-Hans"), reverse: false) ?? $0 }
            : { $0 }

        let previous = index > 0 ? convert(lines[index - 1].text) : nil
        let current = convert(lines[index].text)
        let next = index < lines.count - 1 ? convert(lines[index + 1].text) : nil

        let currentTime = lines[index].time
        let nextTime = index < lines.count - 1 ? lines[index + 1].time : lines[index].time + 5.0
        let duration = nextTime - currentTime
        let progress = duration > 0 ? min((position - currentTime) / duration, 1.0) : 0

        return LyricsDisplay(
            previous: previous,
            current: current,
            next: next,
            progress: progress
        )
    }
}
