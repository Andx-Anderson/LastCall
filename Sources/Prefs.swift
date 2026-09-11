import Cocoa
import ServiceManagement

final class Prefs: ObservableObject {
    static let shared = Prefs()

    private let d = UserDefaults.standard

    @Published var enabled: Bool {
        didSet {
            d.set(enabled, forKey: "enabled")
            Engine.shared.refresh()
        }
    }

    @Published var excluded: [String] {
        didSet { d.set(excluded, forKey: "excluded") }
    }

    /// Seconds to wait before quitting, so an accidental close can be undone by
    /// reopening a window. 0 = instant.
    @Published var quitDelay: Double {
        didSet { d.set(quitDelay, forKey: "quitDelay") }
    }

    @Published var lastQuit: String {
        didSet { d.set(lastQuit, forKey: "lastQuit") }
    }

    init() {
        if d.object(forKey: "enabled") == nil { d.set(true, forKey: "enabled") }
        enabled = d.bool(forKey: "enabled")
        // Seeded on first run only, so removing Finder sticks.
        if d.object(forKey: "excluded") == nil { d.set(["com.apple.finder"], forKey: "excluded") }
        excluded = d.stringArray(forKey: "excluded") ?? []
        lastQuit = d.string(forKey: "lastQuit") ?? ""
        quitDelay = d.object(forKey: "quitDelay") as? Double ?? 0

        // On by default, seeded once: a menu bar app that silently fails to come back
        // after a reboot looks broken. Turning it off afterwards sticks.
        if d.object(forKey: "seededLoginItem") == nil {
            d.set(true, forKey: "seededLoginItem")
            try? SMAppService.mainApp.register()
        }
    }

    var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return v ?? "—"
    }

    func noteQuit(appName: String) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        lastQuit = "Last quit \(appName) at \(f.string(from: Date()))"
    }

    // MARK: Login item

    /// SMAppService, so macOS lists it under Login Items and the user can revoke it.
    var openAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
                } else {
                    if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
                }
            } catch {
                NSLog("Last Call: login item change failed: \(error.localizedDescription)")
            }
            objectWillChange.send()
        }
    }

    // MARK: Display helpers

    func displayName(for bundleId: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return bundleId
        }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    func icon(for bundleId: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
