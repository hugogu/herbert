import HerbertBattlefield
import SwiftUI

extension CompetitionMode {
    var title: String {
        switch self {
        case .timed: L10n.text("限时")
        case .tokenLimited: L10n.text("限 Token")
        case .bestEffort: "Best Effort"
        }
    }
}

extension CompetitionStatus {
    var title: String {
        switch self {
        case .running: L10n.text("比赛进行中")
        case .completed: L10n.text("比赛完成")
        case .timeLimit: L10n.text("时间已到")
        case .tokenLimit: L10n.text("Token 预算用完")
        case .userStopped: L10n.text("已手动终止")
        case .backgrounded: L10n.text("进入后台，比赛已结束")
        case .interrupted: L10n.text("比赛中断")
        }
    }
}

extension ProblemAnswerStatus {
    var title: String {
        switch self {
        case .queued: L10n.text("等待")
        case .requesting: L10n.text("生成中")
        case .judging: L10n.text("验题中")
        case .solved: L10n.text("通过")
        case .failed: L10n.text("未通过")
        case .error: L10n.text("调用失败")
        case .cancelled: L10n.text("已停止")
        }
    }

    var symbol: String {
        switch self {
        case .queued: "minus"
        case .requesting: "ellipsis"
        case .judging: "gearshape"
        case .solved: "checkmark"
        case .failed: "xmark"
        case .error: "exclamationmark"
        case .cancelled: "stop.fill"
        }
    }

    var color: Color {
        switch self {
        case .solved: Palette.mint
        case .failed, .error: Palette.danger
        case .requesting, .judging: Palette.amber
        case .queued, .cancelled: Palette.muted
        }
    }
}

func battlefieldProblemID(_ id: Int) -> String {
    id >= 10_001 ? String(format: "L%02d", id - 10_000) : String(format: "%04d", id)
}

func battlefieldCache(_ entrant: EntrantResult) -> String {
    entrant.cacheRate.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? L10n.text("未提供")
}

struct BattlefieldNotice: View {
    let text: String
    var body: some View {
        Label(text, systemImage: "info.circle")
            .font(.callout).foregroundStyle(Palette.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14).background(Palette.mintLight.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            .textSelection(.enabled)
    }
}

struct BattlefieldMessages: View {
    @EnvironmentObject private var battlefield: BattlefieldModel
    var body: some View {
        if let message = battlefield.message {
            BattlefieldNotice(text: message).accessibilityIdentifier("battlefieldMessage")
        }
        if let message = battlefield.storageMessage {
            VStack(alignment: .leading) {
                BattlefieldNotice(text: message)
                if battlefield.liveResult != nil {
                    Button("重试保存") { Task { await battlefield.retrySave() } }
                }
            }
        }
    }
}

struct BattlefieldSheet<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            content.navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭窗口") { dismiss() }.accessibilityIdentifier("closeBattlefieldSheet")
                    }
                }
        }
        #if os(macOS)
            .frame(minWidth: 520, idealWidth: 700, minHeight: 550, idealHeight: 740)
        #endif
    }
}
