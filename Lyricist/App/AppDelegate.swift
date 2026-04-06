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
