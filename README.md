# Lyricist

[中文](README.zh.md) | English

**桌面悬浮歌词 · Desktop floating lyrics for Spotify**

Lyricist is a lightweight macOS menu bar app that reads your Spotify playback and displays synchronized lyrics as a transparent floating overlay — always on top, never in the way.

---

## Features

- **Always-on-top overlay** — lyrics float above every window, on every Space, even in full-screen apps
- **Line-synced lyrics** — current line highlighted and animated, transitions smoothly every beat
- **Dual lyrics sources** — fetches from [LRCLIB](https://lrclib.net) first, falls back to NetEase Cloud Music for broader coverage
- **Traditional → Simplified Chinese** — automatic character conversion for Chinese lyrics
- **Timing offset** — fine-tune the sync if lyrics feel early or late
- **Menu bar only** — no Dock icon, no clutter; lives quietly in the status bar
- **Draggable & persistent** — hold Option to drag the overlay anywhere; position is remembered across launches
- **Zero external dependencies** — built entirely on system frameworks

## Requirements

- macOS 13 Ventura or later
- Spotify desktop app
- Apple Silicon (arm64)

> Lyricist uses AppleScript to read Spotify's playback state. macOS will prompt for Automation permission on first launch.

## Installation

Download the latest release from the [Releases](../../releases) page.

1. Open the `.dmg` and drag **Lyricist.app** to `/Applications`
2. Launch the app — a music note icon `♩` appears in your menu bar
3. Play something in Spotify and lyrics will appear on your desktop

> Because Lyricist is distributed outside the App Store and ad-hoc signed, macOS may show a Gatekeeper warning on first open. Right-click the app → **Open** to proceed.

## Usage

| Action | How |
|--------|-----|
| Show / hide lyrics overlay | Click `♩` in the menu bar → toggle switch |
| Move the overlay | Hold **Option** and drag |
| Adjust sync timing | Click `♩` → timing offset slider |
| Quit | Click `♩` → Quit |

## Build from Source

Requires Xcode 16 or Swift 5.9+.

```bash
git clone https://github.com/clearmann/Lyricist.git
cd Lyricist

# Debug build
swift build -c debug

# Run tests
swift test

# Release build
swift build -c release
```

The compiled binary is at `.build/release/Lyricist`. To run it as a proper `.app` with AppleScript permissions, wrap it in an app bundle (see the release workflow for the exact steps).

## How It Works

```
Spotify  ──AppleScript──►  SpotifyBridge  ──trackChanged──►  LyricsEngine
  (500ms poll)                                                     │
                                                         LRCLIB / NetEase API
                                                                     │
                                              LyricsDisplay (prev / current / next)
                                                     │
                                          FloatingPanel (NSPanel .floating level)
                                          MenuBar popover
```

`SpotifyBridge` polls Spotify every 500ms via AppleScript. On a track change, `LyricsEngine` fetches and caches the lyrics, then uses binary search on the sorted timestamp list to find the current line in real time. The transparent `NSPanel` overlay never steals focus and joins all Spaces.

## License

MIT
