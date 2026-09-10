// Draws the "Download app for macOS" button used in the README.
// Rendered at 2x so it stays crisp on a retina display.

import AppKit

let scale: CGFloat = 2
let w: CGFloat = 300 * scale
let h: CGFloat = 92 * scale

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w), pixelsHigh: Int(h),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: Int(w) * 4, bitsPerPixel: 32)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Rounded black pill with a faint light edge, as on Apple's own badges.
let inset: CGFloat = 3 * scale
let rect = CGRect(x: inset, y: inset, width: w - inset * 2, height: h - inset * 2)
let radius = rect.height * 0.28
let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
NSColor(calibratedWhite: 0.05, alpha: 1).setFill()
path.fill()
NSColor(calibratedWhite: 0.72, alpha: 1).setStroke()
path.lineWidth = 1.6 * scale
path.stroke()

// Apple logo, left of the text
if let logo = NSImage(systemSymbolName: "apple.logo", accessibilityDescription: nil) {
    let cfg = NSImage.SymbolConfiguration(pointSize: 44 * scale, weight: .regular)
    if let sized = logo.withSymbolConfiguration(cfg) {
        let tinted = NSImage(size: sized.size, flipped: false) { r in
            sized.draw(in: r)
            NSColor.white.set()
            r.fill(using: .sourceAtop)
            return true
        }
        let lw = tinted.size.width, lh = tinted.size.height
        tinted.draw(in: CGRect(x: rect.minX + 26 * scale,
                               y: rect.midY - lh / 2,
                               width: lw, height: lh))
    }
}

func draw(_ s: String, size: CGFloat, weight: NSFont.Weight, x: CGFloat, y: CGFloat) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size * scale, weight: weight),
        .foregroundColor: NSColor.white,
    ]
    NSAttributedString(string: s, attributes: attrs).draw(at: CGPoint(x: x, y: y))
}

let textX = rect.minX + 92 * scale
draw("Download app for", size: 15, weight: .medium, x: textX, y: rect.midY + 4 * scale)
draw("macOS", size: 27, weight: .bold, x: textX, y: rect.midY - 30 * scale)

NSGraphicsContext.restoreGraphicsState()

let out = URL(fileURLWithPath: "Icon/download-macos.png")
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("wrote \(out.path)  \(Int(w))x\(Int(h))")
