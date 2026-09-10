// Turns the opaque black corners of the source icon transparent.
//
// The source PNG has no alpha channel, so the area outside the rounded-square
// artwork is painted solid black. Rather than guess a corner radius, flood fill
// inward from each of the four corners over near-black pixels: that follows the
// artwork's real silhouette, and cannot touch the dark cursor in the middle
// because it is not connected to any edge.

import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count >= 3 else { fputs("usage: mask <in.png> <out.png>\n", stderr); exit(1) }

guard let src = NSImage(contentsOfFile: args[1]),
      let tiff = src.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff) else { fputs("cannot read image\n", stderr); exit(1) }

let w = rep.pixelsWide, h = rep.pixelsHigh
print("source: \(w)x\(h)")

// Redraw into a known RGBA8 buffer; the source may be any layout.
guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                          space: CGColorSpaceCreateDeviceRGB(),
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }
guard let cg = rep.cgImage else { exit(1) }
ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
guard let buf = ctx.data else { exit(1) }
let px = buf.bindMemory(to: UInt8.self, capacity: w * h * 4)

@inline(__always) func idx(_ x: Int, _ y: Int) -> Int { (y * w + x) * 4 }

/// "Black enough to be background." The artwork's darkest real content is the
/// cursor outline, which is well above this and unreachable from the edges anyway.
@inline(__always) func isBackground(_ i: Int) -> Bool {
    Int(px[i]) + Int(px[i + 1]) + Int(px[i + 2]) < 90
}

var visited = [Bool](repeating: false, count: w * h)
var stack: [(Int, Int)] = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
var cleared = 0

while let (x, y) = stack.popLast() {
    guard x >= 0, y >= 0, x < w, y < h else { continue }
    let flat = y * w + x
    if visited[flat] { continue }
    let i = idx(x, y)
    guard isBackground(i) else { continue }
    visited[flat] = true
    px[i] = 0; px[i + 1] = 0; px[i + 2] = 0; px[i + 3] = 0   // fully transparent
    cleared += 1
    stack.append((x + 1, y)); stack.append((x - 1, y))
    stack.append((x, y + 1)); stack.append((x, y - 1))
}
print("cleared \(cleared) corner pixels (\(String(format: "%.2f", Double(cleared) / Double(w * h) * 100))%)")

// Feather the cut edge. A hard flood fill leaves stair-stepped corners; averaging
// alpha with the neighbours once softens them without blurring the artwork.
var alpha = [UInt8](repeating: 0, count: w * h)
for y in 0..<h { for x in 0..<w { alpha[y * w + x] = px[idx(x, y) + 3] } }
for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
        let i = idx(x, y)
        // only soften pixels adjacent to the transparent region
        var touchesHole = false
        for dy in -1...1 { for dx in -1...1 where alpha[(y + dy) * w + (x + dx)] == 0 { touchesHole = true } }
        guard touchesHole, alpha[y * w + x] == 255 else { continue }
        var sum = 0
        for dy in -1...1 { for dx in -1...1 { sum += Int(alpha[(y + dy) * w + (x + dx)]) } }
        px[i + 3] = UInt8(sum / 9)
    }
}

guard let out = ctx.makeImage() else { exit(1) }
let outRep = NSBitmapImageRep(cgImage: out)
outRep.size = NSSize(width: w, height: h)
guard let data = outRep.representation(using: .png, properties: [:]) else { exit(1) }
try! data.write(to: URL(fileURLWithPath: args[2]))
print("wrote \(args[2])")
