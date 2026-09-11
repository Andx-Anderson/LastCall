import SwiftUI
import ApplicationServices
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var prefs = Prefs.shared
    @State private var trusted = Engine.shared.hasPermission
    @State private var selection: String?

    /// So the permission row updates the moment it changes in System Settings,
    /// in either direction, without reopening this window.
    private let trustTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    permissionRow
                    behaviourSection
                    exclusionSection
                }
                .padding(18)
            }
        }
        .frame(width: 440, height: 490)
        .onReceive(trustTimer) { _ in
            let now = Engine.shared.hasPermission
            if now != trusted { trusted = now }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon).resizable().frame(width: 44, height: 44)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Last Call").font(.system(size: 15, weight: .semibold))
                    Text(prefs.version).font(.system(size: 11)).foregroundStyle(.tertiary)
                }
                Text(statusLine).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var statusLine: String {
        if !trusted { return "Not working — needs permission" }
        if !prefs.enabled { return "Paused" }
        if !prefs.lastQuit.isEmpty { return prefs.lastQuit }
        return "Watching for window closes"
    }

    // MARK: Permission
    //
    // Shown in both states: a row that appears only on failure gives you no way to
    // tell "granted" from "the app forgot to check".

    private var permissionRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: trusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(trusted ? Color.green : Color.orange)
                Text("Accessibility access")
                Spacer()
                Text(trusted ? "Granted" : "Not granted")
                    .font(.system(size: 11))
                    .foregroundStyle(trusted ? .secondary : Color.orange)
            }

            if !trusted {
                Text("Last Call cannot see which window you clicked, so nothing will quit until this is on.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Accessibility Settings") {
                    NSWorkspace.shared.open(URL(string:
                        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
                .controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(trusted ? Color.secondary.opacity(0.08) : Color.orange.opacity(0.12)))
    }

    // MARK: Behaviour

    private var behaviourSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Quit apps when the last window closes", isOn: $prefs.enabled)
            Toggle("Open at login", isOn: Binding(
                get: { prefs.openAtLogin },
                set: { prefs.openAtLogin = $0 }
            ))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Quit delay")
                    Spacer()
                    Text(delayLabel).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Slider(value: $prefs.quitDelay, in: 0...5, step: 0.5)
                Text("Reopen a window during the delay and the app is left alone.")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            .disabled(!prefs.enabled)

            Divider().padding(.vertical, 2)

            Toggle("Check for updates", isOn: $prefs.checkForUpdates)
            Text("Asks GitHub once a day whether a newer version exists. Nothing about you is sent.")
                .font(.system(size: 11)).foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var delayLabel: String {
        prefs.quitDelay == 0 ? "Instant" : String(format: "%.1fs", prefs.quitDelay)
    }

    // MARK: Exclusions

    private var exclusionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Never quit these apps").font(.system(size: 12, weight: .medium))

            List(selection: $selection) {
                ForEach(prefs.excluded, id: \.self) { id in
                    HStack(spacing: 8) {
                        if let icon = prefs.icon(for: id) {
                            Image(nsImage: icon).resizable().frame(width: 16, height: 16)
                        }
                        Text(prefs.displayName(for: id))
                        Spacer()
                    }
                    .tag(id)
                }
            }
            .frame(height: 150)
            .border(Color.secondary.opacity(0.2))

            HStack(spacing: 6) {
                Button { addApp() } label: { Image(systemName: "plus") }
                Button { removeSelected() } label: { Image(systemName: "minus") }
                    .disabled(selection == nil)
                Spacer()
                if prefs.excluded.isEmpty {
                    Text("Nothing excluded").font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { continue }
            if !prefs.excluded.contains(id) { prefs.excluded.append(id) }
        }
    }

    private func removeSelected() {
        guard let sel = selection else { return }
        prefs.excluded.removeAll { $0 == sel }
        selection = nil
    }
}
