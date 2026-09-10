import SwiftUI
import ApplicationServices
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var prefs = Prefs.shared
    @State private var trusted = AXIsProcessTrusted()
    @State private var selection: String?

    /// So the row flips to Granted without reopening this window.
    private let trustTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !trusted { permissionBanner }
                    behaviourSection
                    exclusionSection
                }
                .padding(18)
            }
        }
        .frame(width: 440, height: 470)
        .onReceive(trustTimer) { _ in
            let now = AXIsProcessTrusted()
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
                Text("Last Call").font(.system(size: 15, weight: .semibold))
                Text(statusLine).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var statusLine: String {
        if !trusted { return "Needs Accessibility permission" }
        if !prefs.enabled { return "Paused" }
        if !prefs.lastQuit.isEmpty { return prefs.lastQuit }
        return "Watching for window closes"
    }

    // MARK: Permission

    private var permissionBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text("Accessibility permission required").font(.system(size: 12, weight: .medium))
                Text("Last Call needs it to see which window you clicked. It cannot do anything until this is on.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button("Open Accessibility Settings") {
                    NSWorkspace.shared.open(URL(string:
                        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
                .controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.10)))
    }

    // MARK: Behaviour

    private var behaviourSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Quit apps when the last window closes", isOn: $prefs.enabled)
                .disabled(!trusted)
            Toggle("Open at login", isOn: Binding(
                get: { prefs.openAtLogin },
                set: { prefs.openAtLogin = $0 }
            ))
            Text("Clicking the red button closes the window and quits the app, the way Windows does.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Exclusions

    private var exclusionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Never quit these apps").font(.system(size: 12, weight: .medium))

            List(selection: $selection) {
                HStack(spacing: 8) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app"))
                        .resizable().frame(width: 16, height: 16)
                    Text("Finder")
                    Spacer()
                    Text("always").font(.system(size: 10)).foregroundStyle(.tertiary)
                }
                .selectionDisabled()

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
