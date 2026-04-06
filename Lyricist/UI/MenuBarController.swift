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
