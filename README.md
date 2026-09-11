<div align="center">

<img src="Icon/icon.png" width="180" alt="Last Call">

# Last Call

**Close the last window, the app quits. Like Windows.**

<p>
<a href="https://github.com/Andx-Anderson/LastCall/actions/workflows/test.yml"><img src="https://github.com/Andx-Anderson/LastCall/actions/workflows/test.yml/badge.svg" alt="Tests"></a>
<img src="https://img.shields.io/badge/macOS-14%2B-black?logo=apple&logoColor=white" alt="macOS 14+">
<img src="https://img.shields.io/badge/Swift-6.3-F05138?logo=swift&logoColor=white" alt="Swift 6.3">
<a href="https://github.com/Andx-Anderson/LastCall/releases/latest"><img src="https://img.shields.io/github/v/release/Andx-Anderson/LastCall?color=brightgreen" alt="Latest release"></a>
<a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT license"></a>
</p>

</div>

---

Say hello to **Last Call**, the app that makes your Mac's red close button do what you actually
expect. Close an app's last window and the app *quits* — no more half a dozen apps idling in your
Dock with nothing open, no more reaching for Cmd+Q every single time.

And it works on **Discord**, which tools like this quietly fail on. Discord doesn't close its window,
it hides it, so anything waiting for a window to be destroyed waits forever. Last Call counts
windows instead. It also knows the difference between closing a window and *minimizing* one, or
leaving one open on another Space — so it never quits an app you're still using.

---

## Install

### Download

<a href="https://github.com/Andx-Anderson/LastCall/releases/latest/download/LastCall.dmg"><img src="Icon/download-macos.png" width="240" alt="Download app for macOS"></a>

Open the `.dmg`, drag **Last Call** to your `/Applications` folder, and open it. That's it — the app
is signed with a Developer ID and notarised by Apple, so there's no security warning and nothing to
bypass.

### Or build it yourself

```sh
git clone https://github.com/Andx-Anderson/LastCall.git
cd LastCall
./build.sh
```

Compiles it, installs it to `/Applications`, and launches it. No quarantine flag to clear, because
nothing was downloaded.

### Then grant permission

> [!IMPORTANT]
> Last Call needs **Accessibility** permission, and prompts you on first launch. It cannot see which
> window you clicked without it, so nothing works until you tick the box.
>
> System Settings → Privacy & Security → Accessibility → **Last Call**

---

## Use

A menu bar icon and one settings window. Apps quit when you close the last window with the **red
button** or **Cmd+W**.

| Setting | What it does |
| :--- | :--- |
| **Quit apps when the last window closes** | The main switch. |
| **Open at login** | A real Login Item, revocable in System Settings → General → Login Items. |
| **Never quit these apps** | Add any app with `+`. Finder is always excluded. |

The menu bar icon dims when it's paused or when permission is missing.

> [!TIP]
> It deliberately won't quit an app that still has a window on **another Space**, one whose only
> remaining window is **minimized**, or **Finder**. When the answer is ambiguous it leaves the app
> alone — the only thing it can do is quit something, so it errs toward doing nothing.

### Tested

| App | |
| :--- | :--- |
| Discord | quits — hides its window instead of closing it, the case other tools miss |
| Spotify | quits — slow close animation, handled by re-checking |
| ChatGPT | quits |
| Safari | quits on the last window; closing a **tab** correctly does nothing |
| Finder | never quit, by design |

Apps with a window on another Space, or with a minimized window left, are left running.

---

## Privacy

The event tap is **listen-only** and cannot alter or block input. The key handler reads only the
keycode and modifier flags, to test for Cmd+W. Nothing is stored, logged, or sent anywhere.

---

## Build

| File | |
| :--- | :--- |
| `Sources/Engine.swift` | Event tap, triggers, window counting |
| `Sources/Decision.swift` | The quit rule, kept pure so it can be tested |
| `Sources/Prefs.swift` | Settings and the login item |
| `Sources/SettingsView.swift` | Settings window |
| `Sources/AppDelegate.swift` | Menu bar |
| `Icon/mask.swift` | Regenerates the icon from the source art |

`./build.sh` compiles, bundles, signs and installs to `/Applications`.
`./test.sh` runs the decision tests — pure logic, so they need no running app and no permission.

`build.sh` signs with whatever **Developer ID Application** identity is in your keychain, and falls
back to ad-hoc signing if there isn't one.

> [!NOTE]
> Ad-hoc signing ties the Accessibility grant to the code *hash*, so every rebuild silently voids it
> — macOS keeps showing the toggle as enabled while denying the app. A Developer ID identity is
> stable across rebuilds, so the grant survives. If you build ad-hoc, expect to re-tick the box each
> time, and run `tccutil reset Accessibility com.andxlab.lastcall` to get an honest prompt.

To cut a release, `./release.sh <version>` signs, notarises and staples a `.dmg`. It needs App Store
Connect credentials in the environment:

```sh
export ASC_KEY=~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8
export ASC_KEY_ID=XXXXXXXXXX
export ASC_ISSUER=<issuer-uuid>
./release.sh 1.2.0
```

---

## Notes

Why Discord needs different handling, and two designs that failed before this one:
**[DESIGN.md](DESIGN.md)**.

## License

MIT
