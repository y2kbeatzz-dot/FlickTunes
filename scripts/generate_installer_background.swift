// RIFT's custom DMG background, drawn at build time using AppKit.
// macOS .dmg has a Finder-based drag-to-Applications installation, not a PKG wizard.
import AppKit
import CoreGraphics
import Foundation

let destination = CommandLine.arguments.dropFirst().first ?? ".build/rift-installer-background.png"
let width = 720
let height = 440
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: width * 2, pixelsHigh: height * 2,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: false,
    isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
), let ctx = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Unable to create installer artwork")
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx
let c = ctx.cgContext
c.scaleBy(x: 2, y: 2)
let rect = CGRect(x: 0, y: 0, width: width, height: height)
let gradientSpace = CGColorSpaceCreateDeviceRGB()
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a).cgColor
}
func drawText(_ string: String, x: CGFloat, y: CGFloat, fontSize: CGFloat,
              weight: NSFont.Weight = .regular, tint: NSColor = .white,
              width: CGFloat = 640, align: NSTextAlignment = .left) {
    let style = NSMutableParagraphStyle()
    style.alignment = align
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
        .foregroundColor: tint,
        .paragraphStyle: style
    ]
    NSAttributedString(string: string, attributes: attrs).draw(in:
        CGRect(x: x, y: y, width: width, height: fontSize * 1.65))
}

// Soft dark cosmic base.
c.setFillColor(color(0.043, 0.029, 0.082)); c.fill(rect)
if let grad = CGGradient(colorsSpace: gradientSpace, colors: [
    color(0.18, 0.075, 0.29), color(0.075, 0.039, 0.14),
    color(0.036, 0.03, 0.075)
] as CFArray, locations: [0, 0.50, 1]) {
    c.drawLinearGradient(grad, start: CGPoint(x: 0, y: 440),
                             end: CGPoint(x: 720, y: 0), options: [])
}
// Accent bands in the outer corners.
for index in 0..<10 {
    c.setStrokeColor(color(0.80, 0.27, 0.81, 0.04 + CGFloat(index) * 0.008))
    c.setLineWidth(15)
    c.strokeEllipse(in: CGRect(x: -300 + index * 14, y: 220 + index * 11,
                                width: 540, height: 340))
}
for index in 0..<10 {
    c.setStrokeColor(color(0.25, 0.87, 0.97, 0.025 + CGFloat(index) * 0.005))
    c.setLineWidth(12)
    c.strokeEllipse(in: CGRect(x: 550 - index * 6, y: -220 + index * 11,
                                width: 420, height: 360))
}

// Branded title, sized so the Finder icon labels don't overlap.
drawText("RIFT", x: 50, y: 365, fontSize: 42, weight: .heavy)
drawText("Send it. See it arrive.", x: 52, y: 337, fontSize: 17,
         weight: .semibold, tint: NSColor(srgbRed: 0.93, green: 0.75, blue: 1, alpha: 1))
drawText("DRAG TO INSTALL", x: 214, y: 307, fontSize: 12, weight: .bold,
         tint: NSColor(srgbRed: 0.79, green: 0.73, blue: 0.89, alpha: 1),
         width: 300, align: .center)

// Underlay dots, a luminous portal and an arrow connecting the actual icons.
c.saveGState()
let center = CGPoint(x: 360, y: 185)
for i in 0..<10 {
    let opacity = CGFloat(0.04 + (10-i) * 0.008)
    c.setStrokeColor(color(0.89, 0.34, 0.88, opacity))
    c.setLineWidth(CGFloat(14-i) * 0.9)
    c.strokeEllipse(in: CGRect(x: center.x - CGFloat(22+i*5),
                                y: center.y - CGFloat(83+i*6),
                                width: CGFloat(44+i*10),
                                height: CGFloat(166+i*12)))
}
c.setStrokeColor(color(0.99, 0.48, 0.92, 0.85))
c.setLineWidth(5)
c.strokeEllipse(in: CGRect(x: center.x - 33, y: center.y - 93, width: 66, height: 186))
c.setStrokeColor(color(0.39, 0.94, 1.0, 0.84))
c.setLineWidth(2)
c.strokeEllipse(in: CGRect(x: center.x - 24, y: center.y - 86, width: 48, height: 172))
c.restoreGState()

// Install path: two Finder icons are positioned on either side of the portal.
// Arrows sit behind icons, not on top of their labels.
for x in stride(from: CGFloat(270), through: 310, by: 14) {
    c.setFillColor(color(0.63, 0.91, 1, 0.75))
    c.fillEllipse(in: CGRect(x: x, y: 177, width: 5, height: 5))
}
for x in stride(from: CGFloat(411), through: 460, by: 14) {
    c.setFillColor(color(0.63, 0.91, 1, 0.75))
    c.fillEllipse(in: CGRect(x: x, y: 177, width: 5, height: 5))
}
c.setStrokeColor(color(0.48, 0.96, 1, 0.88)); c.setLineWidth(4)
c.setLineCap(.round)
c.move(to: CGPoint(x: 461, y: 179)); c.addLine(to: CGPoint(x: 453, y: 188)); c.strokePath()
c.move(to: CGPoint(x: 461, y: 179)); c.addLine(to: CGPoint(x: 452, y: 170)); c.strokePath()

drawText("RIFT.app", x: 70, y: 72, fontSize: 14, weight: .bold, width: 170,
         align: .center)
drawText("Applications", x: 467, y: 72, fontSize: 14, weight: .bold,
         width: 170, align: .center)
drawText("Drag RIFT into Applications. Then launch it from Applications.",
         x: 68, y: 40, fontSize: 13,
         tint: NSColor(srgbRed: 0.74, green: 0.69, blue: 0.83, alpha: 1),
         width: 585, align: .center)
drawText("© RIFT · Created by Ksyusha", x: 438, y: 407, fontSize: 10,
         tint: NSColor(srgbRed: 0.68, green: 0.61, blue: 0.77, alpha: 1),
         width: 245, align: .right)
c.flush()
NSGraphicsContext.restoreGraphicsState()
try FileManager.default.createDirectory(
    at: URL(fileURLWithPath: destination).deletingLastPathComponent(),
    withIntermediateDirectories: true
)
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Failed to encode installer artwork")
}
try png.write(to: URL(fileURLWithPath: destination), options: .atomic)
print("RIFT custom installer artwork: \(destination)")
