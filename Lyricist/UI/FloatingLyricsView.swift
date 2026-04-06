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
