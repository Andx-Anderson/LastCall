// Last Call — click the red dot, the app quits. Like Windows.
//
// Menu bar utility (LSUIElement, no Dock icon). The interesting part is Engine.swift.

import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
