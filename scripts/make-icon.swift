// Usage: swift make-icon.swift <output.iconset-dir>
// Draws a simple rounded-square icon with a text-cursor "rename" motif at every size macOS needs.
import AppKit

let outDir = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let size = CGFloat(px)
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: size * 0.06, y: size * 0.06, width: size * 0.88, height: size * 0.88)
    let bg = NSBezierPath(roundedRect: rect, xRadius: size * 0.2, yRadius: size * 0.2)
    NSGradient(colors: [NSColor(red: 0.36, green: 0.42, blue: 0.98, alpha: 1),
                        NSColor(red: 0.55, green: 0.28, blue: 0.95, alpha: 1)])!
        .draw(in: bg, angle: -60)

    // A "file name" pill with an insertion caret.
    let pill = NSRect(x: size * 0.2, y: size * 0.4, width: size * 0.6, height: size * 0.2)
    NSColor.white.withAlphaComponent(0.95).setFill()
    NSBezierPath(roundedRect: pill, xRadius: size * 0.05, yRadius: size * 0.05).fill()

    NSColor(red: 0.36, green: 0.42, blue: 0.98, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: size * 0.58, y: size * 0.34, width: size * 0.035, height: size * 0.32),
                 xRadius: size * 0.015, yRadius: size * 0.015).fill()
    for i in 0..<3 {
        let w = size * [0.22, 0.1, 0.06][i]
        let x = size * 0.26 + [0, size * 0.25, size * 0.38][i]
        NSBezierPath(roundedRect: NSRect(x: x, y: size * 0.47, width: w, height: size * 0.06),
                     xRadius: size * 0.02, yRadius: size * 0.02).fill()
    }

    image.unlockFocus()
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: URL(fileURLWithPath: "\(outDir)/icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: URL(fileURLWithPath: "\(outDir)/icon_\(base)x\(base)@2x.png"))
}
