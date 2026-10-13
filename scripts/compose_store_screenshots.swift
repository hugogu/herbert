// Frames raw app captures with localized captions at the App Store screenshot sizes.
// Usage: swift scripts/compose_store_screenshots.swift <captures> <captions.json> <output>
// Captures are read from <captures>/<device>/<language>/<scene>.png and written to
// <output>/<device>/<App Store locale>/<NN>-<scene>.png as opaque RGB PNGs.
import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Captions: Decodable {
    let scenes: [String]
    let locales: [String: String]
    let captions: [String: [String: [String]]]
}

struct Device {
    let name: String
    let canvas: CGSize
    let cornerRadius: CGFloat
    let titleSize: CGFloat
    let subtitleSize: CGFloat
    let lines: Int
    let top: CGFloat
    let gap: CGFloat
    let bottom: CGFloat
}

// App Store Connect requires the 6.3-inch medium iPhone; the 6.9-inch large set is optional.
let devices = [
    Device(
        name: "iphone-6.3", canvas: CGSize(width: 1206, height: 2622), cornerRadius: 0.12, titleSize: 84,
        subtitleSize: 46, lines: 2, top: 137, gap: 77, bottom: 100),
    Device(
        name: "iphone-6.9", canvas: CGSize(width: 1320, height: 2868), cornerRadius: 0.12, titleSize: 92,
        subtitleSize: 50, lines: 2, top: 150, gap: 84, bottom: 110),
    Device(
        name: "ipad", canvas: CGSize(width: 2752, height: 2064), cornerRadius: 0.02, titleSize: 96,
        subtitleSize: 52, lines: 1, top: 110, gap: 72, bottom: 90),
    Device(
        name: "mac", canvas: CGSize(width: 2880, height: 1800), cornerRadius: 0.012, titleSize: 88,
        subtitleSize: 48, lines: 1, top: 100, gap: 64, bottom: 80),
]

let ink = NSColor(red: 0.08, green: 0.15, blue: 0.17, alpha: 1)
let deepInk = NSColor(red: 0.05, green: 0.10, blue: 0.11, alpha: 1)
let mintLight = NSColor(red: 0.86, green: 0.94, blue: 0.88, alpha: 1)

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func loadImage(_ url: URL) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { fail("Missing or unreadable capture: \(url.path)") }
    return image
}

/// XCTest stores a landscape-left iPad screen in portrait pixel order, turned clockwise.
func upright(_ image: CGImage, for device: Device) -> CGImage {
    guard device.canvas.width > device.canvas.height, image.height > image.width else { return image }
    guard
        let context = CGContext(
            data: nil, width: image.height, height: image.width, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { fail("Cannot rotate a \(image.width) × \(image.height) capture") }
    context.translateBy(x: CGFloat(image.height), y: 0)
    context.rotate(by: .pi / 2)
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    guard let rotated = context.makeImage() else { fail("Cannot rotate a \(image.width) × \(image.height) capture") }
    return rotated
}

func paragraph(lineHeight: CGFloat) -> NSParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    style.lineBreakMode = .byWordWrapping
    style.lineHeightMultiple = lineHeight
    return style
}

/// Shrinks the font until the text fits the device's line budget.
func caption(
    _ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, language: String, width: CGFloat, lines: Int
)
    -> (NSAttributedString, CGFloat)
{
    var size = size
    while true {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? base
        let lineHeight: CGFloat = weight == .bold ? 1.05 : 1.2
        let string = NSAttributedString(
            string: text,
            attributes: [
                .font: font, .foregroundColor: color, .paragraphStyle: paragraph(lineHeight: lineHeight),
                // Picks PingFang SC for Simplified Chinese and Hiragino for Japanese Han characters.
                NSAttributedString.Key(kCTLanguageAttributeName as String): language,
            ])
        let height = string.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).height
        if height <= size * lineHeight * 1.25 * CGFloat(lines) || size < 30 { return (string, height) }
        size -= 2
    }
}

