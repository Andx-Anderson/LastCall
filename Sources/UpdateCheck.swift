import Foundation

/// Asks GitHub whether there is a newer release. It does not download or install
/// anything — it only surfaces a menu item linking to the release page.
final class UpdateCheck {
    static let shared = UpdateCheck()

    static let releasesPage = URL(string: "https://github.com/Andx-Anderson/LastCall/releases/latest")!
    private static let api = URL(string: "https://api.github.com/repos/Andx-Anderson/LastCall/releases/latest")!
    private static let interval: TimeInterval = 60 * 60 * 24

    /// Set when a newer release exists, otherwise nil. Read from the main thread.
    private(set) var availableVersion: String?

    private var timer: Timer?

    func start() {
        check()
        timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in
            self?.check()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        availableVersion = nil
    }

    func check() {
        guard Prefs.shared.checkForUpdates else { availableVersion = nil; return }
        var request = URLRequest(url: Self.api)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else { return }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
            DispatchQueue.main.async {
                self.availableVersion = Version.isNewer(latest, than: current) ? latest : nil
            }
        }.resume()
    }
}
