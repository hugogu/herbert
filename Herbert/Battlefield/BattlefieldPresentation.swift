import HerbertBattlefield
import SwiftUI

struct BattlefieldRetryCountdown: View {
    let retryAt: Date
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(L10n.text("等待 %ld 秒后重试", Int(ceil(max(0, retryAt.timeIntervalSince(context.date))))))
                .font(.caption).foregroundStyle(Palette.amber)
                .accessibilityIdentifier("battlefieldRetryCountdown")
        }
    }
}

#if os(macOS)
    import AppKit
#endif

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
        case .burnout: "Burnout"
        case .overloaded: L10n.text("过载")
        case .timedout: L10n.text("超时")
        case .tempUnavailable: L10n.text("临时不可用")
        case .accessDenied: L10n.text("拒绝访问")
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
        case .burnout: "flame.fill"
        case .overloaded: "exclamationmark.triangle"
        case .timedout: "clock.badge.exclamationmark"
        case .tempUnavailable: "wifi.exclamationmark"
        case .accessDenied: "lock.slash.fill"
        }
    }

    var color: Color {
        switch self {
        case .solved: Palette.mint
        case .failed, .error, .accessDenied: Palette.danger
        case .requesting, .judging, .burnout, .overloaded, .timedout, .tempUnavailable: Palette.amber
        case .queued, .cancelled: Palette.muted
        }
    }
}

func battlefieldCache(_ entrant: EntrantResult) -> String {
    entrant.cacheRate.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? L10n.text("未提供")
}

func battlefieldInputOutputTokens(_ entrant: EntrantResult) -> String {
    (entrant.hasEstimatedUsage ? "≈ " : "")
        + "\(entrant.inputTokens.formatted()) / \(entrant.outputTokens.formatted())"
}

func battlefieldTotalTokens(_ entrant: EntrantResult) -> String {
    (entrant.hasEstimatedUsage ? "≈ " : "") + entrant.totalTokens.formatted()
}

struct BattlefieldModelTime: View {
    let entrant: EntrantResult
    var snapshotAt: Date?

    var body: some View {
        Group {
            if let snapshotAt {
                timing(at: snapshotAt)
            } else if entrant.answers.contains(where: { $0.attempts.contains { $0.finishedAt == nil } }) {
                TimelineView(.periodic(from: .now, by: 1)) { context in timing(at: context.date) }
            } else {
                timing(at: .now)
            }
        }
    }

    private func timing(at now: Date) -> some View {
        let duration = battlefieldDuration(entrant.totalAttemptTime(at: now))
        return Label(duration, systemImage: "clock").fixedSize().monospacedDigit()
            .accessibilityElement(children: .ignore).accessibilityLabel(L10n.text("总用时 %@", duration))
            .help(L10n.text("所有尝试的用时之和，包含重试和失败，不包含等待重试或比赛间隔。"))
    }
}

func battlefieldScore(_ score: Double) -> String {
    score.formatted(.number.precision(.fractionLength(0...2)))
}

func battlefieldPercentage(_ fraction: Double) -> String {
    fraction.formatted(.percent.precision(.fractionLength(0...2)))
}

func battlefieldDuration(_ seconds: TimeInterval) -> String {
    let seconds = Int(max(0, seconds))
    return String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
}

extension CompetitionConfiguration {
    var settingsDescription: String {
        if let legacyMode { return L10n.text("旧版比赛设置：%@", legacyMode.title) }
        let time = timeLimitEnabled ? L10n.text("时限 %@", String(Int(timeLimitSeconds)) + "s") : L10n.text("不限时")
        let tokens =
            problemTokenLimitEnabled ? L10n.text("每题 %@ tokens", problemTokenLimit.formatted()) : L10n.text("不限 Token")
        return time + " · " + tokens
    }
}

extension CompetitionResult {
    var scoringDescription: String {
        L10n.text(
            scoringPolicy == .legacyAccepted
                ? "每题通过 100 分 · 同分比较代码 byte 数与完成时间"
                : "目标覆盖率 ×（80 + 20 × 代码压缩率）· 每题取最高分 · 同分比较 Token 与完成时间")
    }
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

enum BattlefieldSheetLayout {
    case standard, answer, puzzles
    var minimumWidth: CGFloat { 520 }
    var preferredWidth: CGFloat {
        switch self {
        case .standard: 700
        case .answer, .puzzles: 900
        }
    }
}

struct BattlefieldSheet<Content: View>: View {
    let title: String
    var layout: BattlefieldSheetLayout = .standard
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
            .frame(
                minWidth: layout.minimumWidth, idealWidth: layout.preferredWidth, maxWidth: .infinity,
                minHeight: 550, idealHeight: 740, maxHeight: .infinity
            )
            .background(
                ResizableBattlefieldSheet(minimumWidth: layout.minimumWidth, preferredWidth: layout.preferredWidth))
        #endif
    }
}

#if os(macOS)
    private struct ResizableBattlefieldSheet: NSViewRepresentable {
        let minimumWidth: CGFloat
        let preferredWidth: CGFloat
        func makeNSView(context: Context) -> SheetView {
            let view = SheetView()
            view.minimumWidth = minimumWidth
            view.preferredWidth = preferredWidth
            return view
        }
        func updateNSView(_ nsView: SheetView, context: Context) { nsView.minimumWidth = minimumWidth }

        final class SheetView: NSView {
            var minimumWidth: CGFloat = 520
            var preferredWidth: CGFloat = 700
            override func viewDidMoveToWindow() {
                super.viewDidMoveToWindow()
                guard let window else { return }
                let minimum = minimumWidth
                let preferred = preferredWidth
                DispatchQueue.main.async { [weak window] in
                    guard let window else { return }
                    window.styleMask.insert(.resizable)
                    window.contentMinSize = NSSize(width: minimum, height: 550)
                    window.setContentSize(NSSize(width: preferred, height: 740))
                }
            }
        }
    }
#endif
