# Lyricist MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menu bar app that detects Spotify playback via AppleScript, fetches synced lyrics from LRCLIB, and displays them in a floating desktop overlay.

**Architecture:** SwiftUI + AppKit hybrid. NSPanel for the always-on-top transparent lyrics overlay, NSStatusItem for menu bar presence. Combine-based data flow: SpotifyBridge publishes playback state → LyricsEngine coordinates lyrics fetch and line sync → UI subscribes and renders.

**Tech Stack:** Swift 5.9+, macOS 13+, SwiftUI, AppKit (NSPanel), Combine, URLSession, NSAppleScript. Zero external dependencies.

---

## File Map

| File | Responsibility |
|------|----------------|
| `Lyricist/App/LyricistApp.swift` | App entry point, menu bar app configuration |
| `Lyricist/App/AppDelegate.swift` | NSPanel lifecycle, global keyboard monitor |
| `Lyricist/Models/PlaybackState.swift` | Spotify playback state data model |
| `Lyricist/Models/LyricsLine.swift` | Lyrics + LyricsLine data models |
| `Lyricist/Models/LyricsDisplay.swift` | Engine output model for UI consumption |
| `Lyricist/Bridge/SpotifyBridge.swift` | AppleScript polling for Spotify state |
| `Lyricist/Lyrics/LyricsProviding.swift` | Protocol for lyrics providers |
| `Lyricist/Lyrics/LRCParser.swift` | LRC format parser |
| `Lyricist/Lyrics/LRCLIBProvider.swift` | LRCLIB API client |
| `Lyricist/Lyrics/LyricsCache.swift` | In-memory lyrics cache |
| `Lyricist/Engine/LyricsEngine.swift` | Core engine: coordinates bridge + provider, computes current line |
| `Lyricist/Settings/SettingsStore.swift` | UserDefaults-backed settings |
| `Lyricist/UI/FloatingPanel.swift` | NSPanel subclass for floating overlay |
| `Lyricist/UI/FloatingLyricsView.swift` | SwiftUI lyrics text rendering |
| `Lyricist/UI/MenuBarController.swift` | NSStatusItem + NSPopover management |
| `Lyricist/UI/PopoverView.swift` | SwiftUI popover content |
| `LyricistTests/LRCParserTests.swift` | LRC parser unit tests |
| `LyricistTests/LyricsEngineTests.swift` | Engine line-sync logic tests |

---

### Task 1: Xcode Project Scaffolding

**Files:**
- Create: Xcode project via `swift package init` or Xcode template
- Create: `Lyricist/App/LyricistApp.swift`
- Create: `Lyricist/App/AppDelegate.swift`
- Create: `Lyricist/Info.plist` (configure LSUIElement, AppleEvents description)

- [ ] **Step 1: Create Xcode project structure**

Create the project directory structure and all empty source folders:

```bash
mkdir -p Lyricist/{App,Models,Bridge,Lyrics,Engine,UI,Settings}
mkdir -p LyricistTests
```

- [ ] **Step 2: Create Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Lyricist",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Lyricist",
            path: "Lyricist",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate",
                              "-Xlinker", "__TEXT",
                              "-Xlinker", "__info_plist",
                              "-Xlinker", "Lyricist/Info.plist"])
            ]
        ),
        .testTarget(
            name: "LyricistTests",
            dependencies: ["Lyricist"],
            path: "LyricistTests"
        ),
    ]
)
```

- [ ] **Step 3: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Lyricist</string>
    <key>CFBundleIdentifier</key>
    <string>com.lyricist.app</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Lyricist needs access to Spotify to display synchronized lyrics.</string>
</dict>
</plist>
```

- [ ] **Step 4: Create LyricistApp.swift**

```swift
import SwiftUI

@main
struct LyricistApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

- [ ] **Step 5: Create AppDelegate.swift (minimal)**

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Will be populated in later tasks
    }
}
```

- [ ] **Step 6: Verify project builds**

