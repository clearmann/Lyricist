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
