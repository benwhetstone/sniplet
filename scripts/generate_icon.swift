import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsetURL = root.appendingPathComponent("packaging/AppIcon.iconset", isDirectory: true)
let outputURL = root.appendingPathComponent("packaging/Sniplet.icns")

let specs: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

try? FileManager.default.removeItem(at: iconsetURL)
try? FileManager.default.removeItem(at: outputURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

for (name, size) in specs {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
    NSColor(calibratedWhite: 0.97, alpha: 1).setFill()
    rect.fill()

    let inset = size * 0.08
    let cardRect = rect.insetBy(dx: inset, dy: inset)
    let cornerRadius = size * 0.22
    let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: cornerRadius, yRadius: cornerRadius)

    let gradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.09, green: 0.58, blue: 0.90, alpha: 1),
            NSColor(calibratedRed: 0.11, green: 0.78, blue: 0.76, alpha: 1)
        ]
    )!
    gradient.draw(in: cardPath, angle: -35)

    NSColor.black.withAlphaComponent(0.10).setStroke()
    cardPath.lineWidth = max(2, size * 0.012)
    cardPath.stroke()

    let frameInset = size * 0.24
    let frameRect = rect.insetBy(dx: frameInset, dy: frameInset)
    let framePath = NSBezierPath(roundedRect: frameRect, xRadius: size * 0.10, yRadius: size * 0.10)
    NSColor.white.setStroke()
    framePath.lineWidth = max(2.5, size * 0.055)
    framePath.stroke()

    let topBarHeight = size * 0.08
    let topBar = NSBezierPath()
    topBar.move(to: CGPoint(x: frameRect.minX, y: frameRect.maxY - topBarHeight))
    topBar.line(to: CGPoint(x: frameRect.maxX, y: frameRect.maxY - topBarHeight))
    topBar.lineWidth = max(1.5, size * 0.03)
    topBar.stroke()

    let sparkleCenter = CGPoint(x: cardRect.maxX - size * 0.20, y: cardRect.minY + size * 0.26)
    let sparkle = NSBezierPath()
    let sparkleLength = size * 0.07
    sparkle.move(to: CGPoint(x: sparkleCenter.x, y: sparkleCenter.y - sparkleLength))
    sparkle.line(to: CGPoint(x: sparkleCenter.x, y: sparkleCenter.y + sparkleLength))
    sparkle.move(to: CGPoint(x: sparkleCenter.x - sparkleLength, y: sparkleCenter.y))
    sparkle.line(to: CGPoint(x: sparkleCenter.x + sparkleLength, y: sparkleCenter.y))
    sparkle.lineWidth = max(1.5, size * 0.022)
    sparkle.lineCapStyle = .round
    sparkle.stroke()

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("Failed to rasterize \(name)")
    }

    try png.write(to: iconsetURL.appendingPathComponent(name))
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try task.run()
task.waitUntilExit()

guard task.terminationStatus == 0 else {
    fatalError("iconutil failed")
}

print(outputURL.path)
