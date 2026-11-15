// Generates matching FlickTunes icons without requiring any binary artwork in Git.
// Usage (on macOS): swift scripts/generate_icons.swift
import AppKit
import CoreGraphics
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let ios = root.appendingPathComponent("Assets/iOS/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
let mac = root.appendingPathComponent("Assets/macOS/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: ios, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: mac, withIntermediateDirectories: true)

func makeIcon(_ pixels: Int, to file: URL) throws {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                       pixelsWide: pixels, pixelsHigh: pixels,
                                       bitsPerSample: 8, samplesPerPixel: 4,
                                       hasAlpha: true, isPlanar: false,
                                       colorSpaceName: .deviceRGB,
                                       bytesPerRow: 0, bitsPerPixel: 0),
          let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "FlickTunes", code: 1, userInfo: [NSLocalizedDescriptionKey: "Couldn't render app icon"])
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    let cg = graphics.cgContext
    let ratio = CGFloat(pixels) / 1024.0
    cg.scaleBy(x: ratio, y: ratio)
    let bounds = CGRect(x: 0, y: 0, width: 1024, height: 1024)
    // Full opaque background (required for modern iOS icons).
    cg.setFillColor(NSColor(red: 0.10, green: 0.04, blue: 0.22, alpha: 1).cgColor)
    cg.fill(bounds)
    let space = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: space, colors: [
        NSColor(red: 0.44, green: 0.17, blue: 0.82, alpha: 1).cgColor,
        NSColor(red: 0.94, green: 0.20, blue: 0.53, alpha: 1).cgColor,
        NSColor(red: 0.14, green: 0.06, blue: 0.35, alpha: 1).cgColor
    ] as CFArray, locations: [0, 0.55, 1])!
    cg.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 1100), end: CGPoint(x: 980, y: 0), options: [])

    // Phone outline, tilted to emphasize the gesture.
    cg.saveGState()
    cg.translateBy(x: 300, y: 510)
    cg.rotate(by: 0.16)
    cg.setStrokeColor(NSColor.white.withAlphaComponent(0.94).cgColor)
    cg.setLineWidth(26)
    cg.addPath(CGPath(roundedRect: CGRect(x: -118, y: -205, width: 236, height: 410), cornerWidth: 44, cornerHeight: 44, transform: nil))
    cg.strokePath()
    cg.setStrokeColor(NSColor.white.withAlphaComponent(0.40).cgColor)
    cg.setLineWidth(10)
    cg.move(to: CGPoint(x: -29, y: -170)); cg.addLine(to: CGPoint(x: 29, y: -170)); cg.strokePath()
    cg.restoreGState()

    // Laptop outline.
    cg.setStrokeColor(NSColor.white.withAlphaComponent(0.94).cgColor)
    cg.setLineWidth(25)
    cg.addPath(CGPath(roundedRect: CGRect(x: 555, y: 340, width: 255, height: 210), cornerWidth: 18, cornerHeight: 18, transform: nil))
    cg.strokePath()
    cg.setLineCap(.round)
    cg.move(to: CGPoint(x: 515, y: 318)); cg.addLine(to: CGPoint(x: 856, y: 318)); cg.strokePath()

    // Three curved 'flick' waves.
    for (index, alpha) in [(0, CGFloat(0.30)), (1, CGFloat(0.60)), (2, CGFloat(0.95))] {
        let shift = CGFloat(index) * 32
        cg.setStrokeColor(NSColor.white.withAlphaComponent(alpha).cgColor)
        cg.setLineWidth(19)
        cg.addArc(center: CGPoint(x: 412, y: 545), radius: 80 + shift, startAngle: -.pi/8, endAngle: .pi/2.5, clockwise: false)
        cg.strokePath()
    }

    // Note tiles matching the purple-pink visual system.
    func noteTile(x: CGFloat, y: CGFloat, width: CGFloat) {
        let rect = CGRect(x: x, y: y, width: width, height: width)
        cg.setFillColor(NSColor(red: 1.0, green: 0.27, blue: 0.53, alpha: 1).cgColor)
        cg.addPath(CGPath(roundedRect: rect, cornerWidth: width * 0.22, cornerHeight: width * 0.22, transform: nil)); cg.fillPath()
        cg.setStrokeColor(NSColor.white.cgColor)
        cg.setFillColor(NSColor.white.cgColor)
        cg.setLineWidth(width * 0.065)
        let shaftX = x + width * 0.63
        cg.move(to: CGPoint(x: shaftX, y: y + width * 0.25))
        cg.addLine(to: CGPoint(x: shaftX, y: y + width * 0.72)); cg.strokePath()
        let head = CGRect(x: x + width * 0.29, y: y + width * 0.18, width: width * 0.36, height: width * 0.22)
        cg.fillEllipse(in: head)
    }
    noteTile(x: 262, y: 480, width: 90)
    noteTile(x: 635, y: 398, width: 85)
    cg.flush()
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "FlickTunes", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to encode PNG"])
    }
    try data.write(to: file, options: .atomic)
}

try makeIcon(1024, to: ios.appendingPathComponent("AppIcon-1024.png"))
let macSizes: [(Int, String)] = [
    (16, "appicon_16x16.png"), (32, "appicon_16x16@2x.png"),
    (32, "appicon_32x32.png"), (64, "appicon_32x32@2x.png"),
    (128, "appicon_128x128.png"), (256, "appicon_128x128@2x.png"),
    (256, "appicon_256x256.png"), (512, "appicon_256x256@2x.png"),
    (512, "appicon_512x512.png"), (1024, "appicon_512x512@2x.png")
]
for (size, filename) in macSizes {
    try makeIcon(size, to: mac.appendingPathComponent(filename))
}
print("Generated FlickTunes iOS + macOS icons")
