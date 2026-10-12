import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: swift scripts/render_media_captions.swift <en-US|zh-Hans> <output-directory>")
}
let locale = CommandLine.arguments[1]
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let captions: [(String, String)]
switch locale {
case "en-US":
    captions = [
        ("Tiny language.\nBig ideas.", "30 original puzzles.\nPlay offline."),
        ("Think in\npatterns.", "Write H code.\nWatch it come to life."),
        ("One step.\nMore insight.", "Trace each move.\nFind your own solution."),
    ]
case "zh-Hans":
    captions = [
        ("小小语言\n大大巧思", "30 个原创关卡\n离线也能探索"),
        ("发现规律\n写出思路", "用 H 语言编程\n让每个目标亮起来"),
        ("一步一步\n看懂代码", "跟随每一次移动\n找到自己的解法"),
    ]
default:
    fatalError("Unsupported locale: \(locale)")
}
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for (index, caption) in captions.enumerated() {
    guard
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 1920, pixelsHigh: 1080, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: bitmap)
    else { fatalError("Cannot create caption bitmap") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    NSColor(deviceRed: 0.075, green: 0.15, blue: 0.17, alpha: 0.97).setFill()
    NSBezierPath(roundedRect: NSRect(x: 24, y: 230, width: 264, height: 238), xRadius: 20, yRadius: 20).fill()
    let mint = NSColor(deviceRed: 0.74, green: 0.9, blue: 0.82, alpha: 1)
    ("Herbot Bot" as NSString).draw(
        at: NSPoint(x: 46, y: 431),
        withAttributes: [.font: NSFont.systemFont(ofSize: 15, weight: .semibold), .foregroundColor: mint])
    (caption.0 as NSString).draw(
        in: NSRect(x: 46, y: 332, width: 220, height: 86),
        withAttributes: [.font: NSFont.systemFont(ofSize: 29, weight: .bold), .foregroundColor: NSColor.white])
    (caption.1 as NSString).draw(
        in: NSRect(x: 46, y: 251, width: 220, height: 65),
        withAttributes: [.font: NSFont.systemFont(ofSize: 18, weight: .medium), .foregroundColor: mint])
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Cannot encode caption PNG")
    }
    try png.write(to: output.appendingPathComponent("caption-\(index + 1).png"))
}