func compose(_ image: CGImage, device: Device, title: String, subtitle: String, language: String) -> CGImage {
    let width = Int(device.canvas.width)
    let height = Int(device.canvas.height)
    guard
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: bitmap)
    else { fail("Cannot create a \(width) × \(height) drawing context") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let canvas = CGRect(origin: .zero, size: device.canvas)
    NSGradient(starting: ink, ending: deepInk)?.draw(in: canvas, angle: -90)
    // The faint dot grid echoes the game board.
    NSColor(white: 1, alpha: 0.07).setFill()
    let spacing = device.canvas.width / 30
    for x in stride(from: spacing / 2, to: canvas.width, by: spacing) {
        for y in stride(from: spacing / 2, to: canvas.height, by: spacing) {
            NSBezierPath(ovalIn: CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5)).fill()
        }
    }

    let textWidth = device.canvas.width * 0.86
    let (titleText, titleHeight) = caption(
        title, size: device.titleSize, weight: .bold, color: .white, language: language, width: textWidth,
        lines: device.lines)
    let (subtitleText, subtitleHeight) = caption(
        subtitle, size: device.subtitleSize, weight: .regular, color: mintLight, language: language,
        width: textWidth, lines: device.lines)
    // Reserve the full line budget so every screenshot in a set sits at the same height.
    let titleBlock = device.titleSize * 1.05 * 1.25 * CGFloat(device.lines)
    let subtitleBlock = device.subtitleSize * 1.2 * 1.25 * CGFloat(device.lines)
    let spacingBetween = device.subtitleSize * 0.55
    let textTop = device.canvas.height - device.top
    let titleTop = textTop - (titleBlock - titleHeight) / 2
    titleText.draw(
        with: CGRect(
            x: (device.canvas.width - textWidth) / 2, y: titleTop - titleHeight, width: textWidth, height: titleHeight),
        options: [.usesLineFragmentOrigin, .usesFontLeading])
    let subtitleTop = textTop - titleBlock - spacingBetween - (subtitleBlock - subtitleHeight) / 2
    subtitleText.draw(
        with: CGRect(
            x: (device.canvas.width - textWidth) / 2, y: subtitleTop - subtitleHeight, width: textWidth,
            height: subtitleHeight),
        options: [.usesLineFragmentOrigin, .usesFontLeading])

    let available = CGSize(
        width: device.canvas.width * 0.9,
        height: textTop - titleBlock - spacingBetween - subtitleBlock - device.gap - device.bottom)
    let scale = min(available.width / CGFloat(image.width), available.height / CGFloat(image.height))
    let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
    let frame = CGRect(
        x: (device.canvas.width - size.width) / 2, y: device.bottom + (available.height - size.height) / 2,
        width: size.width, height: size.height)
    let radius = size.width * device.cornerRadius
    let shape = NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 0, alpha: 0.45)
    shadow.shadowBlurRadius = device.canvas.width * 0.02
    shadow.shadowOffset = CGSize(width: 0, height: -device.canvas.width * 0.006)
    shadow.set()
    ink.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    context.cgContext.interpolationQuality = .high
    context.cgContext.draw(image, in: frame)
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()

    guard let source = bitmap.cgImage,
        let opaque = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { fail("Cannot create an opaque \(width) × \(height) context") }
    opaque.draw(source, in: canvas)
    guard let result = opaque.makeImage() else { fail("Cannot render \(width) × \(height) screenshot") }
    return result
}

func write(_ image: CGImage, to url: URL) {
    do {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    } catch { fail("Cannot create \(url.deletingLastPathComponent().path): \(error)") }
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fail("Cannot write \(url.path)") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fail("Cannot write \(url.path)") }
}

let arguments = CommandLine.arguments
guard arguments.count == 4 else {
    fail("Usage: swift scripts/compose_store_screenshots.swift <captures> <captions.json> <output>")
}
let captures = URL(fileURLWithPath: arguments[1])
let output = URL(fileURLWithPath: arguments[3])
let captions: Captions
do {
    captions = try JSONDecoder().decode(Captions.self, from: Data(contentsOf: URL(fileURLWithPath: arguments[2])))
} catch { fail("Cannot read captions: \(error)") }

var written = 0
for device in devices {
    let deviceCaptures = captures.appendingPathComponent(device.name)
    guard FileManager.default.fileExists(atPath: deviceCaptures.path) else { continue }
    for (language, locale) in captions.locales.sorted(by: { $0.key < $1.key }) {
        let languageCaptures = deviceCaptures.appendingPathComponent(language)
        guard FileManager.default.fileExists(atPath: languageCaptures.path) else { continue }
        for (index, scene) in captions.scenes.enumerated() {
            guard var text = captions.captions[language]?[scene], text.count == 2 else {
                fail("Missing \(language) caption for \(scene)")
            }
            // Line breaks guide narrow iPhone captions; wide canvases fit each caption on one line.
            if device.lines == 1 {
                text = text.map { $0.replacingOccurrences(of: "\n", with: language == "en" ? " " : "") }
            }
            let image = upright(
                loadImage(languageCaptures.appendingPathComponent("\(scene).png")), for: device)
            let result = compose(image, device: device, title: text[0], subtitle: text[1], language: language)
            let name = String(format: "%02d-%@.png", index + 1, scene)
            write(
                result,
                to: output.appendingPathComponent(device.name).appendingPathComponent(locale)
                    .appendingPathComponent(name))
            written += 1
        }
    }
}
guard written > 0 else { fail("No captures found under \(captures.path)") }
print("Composed \(written) App Store screenshots in \(output.path). Review every image before uploading.")
