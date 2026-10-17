import HerbertCore
import SwiftUI

/// The 3D board at full size: the window belongs to the board, with Herbert's controls beside it on wide windows
/// and below it on tall ones. Everything needed to watch a run stays within reach.
struct Board3DStage: View {
    @ObservedObject var model: GameModel
    let onClose: () -> Void

    @AppStorage("board.showTrail") private var showTrail = true
    @AppStorage("board.showGridDots") private var showGridDots = true
    @State private var rig = BoardCameraRig()
    @State private var focused = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width > geometry.size.height * 1.2 && geometry.size.width >= 560
            Group {
                if wide {
                    HStack(spacing: 0) {
                        board
                        VStack(alignment: .leading, spacing: 16) {
                            header
                            stats
                            // A short rail, such as a phone on its side, keeps room for the controls instead.
                            if geometry.size.height >= 480 { program(lines: 10) }
                            Spacer(minLength: 0)
                            footer
                        }.padding(.vertical, 12).padding(.trailing, 20).padding(.leading, 8)
                            .frame(width: min(340, max(280, geometry.size.width * 0.3)))
                    }
                } else {
                    VStack(spacing: 0) {
                        header.padding(.horizontal, 16).padding(.top, 4)
                        stats.padding(.horizontal, 16).padding(.top, 8)
                        board
                        VStack(spacing: 10) {
                            program(lines: 2)
                            footer
                        }.padding(.horizontal, 16).padding(.bottom, 8)
                    }
                }
            }
        }
        .background(Board3DPalette.backdropBottom.color().ignoresSafeArea())
        .foregroundStyle(Palette.ink)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("board-stage")
    }

    private var board: some View {
        Board3DView(
            model: model, rig: $rig, focused: focused, showTrail: showTrail, showGridDots: showGridDots,
            presentation: .stage,
            onToggleFocus: {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                    focused.toggle()
                    rig.resetFraming()
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Palette.line.opacity(0.7), lineWidth: 1))
        .padding(12)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).frame(width: 44, height: 44)
                    .background(.white, in: Circle()).overlay(Circle().stroke(Palette.line, lineWidth: 1))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain).keyboardShortcut(.cancelAction).accessibilityLabel("退出放大视图")
            .accessibilityIdentifier("close-stage")
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow(text: model.problem.number)
                Text(model.problem.displayTitle).font(.system(size: 17, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private var stats: some View {
        HStack(spacing: 0) {
            stat("已点亮", value: "\(model.session.visitedTargets.count) / \(model.session.board.targets.count)")
            Divider().frame(height: 26)
            stat(
                "代码长度", value: "\(model.bytes) / \(model.problem.byteLimit) B",
                danger: model.bytes > model.problem.byteLimit)
            Divider().frame(height: 26)
            stat("执行步数", value: "\(model.session.steps)")
        }.padding(.vertical, 10).background(.white, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 1))
            .accessibilityElement(children: .contain).accessibilityIdentifier("stage-stats")
    }

    private func stat(_ title: String, value: String, danger: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(title)).font(.system(size: 10)).foregroundStyle(Palette.muted).lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value).font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(danger ? Palette.danger : Palette.ink).contentTransition(.numericText()).lineLimit(1)
                .minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12)
    }

    /// What is running, read only: the stage is for watching, and the editor is one tap away.
    private func program(lines: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: "YOUR PROGRAM")
            Text(model.source.isEmpty ? L10n.text("尚未编写程序") : model.source)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(model.source.isEmpty ? Palette.muted : Palette.mint)
                .lineLimit(lines).frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("stage-program")
        }.padding(12).background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1))
    }

    private var footer: some View {
        VStack(spacing: 10) {
            if model.isCompleted { completion }
            GameStatusLine(model: model, identifierPrefix: "stage-")
            GameControls(model: model, editor: nil, identifierPrefix: "stage-")
        }
    }

    private var completion: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles").font(.system(size: 22)).foregroundStyle(Palette.mint)
            VStack(alignment: .leading, spacing: 3) {
                Text("漂亮，全部点亮！").font(.system(size: 15, weight: .bold))
                Text(model.completionSummary).font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
        }.padding(14).background(Palette.mintLight, in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .combine).accessibilityIdentifier("stage-completion")
    }
}
