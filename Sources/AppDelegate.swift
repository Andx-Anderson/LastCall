import Cocoa
import SwiftUI
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var trustTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildStatusItem()

        // The prompting variant is what registers us in the Accessibility list at
        // all; a plain AXIsProcessTrusted() check adds no entry to tick.
        if !AXIsProcessTrusted() {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(opts)
            showSettings(nil)
        }

        Engine.shared.refresh()
        if Prefs.shared.checkForUpdates { UpdateCheck.shared.start() }

        wasTrusted = Engine.shared.hasPermission

        // Picks the grant up live rather than making the user relaunch, and catches
        // it being taken away again.
        trustTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Engine.shared.refresh()
            self?.checkPermissionLoss()
            self?.updateStatusItem()
        }
    }

    /// Revoking Accessibility does not stop the app or say anything — it just makes it
    /// silently useless. So say so, once, the moment it happens.
    private var wasTrusted = false

    private func checkPermissionLoss() {
        let now = Engine.shared.hasPermission
        defer { wasTrusted = now }
        guard wasTrusted, !now else { return }

        Engine.shared.stop()

        showSettings(nil)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Last Call has stopped working"
        alert.informativeText = """
            Its Accessibility permission was turned off, so it can no longer see which \
            window you clicked. Closing a window will not quit anything until you turn \
            it back on.
            """
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string:
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }

    // MARK: Menu bar

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "macwindow",
                                           accessibilityDescription: "Last Call")
        statusItem.button?.image?.isTemplate = true
        rebuildMenu()
        updateStatusItem()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let toggle = NSMenuItem(title: Prefs.shared.enabled ? "Last Call is on" : "Last Call is paused",
                                action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.target = self
        toggle.state = Prefs.shared.enabled ? .on : .off
        menu.addItem(toggle)

        if !AXIsProcessTrusted() {
            let warn = NSMenuItem(title: "Needs Accessibility permission", action: #selector(showSettings(_:)), keyEquivalent: "")
            warn.target = self
            menu.addItem(warn)
        } else if !Prefs.shared.lastQuit.isEmpty {
            let info = NSMenuItem(title: Prefs.shared.lastQuit, action: nil, keyEquivalent: "")
            info.isEnabled = false
            menu.addItem(info)
        }

        if let newVersion = UpdateCheck.shared.availableVersion {
            menu.addItem(.separator())
            let update = NSMenuItem(title: "Update available — \(newVersion)",
                                    action: #selector(openReleases), keyEquivalent: "")
            update.target = self
            menu.addItem(update)
        }

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings(_:)), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: "Quit Last Call", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    /// Only rebuild on a real change: reassigning `statusItem.menu` on a timer
    /// dismisses the menu out from under an open click.
    private var lastMenuState: String = ""

    private func updateStatusItem() {
        let trusted = Engine.shared.hasPermission
        statusItem.button?.appearsDisabled = !(Prefs.shared.enabled && trusted)
        let state = "\(Prefs.shared.enabled)|\(trusted)|\(Prefs.shared.lastQuit)"
            + "|\(UpdateCheck.shared.availableVersion ?? "")"
        guard state != lastMenuState else { return }
        lastMenuState = state
        rebuildMenu()
    }

    // MARK: Actions

    @objc private func toggleEnabled() {
        Prefs.shared.enabled.toggle()
        updateStatusItem()
    }

    @objc private func showSettings(_ sender: Any?) {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 470),
                styleMask: [.titled, .closable],
                backing: .buffered, defer: false)
            window.title = "Last Call"
            window.contentView = NSHostingView(rootView: SettingsView())
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func openReleases() {
        NSWorkspace.shared.open(UpdateCheck.releasesPage)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
