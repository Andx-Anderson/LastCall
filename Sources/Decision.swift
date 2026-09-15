// The quit decision, kept pure so it can be tested without a running app.
// All three inputs are counts of "real" windows — see minWindowSide in Engine.swift.

enum Decision {

    static func shouldQuit(before: Int, after: Int, onScreen: Int) -> Bool {
        // Nothing to reason from. Happens when every window an app owns is below the
        // size floor, so all of them get filtered out — without this guard the
        // hidden-window branch below reads 0 <= 1 as "finished" and quits an app
        // whose windows are all just small.
        if before == 0 { return false }

        // Something of this app's is on screen right now, so it is plainly not
        // finished. This only ever VETOES a quit, which is why it is not the failed
        // design in DESIGN.md: that one used off-screen-ness to JUSTIFY quitting, and
        // so killed apps whose other window sat on another Space. Such a window still
        // reads as not on screen here, so it never vetoes, and the counts below go on
        // handling it. The reverse direction cannot be a false alarm — the window
        // server only reports a window it is actually compositing.
        //
        // This is what closing one of two Chrome profile windows needed: the branch
        // below saw a bad count and never looked at the window still sitting there.
        if onScreen > 0 { return false }

        // A window was destroyed. Whatever is still listed is a real window wherever
        // it lives, which is what keeps an app alive when its other window is on a
        // different Space.
        if after < before { return after == 0 }

        // Nothing was destroyed and the app shows nothing at all: it hid the window
        // instead of destroying it (Discord). One of the listed windows IS the hidden
        // one, so the app is finished at a count of one.
        return after <= 1
    }
}