Run: `swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add Lyricist/ LyricistTests/ Package.swift
git commit -m "chore: scaffold Lyricist project with SwiftPM"
```

---

### Task 2: Data Models

**Files:**
- Create: `Lyricist/Models/PlaybackState.swift`
- Create: `Lyricist/Models/LyricsLine.swift`
- Create: `Lyricist/Models/LyricsDisplay.swift`

- [ ] **Step 1: Create PlaybackState.swift**

```swift
import Foundation

struct PlaybackState: Equatable {
    let trackId: String
    let trackName: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let position: TimeInterval
    let isPlaying: Bool

    static let empty = PlaybackState(
        trackId: "",
        trackName: "",
        artist: "",
        album: "",
        duration: 0,
        position: 0,
        isPlaying: false
    )
}
```

- [ ] **Step 2: Create LyricsLine.swift**

```swift
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
```

- [ ] **Step 3: Create LyricsDisplay.swift**

```swift
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
```

- [ ] **Step 4: Verify build**

Run: `swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Lyricist/Models/
git commit -m "feat: add core data models"
```

---

### Task 3: LRC Parser with TDD

**Files:**
- Create: `Lyricist/Lyrics/LRCParser.swift`
- Create: `LyricistTests/LRCParserTests.swift`

- [ ] **Step 1: Write failing tests for LRC parser**

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter LRCParserTests`
Expected: FAIL — `LRCParser` not found

- [ ] **Step 3: Implement LRCParser**

```swift
import Foundation

enum LRCParser {

    private static let linePattern = /\[(\d{2}):(\d{2})\.(\d{2,3})\]\s*(.+)/

    static func parse(_ raw: String) -> [LyricsLine] {
        raw
            .components(separatedBy: .newlines)
            .compactMap(parseLine)
            .sorted { $0.time < $1.time }
    }

