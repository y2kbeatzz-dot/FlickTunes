// Generates matching RIFT icons without requiring any binary artwork in Git.
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
        throw NSError(domain: "RIFT", code: 1, userInfo: [NSLocalizedDescriptionKey: "Couldn't render app icon"])
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

    // RIFT: a luminous dimensional portal with an arriving tile.
    let glow = NSColor(red: 0.98, green: 0.28, blue: 0.74, alpha: 0.19).cgColor
    cg.setFillColor(glow)
    cg.fillEllipse(in: CGRect(x: 585, y: 162, width: 340, height: 700))

    cg.saveGState()
    cg.translateBy(x: 742, y: 512)
    for (index, radius) in [CGFloat(17), 8, 3].enumerated() {
        cg.setStrokeColor(
            (index == 0
                ? NSColor(red: 0.28, green: 0.91, blue: 1.0, alpha: 0.7)
                : NSColor(red: 1.0, green: 0.44, blue: 0.90, alpha: 0.92)).cgColor
        )
        cg.setLineWidth(radius)
        cg.strokeEllipse(in: CGRect(x: -100, y: -272, width: 200, height: 544))
    }
    cg.setFillColor(NSColor(red: 0.07, green: 0.03, blue: 0.16, alpha: 1).cgColor)
    cg.fillEllipse(in: CGRect(x: -76, y: -246, width: 152, height: 492))
    cg.restoreGState()

    // The content card passes through the portal from right to left.
    cg.saveGState()
    cg.translateBy(x: 385, y: 512)
    cg.rotate(by: -0.11)
    let card = CGRect(x: -191, y: -155, width: 382, height: 310)
    cg.setFillColor(NSColor(red: 0.20, green: 0.11, blue: 0.40, alpha: 1).cgColor)
    cg.addPath(CGPath(roundedRect: card, cornerWidth: 58, cornerHeight: 58, transform: nil))
    cg.fillPath()
    cg.setStrokeColor(NSColor.white.withAlphaComponent(0.95).cgColor)
    cg.setLineWidth(23)
    cg.addPath(CGPath(roundedRect: card.insetBy(dx: 7, dy: 7), cornerWidth: 50, cornerHeight: 50, transform: nil))
    cg.strokePath()
    let picture = CGRect(x: -135, y: -87, width: 138, height: 154)
    cg.setFillColor(NSColor(red: 0.96, green: 0.26, blue: 0.61, alpha: 1).cgColor)
    cg.addPath(CGPath(roundedRect: picture, cornerWidth: 25, cornerHeight: 25, transform: nil))
    cg.fillPath()
    cg.setFillColor(NSColor.white.withAlphaComponent(0.92).cgColor)
    cg.fillEllipse(in: CGRect(x: -95, y: 7, width: 47, height: 47))
    cg.move(to: CGPoint(x: -116, y: -65))
    cg.addLine(to: CGPoint(x: -57, y: 0))
    cg.addLine(to: CGPoint(x: -15, y: -65))
    cg.closePath()
    cg.fillPath()
    cg.restoreGState()

    // Motion streaks connect the moving card to the dimensional slit.
    for i in 0..<3 {
        let y = CGFloat(422 + i * 87)
        cg.setStrokeColor(NSColor.white.withAlphaComponent(0.65 - CGFloat(i) * 0.12).cgColor)
        cg.setLineWidth(CGFloat(14 - i * 2))
        cg.setLineCap(.round)
        cg.move(to: CGPoint(x: 548, y: y))
        cg.addLine(to: CGPoint(x: 636, y: y))
        cg.strokePath()
    }
    cg.flush()
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "RIFT", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to encode PNG"])
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
print("Generated RIFT iOS + macOS icons")
