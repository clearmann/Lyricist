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
