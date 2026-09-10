# Last Call

Close an app's last window and the app quits, the way Windows does. No more apps idling in the Dock
with nothing open.

Works on **Discord** and other Electron apps, which similar tools don't — they hide their windows
instead of closing them, so anything watching for a window to be destroyed never fires.

macOS 14+.

## Install

```sh
./build.sh
```

Then grant Accessibility when prompted. It can't see which window you clicked without it.

## Use

A menu bar icon and one settings window. Quitting happens when you close the last window with the
**red button** or **Cmd+W**.

Settings:

| | |
| :--- | :--- |
| **Quit apps when the last window closes** | The main switch. |
| **Open at login** | A real Login Item, revocable in System Settings → General → Login Items. |
| **Never quit these apps** | Add any app with `+`. Finder is always excluded. |

The menu bar icon dims when paused or when permission is missing.

Things it deliberately won't do: quit an app with another window open on a different Space, quit an
app whose only remaining window is minimized, or quit Finder.

## Privacy

The event tap is **listen-only** and cannot alter or block input. The key handler reads only the
keycode and modifier flags, to test for Cmd+W. Nothing is stored, logged, or sent anywhere.

## Build

| | |
| :--- | :--- |
| `Sources/Engine.swift` | Detection and the quit decision |
| `Sources/Prefs.swift` | Settings and the login item |
| `Sources/SettingsView.swift` | Settings window |
| `Sources/AppDelegate.swift` | Menu bar |
| `Icon/mask.swift` | Regenerates the icon from the source art |

`./build.sh` compiles, bundles, signs and installs to `/Applications`.

The bundle is ad-hoc signed, so its Accessibility grant is tied to the code hash and **every rebuild
voids it** — macOS keeps showing the toggle as enabled while denying the app. `build.sh` resets the
grant each build so you get a fresh prompt instead.

## Notes

Why Discord needs different handling, and two designs that failed before this one:
[DESIGN.md](DESIGN.md).

## License

MIT
