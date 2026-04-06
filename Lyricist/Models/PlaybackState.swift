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
