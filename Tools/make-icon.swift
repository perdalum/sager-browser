// Draws the Sager app icon as a PNG at any pixel size:
//
//   swift Tools/make-icon.swift 1024 Resources/icon-1024.png
//
// The artwork is laid out in an 824x824 design box (the size macOS uses for a
// 1024pt icon: ~10% padding on each side for the drop shadow), with y running
// downwards, and scaled to whatever pixel size is requested. Everything is
// vector, so each iconset size is rendered directly instead of being resampled.
import AppKit
import Foundation

// MARK: - Arguments

let arguments = CommandLine.arguments
guard arguments.count == 3, let pixelSize = Double(arguments[1]) else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <pixels> <out.png>\n".utf8))
    exit(2)
}

let outputPath = arguments[2]
let canvas = pixelSize
let design = 824.0
let artInset = (canvas - canvas * (design / 1024.0)) / 2
let scale = (canvas - artInset * 2) / design

/// Design coordinates (824 box, y down) -> AppKit coordinates (y up).
func point(_ x: Double, _ y: Double) -> NSPoint {
    NSPoint(x: artInset + x * scale, y: artInset + (design - y) * scale)
}

func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> NSRect {
    NSRect(
        x: artInset + x * scale,
        y: artInset + (design - y - height) * scale,
        width: width * scale,
        height: height * scale
    )
}

func box(_ x: Double, _ y: Double, _ width: Double, _ height: Double, radius: Double) -> NSBezierPath {
    NSBezierPath(
        roundedRect: rect(x, y, width, height),
        xRadius: radius * scale,
        yRadius: radius * scale
    )
}

// MARK: - Bitmap

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(pixelSize),
    pixelsHigh: Int(pixelSize),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    FileHandle.standardError.write(Data("could not create bitmap\n".utf8))
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.shouldAntialias = true
NSGraphicsContext.current?.imageInterpolation = .high

// MARK: - Background (rounded square + shadow)

let square = box(0, 0, design, design, radius: 185)

let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
shadow.shadowBlurRadius = 26 * scale
shadow.shadowOffset = NSSize(width: 0, height: -12 * scale)
shadow.set()

NSGradient(
    starting: NSColor(srgbRed: 0.373, green: 0.549, blue: 0.961, alpha: 1),  // #5F8CF5
    ending: NSColor(srgbRed: 0.208, green: 0.235, blue: 0.639, alpha: 1)     // #353CA3
)?.draw(in: square, angle: -90)

// Reset the shadow so the foreground stays crisp.
NSShadow().set()

// Glassy highlight along the top edge.
NSGraphicsContext.saveGraphicsState()
square.addClip()
NSGradient(
    starting: NSColor.white.withAlphaComponent(0.26),
    ending: NSColor.white.withAlphaComponent(0.0)
)?.draw(in: rect(0, 0, design, design * 0.55), angle: -90)
NSGraphicsContext.restoreGraphicsState()

// Everything below lives inside the rounded square.
NSGraphicsContext.saveGraphicsState()
square.addClip()

// MARK: - Page peeking out of the folder (the journal)

let page = box(300, 168, 236, 300, radius: 22)
NSColor(srgbRed: 0.925, green: 0.945, blue: 1.0, alpha: 1).setFill()
page.fill()

// Below ~32px the rules are sub-pixel noise, so they are left out there.
if pixelSize > 32 {
    let rule = NSColor(srgbRed: 0.663, green: 0.722, blue: 0.878, alpha: 1)
    rule.setFill()
    for (index, width) in [156.0, 138.0].enumerated() {
        box(340, 214 + Double(index) * 54, width, 20, radius: 10).fill()
    }
}

// MARK: - Folder

let folderTab = box(118, 246, 246, 96, radius: 30)
NSColor(srgbRed: 0.925, green: 0.941, blue: 0.988, alpha: 1).setFill()
folderTab.fill()

let folderBody = box(118, 300, 424, 342, radius: 40)
NSGradient(
    starting: NSColor.white,
    ending: NSColor(srgbRed: 0.878, green: 0.906, blue: 0.980, alpha: 1)
)?.draw(in: folderBody, angle: -90)

// MARK: - Magnifier

let lensCentre = point(618, 542)
let lensRadius = 142.0 * scale
// Heavier ring and handle in the small sizes, where 46pt of white would
// otherwise average away against the blue.
let isSmall = pixelSize <= 32
let ringWidth = (isSmall ? 62.0 : 46.0) * scale

let lens = NSBezierPath(
    ovalIn: NSRect(
        x: lensCentre.x - lensRadius,
        y: lensCentre.y - lensRadius,
        width: lensRadius * 2,
        height: lensRadius * 2
    )
)

NSColor.white.withAlphaComponent(0.30).setFill()
lens.fill()

NSColor.white.setStroke()
lens.lineWidth = ringWidth
lens.stroke()

let handleStart = point(618 + 142 * 0.707, 542 + 142 * 0.707)
let handleEnd = point(618 + 208 * 0.707, 542 + 208 * 0.707)
let handle = NSBezierPath()
handle.move(to: handleStart)
handle.line(to: handleEnd)
handle.lineWidth = (isSmall ? 76.0 : 54.0) * scale
handle.lineCapStyle = .round
NSColor.white.setStroke()
handle.stroke()

NSGraphicsContext.restoreGraphicsState()   // clip
NSGraphicsContext.restoreGraphicsState()   // bitmap context

// MARK: - Write

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("could not encode png\n".utf8))
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: outputPath))
} catch {
    FileHandle.standardError.write(Data("write failed: \(error.localizedDescription)\n".utf8))
    exit(1)
}