    private static func parseLine(_ line: String) -> LyricsLine? {
        guard let match = line.firstMatch(of: linePattern) else {
            return nil
        }

        let minutes = Double(match.1) ?? 0
        let seconds = Double(match.2) ?? 0
        let centiseconds = Double(match.3) ?? 0
        let divisor = match.3.count == 3 ? 1000.0 : 100.0

        let time = minutes * 60 + seconds + centiseconds / divisor
        let text = String(match.4).trimmingCharacters(in: .whitespaces)

        guard !text.isEmpty else { return nil }

        return LyricsLine(time: time, text: text)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter LRCParserTests`
Expected: All 6 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Lyricist/Lyrics/LRCParser.swift LyricistTests/LRCParserTests.swift
git commit -m "feat: add LRC parser with full test coverage"
```

---

### Task 4: Lyrics Provider (Protocol + LRCLIB + Cache)

**Files:**
- Create: `Lyricist/Lyrics/LyricsProviding.swift`
- Create: `Lyricist/Lyrics/LRCLIBProvider.swift`
- Create: `Lyricist/Lyrics/LyricsCache.swift`

- [ ] **Step 1: Create LyricsProviding protocol**

```swift
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
```

- [ ] **Step 2: Create LRCLIBProvider**

```swift
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

        let (data, response) : (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw LyricsError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LyricsError.networkError(
                URLError(.badServerResponse)
            )
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
```

- [ ] **Step 3: Create LyricsCache**

```swift
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
```

- [ ] **Step 4: Verify build**

Run: `swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Lyricist/Lyrics/
git commit -m "feat: add LRCLIB lyrics provider with cache"
```

---

### Task 5: SpotifyBridge

**Files:**
- Create: `Lyricist/Bridge/SpotifyBridge.swift`

- [ ] **Step 1: Implement SpotifyBridge**

```swift
import AppKit
import Combine

final class SpotifyBridge: ObservableObject {

    @Published private(set) var playbackState: PlaybackState = .empty
    @Published private(set) var isSpotifyRunning: Bool = false

    private var timer: Timer?
    private var lastTrackId: String = ""
    private var cancellables = Set<AnyCancellable>()

    let trackChanged = PassthroughSubject<PlaybackState, Never>()

    init() {
        observeSpotifyLaunch()
        updateSpotifyRunning()
        if isSpotifyRunning {
            startPolling()
        }
    }

    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        guard isSpotifyRunning else {
            stopPolling()
            return
        }

        let script = """
        tell application "Spotify"
            if player state is stopped then
                return "stopped"
            end if
            set trackId to id of current track
            set trackName to name of current track
            set trackArtist to artist of current track
            set trackAlbum to album of current track
            set trackDuration to duration of current track
            set playerPosition to player position
            set playerState to player state as string
            return trackId & "|||" & trackName & "|||" & trackArtist & "|||" & trackAlbum & "|||" & (trackDuration as string) & "|||" & (playerPosition as string) & "|||" & playerState
        end tell
        """

        guard let appleScript = NSAppleScript(source: script) else { return }

        var error: NSDictionary?
        let output = appleScript.executeAndReturnError(&error)

        guard error == nil else { return }

        let result = output.stringValue ?? ""

        guard result != "stopped" else {
            playbackState = PlaybackState(
                trackId: playbackState.trackId,
                trackName: playbackState.trackName,
                artist: playbackState.artist,
                album: playbackState.album,
                duration: playbackState.duration,
                position: playbackState.position,
                isPlaying: false
            )
            return
        }

        let parts = result.components(separatedBy: "|||")
        guard parts.count == 7 else { return }

        let newState = PlaybackState(
            trackId: parts[0],
            trackName: parts[1],
            artist: parts[2],
            album: parts[3],
            duration: (Double(parts[4]) ?? 0) / 1000.0,
            position: Double(parts[5]) ?? 0,
            isPlaying: parts[6] == "playing"
        )

        let trackDidChange = newState.trackId != lastTrackId
        lastTrackId = newState.trackId
        playbackState = newState

        if trackDidChange {
            trackChanged.send(newState)
        }
    }

    private func updateSpotifyRunning() {
        isSpotifyRunning = NSWorkspace.shared.runningApplications
            .contains { $0.bundleIdentifier == "com.spotify.client" }
    }

    private func observeSpotifyLaunch() {
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .sink { [weak self] notification in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      app.bundleIdentifier == "com.spotify.client" else { return }
                self?.isSpotifyRunning = true
                self?.startPolling()
            }
            .store(in: &cancellables)

        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didTerminateApplicationNotification)
            .sink { [weak self] notification in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      app.bundleIdentifier == "com.spotify.client" else { return }
                self?.isSpotifyRunning = false
                self?.stopPolling()
                self?.playbackState = .empty
            }
            .store(in: &cancellables)
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Lyricist/Bridge/SpotifyBridge.swift
git commit -m "feat: add SpotifyBridge with AppleScript polling"
```

---

### Task 6: LyricsEngine with TDD

**Files:**
- Create: `Lyricist/Engine/LyricsEngine.swift`
- Create: `LyricistTests/LyricsEngineTests.swift`

- [ ] **Step 1: Write failing tests for line sync logic**

```swift
import XCTest
@testable import Lyricist

final class LyricsEngineTests: XCTestCase {

    func testCurrentLineAtStart() {
        let lines = [
            LyricsLine(time: 5.0, text: "First"),
            LyricsLine(time: 10.0, text: "Second"),
            LyricsLine(time: 15.0, text: "Third"),
        ]
        let result = LyricsEngine.findCurrentIndex(position: 0, lines: lines)
        XCTAssertNil(result)
    }

    func testCurrentLineAtExactTime() {
        let lines = [
            LyricsLine(time: 5.0, text: "First"),
            LyricsLine(time: 10.0, text: "Second"),
            LyricsLine(time: 15.0, text: "Third"),
        ]
        let result = LyricsEngine.findCurrentIndex(position: 10.0, lines: lines)
        XCTAssertEqual(result, 1)
    }

    func testCurrentLineBetweenTimes() {
        let lines = [
            LyricsLine(time: 5.0, text: "First"),
            LyricsLine(time: 10.0, text: "Second"),
            LyricsLine(time: 15.0, text: "Third"),
        ]
        let result = LyricsEngine.findCurrentIndex(position: 12.0, lines: lines)
        XCTAssertEqual(result, 1)
    }

    func testCurrentLineAtLastLine() {
        let lines = [
            LyricsLine(time: 5.0, text: "First"),
            LyricsLine(time: 10.0, text: "Second"),
        ]
        let result = LyricsEngine.findCurrentIndex(position: 999.0, lines: lines)
        XCTAssertEqual(result, 1)
    }

    func testCurrentLineEmptyLines() {
        let result = LyricsEngine.findCurrentIndex(position: 5.0, lines: [])
        XCTAssertNil(result)
    }

    func testBuildDisplay() {
        let lines = [
            LyricsLine(time: 5.0, text: "First"),
            LyricsLine(time: 10.0, text: "Second"),
            LyricsLine(time: 15.0, text: "Third"),
        ]
        let display = LyricsEngine.buildDisplay(index: 1, lines: lines, position: 12.0)

        XCTAssertEqual(display?.previous, "First")
        XCTAssertEqual(display?.current, "Second")
        XCTAssertEqual(display?.next, "Third")
    }

    func testBuildDisplayFirstLine() {
        let lines = [
            LyricsLine(time: 5.0, text: "First"),
            LyricsLine(time: 10.0, text: "Second"),
        ]
        let display = LyricsEngine.buildDisplay(index: 0, lines: lines, position: 6.0)

        XCTAssertNil(display?.previous)
        XCTAssertEqual(display?.current, "First")
        XCTAssertEqual(display?.next, "Second")
    }

    func testBuildDisplayLastLine() {
        let lines = [
            LyricsLine(time: 5.0, text: "First"),
            LyricsLine(time: 10.0, text: "Last"),
        ]
        let display = LyricsEngine.buildDisplay(index: 1, lines: lines, position: 11.0)

        XCTAssertEqual(display?.previous, "First")
        XCTAssertEqual(display?.current, "Last")
        XCTAssertNil(display?.next)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter LyricsEngineTests`
Expected: FAIL — `LyricsEngine` not found

- [ ] **Step 3: Implement LyricsEngine**

```swift
import Combine
import Foundation

final class LyricsEngine: ObservableObject {

    @Published private(set) var display: LyricsDisplay?
    @Published private(set) var state: EngineState = .idle

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
            position: playback.position,
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
            position: playback.position
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

    static func buildDisplay(index: Int, lines: [LyricsLine], position: TimeInterval) -> LyricsDisplay? {
        guard index >= 0, index < lines.count else { return nil }

        let previous = index > 0 ? lines[index - 1].text : nil
        let current = lines[index].text
        let next = index < lines.count - 1 ? lines[index + 1].text : nil

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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter LyricsEngineTests`
Expected: All 8 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Lyricist/Engine/LyricsEngine.swift LyricistTests/LyricsEngineTests.swift
git commit -m "feat: add LyricsEngine with binary search line sync"
```

---

### Task 7: SettingsStore

**Files:**
- Create: `Lyricist/Settings/SettingsStore.swift`

- [ ] **Step 1: Create SettingsStore**

```swift
import Combine
import Foundation

final class SettingsStore: ObservableObject {

    @Published var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }

    @Published var panelX: Double {
        didSet { UserDefaults.standard.set(panelX, forKey: "panelX") }
    }

    @Published var panelY: Double {
        didSet { UserDefaults.standard.set(panelY, forKey: "panelY") }
    }

    @Published var isFloatingVisible: Bool {
        didSet { UserDefaults.standard.set(isFloatingVisible, forKey: "isFloatingVisible") }
    }

    init() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: "fontSize") == nil {
            defaults.set(22.0, forKey: "fontSize")
        }
        if defaults.object(forKey: "isFloatingVisible") == nil {
            defaults.set(true, forKey: "isFloatingVisible")
        }

