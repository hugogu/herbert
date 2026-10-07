import SwiftUI

enum BoardStyle: String, CaseIterable, Identifiable {
    case modern, classic
    var id: String { rawValue }
    var title: LocalizedStringKey { self == .modern ? "现代风格" : "经典风格" }
    var background: Color { self == .classic ? Color(white: 0.98) : Palette.paper.opacity(0.7) }
}

struct BoardOptionsView: View {
    @AppStorage("board.style") private var style = BoardStyle.modern
    @AppStorage("board.showTrail") private var showTrail = true
    @AppStorage("board.showGridDots") private var showGridDots = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("棋盘设置").font(.headline)
                Spacer()
                Button("完成") { dismiss() }.accessibilityIdentifier("close-board-options")
            }.padding(16)
            Divider()
            Form {
                Section("棋盘外观") {
                    Picker("风格", selection: $style) {
                        ForEach(BoardStyle.allCases) { style in
                            Text(style.title).tag(style).accessibilityIdentifier("board-style-\(style.rawValue)")
                        }
                    }
                    .pickerStyle(.segmented).accessibilityIdentifier("board-style")
                    Toggle("显示网格点", isOn: $showGridDots).accessibilityIdentifier("show-grid-dots")
                }
                Section {
                    Toggle("显示运动轨迹", isOn: $showTrail).accessibilityIdentifier("show-trail")
                } footer: {
                    Text("轨迹保留本次运行走过的路径，重置棋盘或修改代码后清空。隐藏轨迹不会停止记录。")
                }
            }
            .formStyle(.grouped)

        }
        .frame(minWidth: 300, idealWidth: 380, minHeight: 300, idealHeight: 360)
        #if os(iOS)
            .presentationCompactAdaptation(.sheet)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        #endif
    }
}
