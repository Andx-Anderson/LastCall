// The quit decision, kept pure so it can be tested without a running app.
//
// Inputs are all counts of "real" windows (see minWindowSide in Engine.swift):
//   before    the app's window count when the user triggered a close
//   after     its window count once things settled
//   onScreen  how many of its windows the window server is currently showing

enum Decision {

    static func shouldQuit(before: Int, after: Int, onScreen: Int) -> Bool {
        // Nothing to reason from. Happens when every window an app owns is below the
        // size floor, so all of them get filtered out — without this guard the
        // hidden-window branch below reads 0 <= 1 as "finished" and quits an app
        // whose windows are all just small.
        if before == 0 { return false }

        // A window was destroyed. Whatever is still listed is a real window wherever
        // it lives, which is what keeps an app alive when its other window is on a
        // different Space.
        if after < before { return after == 0 }

        // Nothing was destroyed, and the app shows nothing at all: it hid the window
        // instead of destroying it (Discord). One of the listed windows IS the hidden
        // one, so the app is finished at a count of one.
        if onScreen == 0 { return after <= 1 }

        // Nothing was destroyed and something is still visible — the close did not
        // land (a Cmd+W that closed a tab, say). Leave it alone.
        return false
    }
}
