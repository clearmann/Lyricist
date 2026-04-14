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

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Lyrics Offset")
                        .font(.subheadline)
                    Spacer()
                    Text(offsetLabel)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $settings.lyricsOffset, in: -2.0...2.0, step: 0.05)
            }

            Divider()

            Button("Quit Lyricist") {
                onQuit()
            }
        }
        .padding(16)
        .frame(width: 260)
    }

    private var offsetLabel: String {
        let ms = Int(settings.lyricsOffset * 1000)
        return ms >= 0 ? "+\(ms)ms" : "\(ms)ms"
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
