# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Build (debug)
swift build -c debug

# Build (release)
swift build -c release

# Run all tests
swift test

# Run a single test class
swift test --filter LRCParserTests

# Run a single test method
swift test --filter LRCParserTests/testParsesBasicLRC
```

## Architecture

Lyricist is a macOS menu bar app (no Dock icon, `LSUIElement = true`) that displays synchronized Spotify lyrics in a floating desktop overlay. It uses SwiftUI + AppKit (no sandbox — AppleScript requires it), targets macOS 13+, and has zero external dependencies.

### Data flow

```
SpotifyBridge (500ms poll via AppleScript)
    → trackChanged / playbackState (Combine)
    → LyricsEngine
        → LyricsProvider (async fetch + LyricsCache)
        → LyricsDisplay (current/previous/next line via binary search)
            → FloatingLyricsView (NSPanel overlay)
            → MenuBarController (NSStatusItem popover)
```

### Key modules

- **`SpotifyBridge`** — Polls Spotify every 500ms via AppleScript. Publishes `playbackState` (`CurrentValueSubject`) and fires `trackChanged` (`PassthroughSubject`) when the track ID changes. Monitors `NSWorkspace` notifications to start/stop polling when Spotify launches/quits.

- **`LyricsEngine`** — `ObservableObject` that owns `SpotifyBridge`. On track change, fetches lyrics through the provider chain (LRCLIB → NetEase fallback). Uses binary search on sorted `LyricsLine` timestamps to compute current line. Publishes `display: LyricsDisplay?` and `state: EngineState`.

- **`LyricsProviding` protocol** — `fetchLyrics(trackName:artist:) async throws -> Lyrics`. Implemented by `LRCLIBProvider` (primary) and a NetEase provider (fallback). `LRCLIBProvider` first tries an exact GET, then falls back to the search API.

- **`LRCParser`** — Static parser for LRC format (`[mm:ss.xx] text`). Ignores metadata tags (`[ti:]`, `[ar:]`, etc.) and empty lines. Returns lines sorted by timestamp.

- **`LyricsCache`** — In-memory cache keyed by `"artist-trackName"`. No disk persistence.

- **`FloatingPanel`** / **`FloatingLyricsView`** — `NSPanel` subclass at `.floating` window level, transparent background, non-activating. Embeds SwiftUI via `NSHostingView`. Position is draggable (Option key) and persisted via `SettingsStore`.

- **`MenuBarController`** — Owns `NSStatusItem` with a music note icon. Shows a `PopoverView` (SwiftUI) with toggle/quit controls.

- **`SettingsStore`** — `ObservableObject` backed by `UserDefaults`/`@AppStorage`. Stores floating panel position, font size, visibility, and timing offset.

### Lyrics model

```swift
struct LyricsLine { let time: TimeInterval; let text: String }
struct Lyrics      { let lines: [LyricsLine]; let source: String }
struct LyricsDisplay { let previous: String?; let current: String; let next: String?; let progress: Double }
```

### Release

GitHub Actions CI runs `swift build` + `swift test` on push/PR. Releases are triggered by `v*` tags: CI builds a release binary, wraps it in a `.app` bundle with an inline `Info.plist`, ad-hoc code-signs it, and publishes `.dmg` + `.zip` artifacts to GitHub Releases.
