<div align="center">

<img src="Icon/icon.png" width="180" alt="Last Call">

# Last Call

**Close the last window, the app quits. Like Windows.**

<p>
<img src="https://img.shields.io/badge/macOS-14%2B-000000?style=for-the-badge&logo=apple&logoColor=white" alt="macOS 14+">
<img src="https://img.shields.io/badge/Swift-6.3-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 6.3">
<img src="https://img.shields.io/badge/Works%20on-Discord-5865F2?style=for-the-badge&logo=discord&logoColor=white" alt="Works on Discord">
</p>

<p>
<a href="https://github.com/Andx-Anderson/LastCall/releases/latest"><img src="https://img.shields.io/github/v/release/Andx-Anderson/LastCall?color=3FB950&label=release" alt="Latest release"></a>
<a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-1F6FEB" alt="MIT license"></a>
<img src="https://img.shields.io/badge/menu%20bar-only-8957E5" alt="Menu bar only">
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

```sh
git clone https://github.com/Andx-Anderson/LastCall.git
cd LastCall
./build.sh
```

That compiles it, installs it to `/Applications`, and launches it.

> [!IMPORTANT]
> Last Call needs **Accessibility** permission, and it will prompt you on first launch. It cannot see
> which window you clicked without it, so nothing works until you tick the box.
>
> System Settings → Privacy & Security → Accessibility → **Last Call**

> [!NOTE]
> There's no download button here on purpose. The build is ad-hoc signed, so macOS would flag it as
> coming from an unidentified developer — and an unsigned app asking for Accessibility, the
> permission to read and control every other app, is shaped exactly like malware. Building it
> yourself takes one command and you can read precisely what you're granting.

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

---

## Privacy

The event tap is **listen-only** and cannot alter or block input. The key handler reads only the
keycode and modifier flags, to test for Cmd+W. Nothing is stored, logged, or sent anywhere.

---

## Build

| File | |
| :--- | :--- |
| `Sources/Engine.swift` | Detection and the quit decision |
| `Sources/Prefs.swift` | Settings and the login item |
| `Sources/SettingsView.swift` | Settings window |
| `Sources/AppDelegate.swift` | Menu bar |
| `Icon/mask.swift` | Regenerates the icon from the source art |

`./build.sh` compiles, bundles, signs and installs to `/Applications`.

> [!WARNING]
> Ad-hoc signing ties the Accessibility grant to the code hash, so **every rebuild silently voids
> it** — macOS keeps showing the toggle as enabled while denying the app. `build.sh` resets the grant
> on each build so you get an honest prompt instead of an app that looks authorised and does nothing.

---

## Notes

Why Discord needs different handling, and two designs that failed before this one:
**[DESIGN.md](DESIGN.md)**.

## License

MIT
