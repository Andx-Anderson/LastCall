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

<div align="center">

<a href="https://github.com/Andx-Anderson/LastCall/releases/latest/download/LastCall.dmg"><img src="Icon/download-macos.png" width="200" alt="Download app for macOS"></a>

</div>

Open the `.dmg`, drag **Last Call** to your `/Applications` folder, and open it. Signed and notarised
by Apple, so there's no security warning and nothing to bypass.

> [!IMPORTANT]
> Last Call needs **Accessibility** permission and will ask on first launch. It cannot see which
> window you clicked without it, so nothing quits until you turn it on.
>
> System Settings → Privacy & Security → Accessibility → **Last Call**

---

## Using it

A menu bar icon and one settings window. Apps quit when you close their last window with the **red
button** or **Cmd+W**.

| Setting | What it does |
| :--- | :--- |
| **Quit apps when the last window closes** | The main switch. |
| **Open at login** | On by default, so it still works after a reboot. Revocable in System Settings → General → Login Items. |
| **Quit delay** | A grace period before quitting, up to 5s. Reopen a window during it and the app is left alone. Instant by default. |
| **Never quit these apps** | Apps to leave alone. Finder is here by default — remove it if you want Finder to quit too. |

The menu bar icon dims when it's paused or missing permission, and the settings window tells you
which.

> [!TIP]
> Last Call leaves an app alone if it still has a window on **another Space** or a **minimized**
> window. When the answer is ambiguous it does nothing — the only thing it can do is quit something,
> so it errs toward leaving you alone.

**Tested on** Discord, Spotify, ChatGPT and Safari. Closing a browser *tab* correctly does nothing.

---

## Privacy

Last Call watches for mouse clicks and Cmd+W so it knows when you closed a window. That is the only
reason it needs Accessibility.

- It **cannot** alter or block your input — the event tap is listen-only.
- It reads only the key and modifier flags, to check for Cmd+W. It does not see what you type.
- Nothing is stored, logged, or sent anywhere. There is no network code in the app.

The whole thing is about 600 lines of Swift in [Sources](Sources) if you'd like to check.

---

## Building it yourself

```sh
git clone https://github.com/Andx-Anderson/LastCall.git
cd LastCall
./build.sh
```

Compiles, signs and installs to `/Applications`. `./test.sh` runs the tests.

How it decides what to quit, why Discord needs special handling, and two designs that failed before
this one: **[DESIGN.md](DESIGN.md)**.

---

## License

MIT
