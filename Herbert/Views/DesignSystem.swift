import SwiftUI

// A quiet, tactile workbench: mint for actions, amber for destinations.
enum Palette {
    static let ink = Color(red: 0.08, green: 0.15, blue: 0.17)
    static let muted = Color(red: 0.40, green: 0.47, blue: 0.46)
    static let mint = Color(red: 0.10, green: 0.48, blue: 0.39)
    static let mintLight = Color(red: 0.86, green: 0.94, blue: 0.88)
    static let paper = Color(red: 0.96, green: 0.96, blue: 0.93)
    static let line = Color(red: 0.86, green: 0.89, blue: 0.86)
    static let amber = Color(red: 0.94, green: 0.66, blue: 0.24)
    static let danger = Color(red: 0.72, green: 0.30, blue: 0.23)
}

struct Eyebrow: View {
    var text: String
    var color: Color = Palette.muted
    var body: some View {
        Text(LocalizedStringKey(text)).font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(2).foregroundStyle(color)
    }
}

struct Pill: View {
    var text: String
    var color: Color = Palette.mint
    var body: some View {
        Text(LocalizedStringKey(text)).font(.system(size: 11, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 9).padding(.vertical, 5)
            .foregroundStyle(color).background(color.opacity(0.09), in: Capsule())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 15, weight: .semibold))
            .frame(minHeight: 48).frame(maxWidth: .infinity)
            .foregroundStyle(.white).background(
                isEnabled ? Palette.mint : Palette.muted, in: RoundedRectangle(cornerRadius: 14)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

private struct ActionButtonStyle: ButtonStyle {
    let prominent: Bool
    let color: Color
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let ink = isEnabled ? color : Palette.muted
        configuration.label
            .fontWeight(.medium)
            .foregroundStyle(prominent ? Color.white : ink)
            .padding(.horizontal, 12).padding(.vertical, 6)
            #if os(iOS)
                .frame(minHeight: 44)
            #else
                .frame(minHeight: 28)
            #endif
            .background(prominent ? ink : ink.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct RobotMark: View {
    var body: some View {
        Image(systemName: "arrow.up").font(.system(size: 22, weight: .heavy, design: .rounded))
            .foregroundStyle(Palette.ink).frame(width: 46, height: 46)
            .background(Palette.mintLight, in: RoundedRectangle(cornerRadius: 15))
            .overlay(alignment: .bottom) {
                HStack(spacing: 11) {
                    Circle().frame(width: 4, height: 4)
                    Circle().frame(width: 4, height: 4)
                }.foregroundStyle(Palette.mint).offset(y: -7)
            }
    }
}

extension View {
    // Own both foreground and background: native prominent fills disappear in inactive Mac windows.
    func prominentButtonStyle() -> some View {
        buttonStyle(ActionButtonStyle(prominent: true, color: Palette.mint))
    }

    func secondaryButtonStyle(color: Color = Palette.mint) -> some View {
        buttonStyle(ActionButtonStyle(prominent: false, color: color))
    }

    func panel(padding: CGFloat = 20) -> some View {
        self.padding(padding).background(.white, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line.opacity(0.7), lineWidth: 1))
    }
}