        self.fontSize = defaults.double(forKey: "fontSize")
        self.panelX = defaults.double(forKey: "panelX")
        self.panelY = defaults.double(forKey: "panelY")
        self.isFloatingVisible = defaults.bool(forKey: "isFloatingVisible")
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Lyricist/Settings/SettingsStore.swift
git commit -m "feat: add SettingsStore with UserDefaults persistence"
```

---

### Task 8: Floating Panel (NSPanel + SwiftUI)

**Files:**
- Create: `Lyricist/UI/FloatingPanel.swift`
- Create: `Lyricist/UI/FloatingLyricsView.swift`

- [ ] **Step 1: Create FloatingPanel**

```swift
import AppKit

final class FloatingPanel: NSPanel {

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = true
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
```

- [ ] **Step 2: Create FloatingLyricsView**

```swift
import SwiftUI

struct FloatingLyricsView: View {
    @ObservedObject var engine: LyricsEngine
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Group {
            switch engine.state {
            case .playing:
                if let display = engine.display {
                    lyricsContent(display)
                }
            case .loading:
                styledText("Loading lyrics...")
            case .noLyrics:
                styledText("No lyrics available")
            case .idle, .error:
                EmptyView()
            }
        }
        .frame(maxWidth: 800)
        .padding(.horizontal, 32)
        .padding(.vertical, 8)
    }

