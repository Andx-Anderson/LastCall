import Cocoa
import ServiceManagement

/// Observable so the settings window and the menu bar both react to either one.
final class Prefs: ObservableObject {
    static let shared = Prefs()

    private let d = UserDefaults.standard

    @Published var enabled: Bool {
        didSet {
            d.set(enabled, forKey: "enabled")
            Engine.shared.refresh()
        }
    }

    /// Finder is enforced in the engine, not stored here.
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
        // `enabled` defaults to true for a first run, where the key is absent.
        if d.object(forKey: "enabled") == nil { d.set(true, forKey: "enabled") }
        enabled = d.bool(forKey: "enabled")
        // Seeded on first run only, so removing Finder sticks.
        if d.object(forKey: "excluded") == nil { d.set(["com.apple.finder"], forKey: "excluded") }
        excluded = d.stringArray(forKey: "excluded") ?? []
        lastQuit = d.string(forKey: "lastQuit") ?? ""
        quitDelay = d.object(forKey: "quitDelay") as? Double ?? 0
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

    /// Falls back to the raw id for an app that is no longer installed.
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
