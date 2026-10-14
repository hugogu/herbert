import SwiftUI

/// An RGB color that can be lit, darkened and mixed before it becomes a SwiftUI color.
struct Tone: Equatable {
    var red: Double
    var green: Double
    var blue: Double

    init(_ hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
    }

    private init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    func lit(_ factor: Double) -> Tone {
        Tone(red: min(1, red * factor), green: min(1, green * factor), blue: min(1, blue * factor))
    }

    func mixed(with other: Tone, _ amount: Double) -> Tone {
        Tone(
            red: red + (other.red - red) * amount, green: green + (other.green - green) * amount,
            blue: blue + (other.blue - blue) * amount)
    }

    func color(_ opacity: Double = 1) -> Color {
        Color(red: red, green: green, blue: blue).opacity(opacity)
    }
}

/// Scene colors for the 3D board: a warm cream studio, charcoal stone, amber discs and a cyan trail.
enum Board3DPalette {
    static let backdropTop = Tone(0xFBF6EC)
    static let backdropBottom = Tone(0xEDE1CC)
    static let floor = Tone(0xD9D5CD)
    static let floorSeam = Tone(0x8C877F)
    static let wall = Tone(0x6A645E)
    static let curb = Tone(0x8D877F)
    static let amber = Tone(0xF6A12E)
    static let amberLight = Tone(0xFFD27A)
    static let amberDeep = Tone(0xC2600C)
    static let lit = Tone(0x39D3EE)
    static let litLight = Tone(0xBDF6FF)
    static let litDeep = Tone(0x0C7E98)
    static let trail = Tone(0x35CCE8)
    static let trailCore = Tone(0xE6FCFF)
    static let hole = Tone(0x14110F)
    static let shell = Tone(0xF7F6F2)
    static let shellShade = Tone(0xC9CCCB)
    static let visor = Tone(0x1D2A33)
    static let eye = Tone(0x4DEBFF)
    static let rubber = Tone(0x2B2F33)
}

/// Deterministic per-cell variation, so stone and tiles look hand-made but never shimmer between frames.
func cellNoise(_ x: Int, _ y: Int, salt: Int = 0) -> Double {
    var hash = UInt32(truncatingIfNeeded: x &* 73_856_093) ^ UInt32(truncatingIfNeeded: y &* 19_349_663)
    hash ^= UInt32(truncatingIfNeeded: salt &* 83_492_791)
    hash ^= hash >> 13
    hash = hash &* 0x5BD1_E995
    hash ^= hash >> 15
    return Double(hash & 0xFFFF) / 65_535
}