    private func lyricsContent(_ display: LyricsDisplay) -> some View {
        Text(display.current)
            .font(.system(size: settings.fontSize, weight: .bold))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.9), radius: 4, x: 0, y: 2)
            .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 0)
            .shadow(color: .black.opacity(0.7), radius: 12, x: 0, y: 0)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .animation(.easeInOut(duration: 0.3), value: display.current)
    }

    private func styledText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white.opacity(0.6))
            .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
    }
}
```

- [ ] **Step 3: Verify build**

Run: `swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Lyricist/UI/FloatingPanel.swift Lyricist/UI/FloatingLyricsView.swift
git commit -m "feat: add floating panel with lyrics overlay view"
```

---

### Task 9: Menu Bar Controller + Popover

**Files:**
- Create: `Lyricist/UI/MenuBarController.swift`
- Create: `Lyricist/UI/PopoverView.swift`

- [ ] **Step 1: Create PopoverView**

```swift
import SwiftUI

struct PopoverView: View {
    @ObservedObject var engine: LyricsEngine
    @ObservedObject var settings: SettingsStore
    let onTogglePanel: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            trackInfo

            Divider()

            Toggle("Show Lyrics Overlay", isOn: $settings.isFloatingVisible)
                .onChange(of: settings.isFloatingVisible) { _ in
                    onTogglePanel()
                }

            Divider()

