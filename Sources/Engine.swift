// Detection and the quit decision. See DESIGN.md for why it is shaped this way —
// briefly: Discord hides its window instead of destroying it, and a window on
// another Space reads as off-screen, so neither destruction events nor
// on-screen-ness can be trusted. Counts can.

import Cocoa
import ApplicationServices

/// Bundle ids never quit, whatever the user configures.
let hardExcluded: Set<String> = ["com.apple.finder"]

final class Engine {
    static let shared = Engine()

    private var tap: CFMachPort?
    private(set) var isRunning = false

    /// A window does not vanish on mouse-down; Spotify's close animation outlasts
    /// 300ms. Act on the first settled check rather than waiting a fixed delay.
    private let checkDelays: [TimeInterval] = [0.25, 0.25, 0.30, 0.40]

    /// Chrome owns a dozen tiny helper surfaces that are not real windows.
    private let minWindowSide: CGFloat = 100

    /// AX calls block until the target app answers. These run in the event-tap
    /// callback on every click, so an uncapped query lets one hung app stall input.
    private let axTimeout: Float = 0.2

    private lazy var systemWide: AXUIElement = {
        let el = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(el, axTimeout)
        return el
    }()

    private func appElement(_ pid: pid_t) -> AXUIElement {
        let el = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(el, axTimeout)
        return el
    }

    // MARK: Lifecycle

    func start() {
        guard !isRunning, AXIsProcessTrusted() else { return }
        // leftMouseDown for the red button, keyDown for Cmd+W.
        let mask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.keyDown.rawValue)
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                        place: .headInsertEventTap,
                                        options: .listenOnly,
                                        eventsOfInterest: CGEventMask(mask),
                                        callback: { _, type, event, _ in
                                            Engine.shared.handle(type: type, event: event)
                                            return Unmanaged.passUnretained(event)
                                        },
                                        userInfo: nil) else { return }
        tap = t
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        isRunning = true
    }

    func stop() {
        guard let t = tap else { isRunning = false; return }
        CGEvent.tapEnable(tap: t, enable: false)
        CFMachPortInvalidate(t)
        tap = nil
        isRunning = false
    }

    func refresh() {
        if Prefs.shared.enabled && AXIsProcessTrusted() { start() } else { stop() }
    }

    // MARK: Triggers
    //
    // A trigger is only a hint. The decision comes from window state afterwards, so a
    // false trigger is free — a Cmd+W that closed a tab leaves the window in place.

    private func handle(type: CGEventType, event: CGEvent) {
        // macOS disables a tap that ever runs long. Re-arm rather than going deaf.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
            return
        }
        guard Prefs.shared.enabled else { return }

        switch type {
        case .leftMouseDown:
            guard let pid = closeButtonPid(at: event.location) else { return }
            schedule(pid: pid)

        case .keyDown:
            // Only the key identity and modifier flags are read; nothing is recorded.
            guard event.flags.contains(.maskCommand),
                  event.getIntegerValueField(.keyboardEventKeycode) == 13 else { return }  // 13 = W
            guard let app = NSWorkspace.shared.frontmostApplication else { return }
            schedule(pid: app.processIdentifier)

        default:
            return
        }
    }

    /// Snapshot the window count at trigger time; the decision compares against it.
    private func schedule(pid: pid_t) {
        let before = realWindowCount(pid: pid)
        DispatchQueue.main.asyncAfter(deadline: .now() + checkDelays[0]) { [weak self] in
            self?.consider(pid: pid, before: before, attempt: 0)
        }
    }

    /// Was that click on a window's red close button? If so, whose?
    private func closeButtonPid(at point: CGPoint) -> pid_t? {
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide,
                                               Float(point.x), Float(point.y), &element) == .success,
              let el = element else { return nil }
        var sub: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXSubroleAttribute as CFString, &sub) == .success,
              let subrole = sub as? String, subrole == kAXCloseButtonSubrole as String else { return nil }
        var pid: pid_t = 0
        guard AXUIElementGetPid(el, &pid) == .success else { return nil }
        return pid
    }

    // MARK: Decide

    /// `after < before`           a window was destroyed  -> quit iff nothing remains
    /// `after == before`, nothing on screen  hidden, not destroyed -> one of the listed
    ///                            windows is the hidden one, so finished at 1
    /// `after == before`, something on screen  the close did nothing -> leave it alone
    ///
    /// Counts, never `CFEqual` identity: AXUIElement refs to one window are not
    /// reliably equal across fetches (Discord's are not). See DESIGN.md.
    private func consider(pid: pid_t, before: Int, attempt: Int) {
        guard let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated else { return }
        let bundleId = app.bundleIdentifier ?? ""

        // Only real, Dock-visible apps. Menu bar agents legitimately run windowless.
        guard app.activationPolicy == .regular else { return }
        guard !hardExcluded.contains(bundleId), !Prefs.shared.excluded.contains(bundleId) else { return }
        guard pid != ProcessInfo.processInfo.processIdentifier else { return }

        let after = realWindowCount(pid: pid)
        let onScreen = onScreenWindowCount(pid: pid)

        let finished: Bool
        if after < before {
            finished = after == 0
        } else if onScreen == 0 {
            finished = after <= 1
        } else {
            finished = false
        }

        if finished {
            let name = app.localizedName ?? bundleId
            app.terminate()
            Prefs.shared.noteQuit(appName: name)
            return
        }
        // Not settled — the close may still be animating. Retry a few times, then give
        // up and leave the app alone.
        let next = attempt + 1
        guard next < checkDelays.count else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + checkDelays[next]) { [weak self] in
            self?.consider(pid: pid, before: before, attempt: next)
        }
    }

    // MARK: Window inspection

    /// Windows in the AX list, across every Space.
    private func realWindowCount(pid: pid_t) -> Int {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement(pid),
                                           kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return 0 }
        return windows.filter { isRealWindow($0) }.count
    }

    /// Small permanent utility surfaces would otherwise keep an app alive forever.
    private func isRealWindow(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &value) == .success,
              let raw = value, CFGetTypeID(raw) == AXValueGetTypeID() else { return true }
        var size = CGSize.zero
        guard AXValueGetValue(raw as! AXValue, .cgSize, &size) else { return true }
        return size.width >= minWindowSide && size.height >= minWindowSide
    }

    /// Only used to detect hide-instead-of-destroy. Never to judge other windows —
    /// an off-Space window also reads as not on screen.
    private func onScreenWindowCount(pid: pid_t) -> Int {
        guard let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else {
            return 0
        }
        var count = 0
        for w in list {
            guard let owner = w[kCGWindowOwnerPID as String] as? pid_t, owner == pid,
                  let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
                  let visible = w[kCGWindowIsOnscreen as String] as? Bool, visible,
                  let b = w[kCGWindowBounds as String] as? [String: Any],
                  let width = b["Width"] as? CGFloat, let height = b["Height"] as? CGFloat,
                  width >= minWindowSide, height >= minWindowSide else { continue }
            count += 1
        }
        return count
    }
}
