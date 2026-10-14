import SwiftUI

/// Herbert's status line: the latest error, or what the board is waiting for.
struct GameStatusLine: View {
    @ObservedObject var model: GameModel
    /// Distinguishes a second copy of the line from the one on the page behind it.
    var identifierPrefix = ""

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: model.message == nil ? "terminal" : "exclamationmark.circle")
            Text(model.message ?? statusText).lineSpacing(3)
                .accessibilityIdentifier(identifierPrefix + "game-status")
            Spacer(minLength: 0)
        }.font(.system(size: 12)).foregroundStyle(model.message == nil ? Palette.muted : Palette.danger)
            .padding(.horizontal, 3).frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusText: String {
        switch model.session.status {
        case .ready: L10n.text("观察棋盘，编写程序，然后运行。")
        case .running: model.lastEvent == .trap ? L10n.text("踩到陷阱，所有目标已重置。") : L10n.text("Herbert 正在执行你的程序…")
        case .paused: model.lastEvent == .trap ? L10n.text("踩到陷阱，所有目标已重置。") : L10n.text("已暂停，可以单步观察下一条指令。")
        case .completed: L10n.text("已完成！你的思路点亮了所有目标。")
        case .ended: L10n.text("程序已结束，还有目标未点亮。调整代码再试试。")
        case .failed(let message): message
        }
    }
}

/// Run, step and reset with the speed picker. Pass the editor so the keyboard closes before a run.
struct GameControls: View {
    @ObservedObject var model: GameModel
    var editor: EditorController?
    /// Distinguishes a second copy of the controls from the ones on the page behind it.
    var identifierPrefix = ""

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    editor?.dismiss()
                    model.toggleRun()
                } label: {
                    Label(
                        LocalizedStringKey(model.isRunning ? "暂停" : model.isCompleted ? "再运行" : "运行"),
                        systemImage: model.isRunning ? "pause.fill" : "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.return, modifiers: .command)
                .accessibilityIdentifier(identifierPrefix + "run-program")
                Button {
                    editor?.dismiss()
                    model.step()
                } label: {
                    Image(systemName: "forward.end.fill").frame(width: 48, height: 48)
                }
                .buttonStyle(.plain).background(.white, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1))
                .accessibilityLabel("单步执行").accessibilityIdentifier(identifierPrefix + "step-program")
                Button {
                    model.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise").frame(width: 48, height: 48)
                }
                .buttonStyle(.plain).background(.white, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1))
                .accessibilityLabel("重置棋盘").accessibilityIdentifier(identifierPrefix + "reset-program")
            }
            HStack {
                Label("速度", systemImage: "speedometer").font(.system(size: 10)).foregroundStyle(Palette.muted)
                Spacer()
                ForEach([1.0, 4, 16, 64], id: \.self) { speed in
                    Button {
                        model.speed = speed
                    } label: {
                        Text(speed == 64 ? L10n.text("极速") : "\(Int(speed))×")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced)).frame(
                                width: 42, height: 26
                            )
                            .foregroundStyle(model.speed == speed ? Palette.mint : Palette.muted)
                            .background(model.speed == speed ? Palette.mintLight : Color.clear, in: Capsule())
                    }.buttonStyle(.plain)
                }
            }
        }
    }
}

extension GameModel {
    /// The byte-count line shown after every target lights up, which says whether the run was saved.
    var completionSummary: String {
        !session.isAccepted
            ? L10n.text("%ld byte · 超过长度限制，仅供试运行，未保存为解答", session.programBytes)
            : isTrial
                ? L10n.text("%ld byte · AI 答案试运行完成", session.programBytes)
                : L10n.text("%ld byte · 最短解已保存到本机", session.programBytes)
    }
}