            Button("Quit Lyricist") {
                onQuit()
            }
        }
        .padding(16)
        .frame(width: 260)
    }

    @ViewBuilder
    private var trackInfo: some View {
        if case .playing = engine.state,
           let display = engine.display {
            VStack(alignment: .leading, spacing: 4) {
                Text(display.current)
                    .font(.headline)
                    .lineLimit(2)
                Text("♫ Now Playing")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } else {
            Text("Not playing")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}
```

- [ ] **Step 2: Create MenuBarController**

```swift
import AppKit
import SwiftUI

final class MenuBarController {

    private var statusItem: NSStatusItem
    private var popover: NSPopover

    init(engine: LyricsEngine, settings: SettingsStore, onTogglePanel: @escaping () -> Void) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "music.note",
                accessibilityDescription: "Lyricist"
            )
            button.action = #selector(togglePopover)
            button.target = self
        }

        let popoverView = PopoverView(
            engine: engine,
            settings: settings,
            onTogglePanel: onTogglePanel,
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )

        popover.contentViewController = NSHostingController(rootView: popoverView)
        popover.behavior = .transient
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
```

- [ ] **Step 3: Verify build**

Run: `swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Lyricist/UI/MenuBarController.swift Lyricist/UI/PopoverView.swift
git commit -m "feat: add menu bar controller with popover"
```

---

### Task 10: Wire Everything Together in AppDelegate

**Files:**
- Modify: `Lyricist/App/AppDelegate.swift`

- [ ] **Step 1: Update AppDelegate to wire all components**

Replace the entire contents of `AppDelegate.swift`:

```swift
import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var floatingPanel: FloatingPanel!
    private var menuBarController: MenuBarController!
    private var spotifyBridge: SpotifyBridge!
    private var lyricsEngine: LyricsEngine!
    private var settingsStore: SettingsStore!
    private var cancellables = Set<AnyCancellable>()
    private var optionKeyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        settingsStore = SettingsStore()
        spotifyBridge = SpotifyBridge()
        lyricsEngine = LyricsEngine(
            bridge: spotifyBridge,
            provider: LRCLIBProvider()
        )

        setupFloatingPanel()
        setupMenuBar()
        setupOptionKeyMonitor()
    }

    private func setupFloatingPanel() {
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let panelWidth: CGFloat = 800
        let panelHeight: CGFloat = 80

        let x: CGFloat
        let y: CGFloat

        if settingsStore.panelX != 0 || settingsStore.panelY != 0 {
            x = settingsStore.panelX
            y = settingsStore.panelY
        } else {
            x = screenFrame.midX - panelWidth / 2
            y = screenFrame.minY + 60
        }

        let rect = NSRect(x: x, y: y, width: panelWidth, height: panelHeight)
        floatingPanel = FloatingPanel(contentRect: rect)

        let hostingView = NSHostingView(
            rootView: FloatingLyricsView(engine: lyricsEngine, settings: settingsStore)
        )
        hostingView.frame = floatingPanel.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        floatingPanel.contentView?.addSubview(hostingView)

        if settingsStore.isFloatingVisible {
            floatingPanel.orderFront(nil)
        }

        // Save position when panel moves
        NotificationCenter.default.publisher(for: NSWindow.didMoveNotification, object: floatingPanel)
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, let panel = self.floatingPanel else { return }
                self.settingsStore.panelX = panel.frame.origin.x
                self.settingsStore.panelY = panel.frame.origin.y
            }
            .store(in: &cancellables)
    }

    private func setupMenuBar() {
        menuBarController = MenuBarController(
            engine: lyricsEngine,
            settings: settingsStore,
            onTogglePanel: { [weak self] in
                guard let self else { return }
                if self.settingsStore.isFloatingVisible {
                    self.floatingPanel.orderFront(nil)
                } else {
                    self.floatingPanel.orderOut(nil)
                }
            }
        )
    }

    private func setupOptionKeyMonitor() {
        optionKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let optionPressed = event.modifierFlags.contains(.option)
            self?.floatingPanel.ignoresMouseEvents = !optionPressed
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = optionKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run the app manually**

Run: `swift run`
Expected: App launches as menu bar app with ♫ icon. If Spotify is playing, lyrics overlay should appear.

- [ ] **Step 4: Commit**

```bash
git add Lyricist/App/AppDelegate.swift
git commit -m "feat: wire all components together in AppDelegate"
```

---

### Task 11: Final Integration Test

- [ ] **Step 1: Run full test suite**

Run: `swift test`
Expected: All tests pass (LRCParser: 6 tests, LyricsEngine: 8 tests)

- [ ] **Step 2: Manual smoke test**

1. Open Spotify and play a popular song (e.g., "Something Just Like This" by Coldplay)
2. Run `swift run` — app should show ♫ in menu bar
3. Verify floating lyrics appear at bottom of screen
4. Verify lyrics update as the song plays
5. Hold Option key — verify panel becomes draggable
6. Click ♫ icon — verify popover shows with toggle and quit
7. Toggle "Show Lyrics Overlay" off — verify panel hides
8. Quit via popover — verify clean exit

- [ ] **Step 3: Commit final state**

```bash
git add -A
git commit -m "feat: complete Lyricist MVP — floating desktop lyrics for Spotify"
```
