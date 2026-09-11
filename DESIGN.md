# Design notes

Measured on macOS 26.6.2.

## Why Discord breaks the obvious approach

Existing tools wait for the Accessibility `AXUIElementDestroyed` notification, or poll until an
app's AX window count reaches zero. Discord closes its window by **hiding** it:

| after clicking close | Spotify | Discord |
| :--- | :--- | :--- |
| AX window count | 1 → 0 | 1 → **1** |
| `AXUIElementDestroyed` | fires instantly | **never** |
| `AXMinimized` | — | false |
| `kCGWindowIsOnscreen` | false | false |

Nothing times out of that, because nothing will ever change.

## How it works

1. Listen-only `CGEventTap` on left-mouse-down and key-down.
2. Click → `AXUIElementCopyElementAtPosition`; if the subrole is `AXCloseButton`, take the pid.
   Cmd+W → take the frontmost app.
3. Snapshot the app's window count, re-check shortly after, decide:

| | |
| :--- | :--- |
| `before == 0` | Nothing to reason from. Do nothing. |
| `after < before` | A window was destroyed. Quit iff `after == 0`. |
| `after == before`, nothing on screen | Hidden, not destroyed. Quit iff `after <= 1`. |
| `after == before`, something on screen | Do nothing. |

The `before == 0` guard exists because the 100px floor filters every window of an app whose windows
are all small, making the counts arrive as zeroes — and `0 <= 1` would otherwise read as "finished"
and quit an app that still had windows open. Such an app now simply never auto-quits, which is the
right way to fail. The rule lives in `Sources/Decision.swift` as a pure function; `./test.sh` covers
it, including that regression.

A trigger is only a hint; the decision comes from window state afterwards. So a false trigger is
free — a Cmd+W that closed a browser tab leaves the window in place.

Retries at 0.25/0.5/0.8/1.2s, acting on the first settled result. A window doesn't vanish on
mouse-down; Spotify's close animation outlasts 300ms.

## Two designs that failed

**Judging other windows by `kCGWindowIsOnscreen`.** A window on another Space also reports
not-on-screen, so this quits an app whose other window is on a different desktop — the regression
reported against Swift Quit's [PR #60](https://github.com/onebadidea/swiftquit/pull/60).

**Identifying the closed window by `CFEqual`.** `AXUIElement` references to the same window aren't
reliably equal across fetches. Discord's aren't, so the just-closed window counted as another open
window and nothing ever quit.

Counting needs neither, which is why it survives both.

## Constraints worth keeping

- **Ambiguity means do nothing.** The only action is terminating an app.
- **AX queries capped at 200ms.** They run in the event-tap callback on every click, and AX calls
  block until the target app answers. Uncapped, one hung app stalls input and the system disables
  the tap.
- **Windows under 100px per side ignored.** Chrome owns a dozen tiny helper surfaces.
- **`.regular` apps only.** Menu bar agents legitimately run windowless.

## Testing traps

Things that produced confident wrong answers:

- **Most single-window apps self-terminate on macOS 26** — Calculator, TextEdit, Font Book,
  Dictionary — so they "prove" a broken build works. Third-party survivors usable as controls:
  Spotify, ChatGPT.
- **Chess survives but is a system app**, and such tools exclude those.
- **A maximized window's red X exits fullscreen** instead of closing.
- **A synthetic click lands on whatever covers that point** unless you raise the target window
  first, and `osascript` keystrokes go to whatever is frontmost.

Assert the window count actually changed before reading anything into a result. A test whose setup
silently failed looks identical to a passing one.

## Source layout

| File | |
| :--- | :--- |
| `Sources/Engine.swift` | Event tap, triggers, window counting |
| `Sources/Decision.swift` | The quit rule, pure so it can be unit tested |
| `Sources/Prefs.swift` | Settings and the login item |
| `Sources/SettingsView.swift` | Settings window |
| `Sources/AppDelegate.swift` | Menu bar, permission watching |
| `Icon/mask.swift` | Regenerates the icon from the source art |

## Building and releasing

`./build.sh` compiles, signs and installs to `/Applications`. It signs with whatever **Developer ID
Application** identity is in your keychain and falls back to ad-hoc signing if there isn't one.

> Ad-hoc signing ties the Accessibility grant to the code *hash*, so every rebuild silently voids it
> — macOS keeps showing the toggle as enabled while denying the app. A Developer ID identity is
> stable across rebuilds, so the grant survives. Building ad-hoc, expect to re-tick the box each
> time, and run `tccutil reset Accessibility com.andxlab.lastcall` to get an honest prompt.

`./release.sh <version>` signs, notarises and staples a `.dmg`. It needs App Store Connect
credentials in the environment:

```sh
export ASC_KEY=~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8
export ASC_KEY_ID=XXXXXXXXXX
export ASC_ISSUER=<issuer-uuid>
./release.sh 1.3.0
```

**Sign the disk image before notarising it.** A notarised-but-unsigned `.dmg` staples successfully
and still fails Gatekeeper with `no usable signature` — every tool reports success and the download
still warns. The only honest check is to copy the artefact, apply a real quarantine flag, and run
the assessment a downloader hits:

```sh
xattr -w com.apple.quarantine "0081;$(printf %x $(date +%s));Safari;" copy.dmg
spctl -a -vvv -t open --context context:primary-signature copy.dmg   # want: accepted
```
