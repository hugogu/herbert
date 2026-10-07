import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

let output = CommandLine.arguments.dropFirst().first ?? "Herbert/Assets.xcassets/AppIcon.appiconset"
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
func makeIcon(size: Int, filename: String) throws {
    guard
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0), let context = NSGraphicsContext(bitmapImageRep: bitmap)
    else { throw CocoaError(.fileWriteUnknown) }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    NSColor(red: 0.08, green: 0.15, blue: 0.17, alpha: 1).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
    NSColor(red: 0.86, green: 0.94, blue: 0.88, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 238, y: 212, width: 548, height: 574), xRadius: 164, yRadius: 164).fill()
    NSColor(red: 0.1, green: 0.48, blue: 0.39, alpha: 1).setStroke()
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 390, y: 525))
    arrow.line(to: NSPoint(x: 512, y: 653))
    arrow.line(to: NSPoint(x: 634, y: 525))
    arrow.lineWidth = 50
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.stroke()
    NSColor(red: 0.1, green: 0.48, blue: 0.39, alpha: 1).setFill()
    for x in [420, 566] { NSBezierPath(ovalIn: NSRect(x: x, y: 365, width: 40, height: 40)).fill() }
    NSGraphicsContext.restoreGraphicsState()
    guard let source = bitmap.cgImage,
        let opaque = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else {
        throw CocoaError(.fileWriteUnknown)
    }
    opaque.draw(source, in: CGRect(x: 0, y: 0, width: size, height: size))
    let url = URL(fileURLWithPath: output).appendingPathComponent(filename)
    guard let image = opaque.makeImage(),
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}
var entries: [[String: String]] = []
try makeIcon(size: 1024, filename: "AppIcon.png")
entries.append(["idiom": "universal", "platform": "ios", "size": "1024x1024", "filename": "AppIcon.png"])
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "mac-\(size)@\(scale)x.png"
        try makeIcon(size: size * scale, filename: name)
        entries.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": name])
    }
}
let data = try JSONSerialization.data(
    withJSONObject: ["images": entries, "info": ["author": "xcode", "version": 1]],
    options: [.prettyPrinted, .sortedKeys])
try data.write(to: URL(fileURLWithPath: output).appendingPathComponent("Contents.json"))
