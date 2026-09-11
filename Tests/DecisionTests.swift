// Tests for the quit decision. Run with ./test.sh
//
// No XCTest, so this stays a plain binary you can run anywhere with swiftc.

import Foundation

struct Case {
    let name: String
    let before: Int
    let after: Int
    let onScreen: Int
    let expect: Bool
}

let cases: [Case] = [
    // The ordinary path
    Case(name: "single window app, window destroyed",
         before: 1, after: 0, onScreen: 0, expect: true),
    Case(name: "two windows, one destroyed",
         before: 2, after: 1, onScreen: 1, expect: false),
    Case(name: "three windows, one destroyed",
         before: 3, after: 2, onScreen: 2, expect: false),

    // Discord: the window is hidden, not destroyed, so the count does not drop
    Case(name: "Discord, window hidden not destroyed",
         before: 1, after: 1, onScreen: 0, expect: true),
    Case(name: "Discord-style hide with a second window still visible",
         before: 2, after: 2, onScreen: 1, expect: false),

    // A window on another Space is still in the AX list but not on screen, so it
    // must keep the app alive.
    Case(name: "last visible window destroyed, one left on another Space",
         before: 2, after: 1, onScreen: 0, expect: false),
    Case(name: "two windows left on other Spaces",
         before: 3, after: 2, onScreen: 0, expect: false),

    // A minimized window is still listed, so it lands in the same branch.
    Case(name: "visible window destroyed, a minimized one remains",
         before: 2, after: 1, onScreen: 0, expect: false),

    // The trigger did not actually close anything
    Case(name: "Cmd+W closed a browser tab, window untouched",
         before: 1, after: 1, onScreen: 1, expect: false),
    Case(name: "close still animating, window not gone yet",
         before: 1, after: 1, onScreen: 1, expect: false),

    // Regression: every window below the size floor gets filtered, so the counts
    // arrive as zeroes. Before the guard this quit an app that still had windows.
    Case(name: "all windows below the size floor",
         before: 0, after: 0, onScreen: 0, expect: false),
    Case(name: "no windows at trigger time",
         before: 0, after: 1, onScreen: 1, expect: false),

    // A new window appearing must never be read as a close
    Case(name: "a window opened instead of closing",
         before: 1, after: 2, onScreen: 2, expect: false),
]

@main
struct TestRunner {
    static func main() {
        var failed = 0
        for c in cases {
            let got = Decision.shouldQuit(before: c.before, after: c.after, onScreen: c.onScreen)
            let ok = got == c.expect
            if !ok { failed += 1 }
            print("[\(ok ? "pass" : "FAIL")] \(c.name)  (before=\(c.before) after=\(c.after) onScreen=\(c.onScreen)) -> \(got)")
        }
        // Version comparison, used to decide whether an update exists
        let versionCases: [(String, String, Bool)] = [
            ("1.4.0", "1.3.1", true),
            ("1.3.1", "1.3.1", false),
            ("1.3.0", "1.3.1", false),
            ("1.10.0", "1.9.0", true),    // not a string comparison
            ("2.0", "1.9.9", true),
            ("1.3", "1.3.0", false),
            ("1.3.2", "1.3", true),
        ]
        for (cand, cur, want) in versionCases {
            let got = Version.isNewer(cand, than: cur)
            if got != want { failed += 1 }
            print("[\(got == want ? "pass" : "FAIL")] version \(cand) newer than \(cur) -> \(got)")
        }

        print("")
        let total = cases.count + versionCases.count
        print(failed == 0 ? "\(total) passed" : "\(failed) of \(total) FAILED")
        exit(failed == 0 ? 0 : 1)
    }
}
