import HerbertBattlefield
import HerbertCore
import SwiftUI

private struct BattlefieldAnswerSelection: Identifiable {
    let resultID: UUID
    let entrant: EntrantResult
    let answer: ProblemAnswer
    let problem: Problem
    let scoring: BattlefieldScoring
    var id: String { "\(entrant.id)/\(answer.id)" }
}

private struct BattlefieldTrial: Hashable {
    let problem: Problem
    let source: String
}

struct BattlefieldDashboard: View {
    @EnvironmentObject private var battlefield: BattlefieldModel
    @EnvironmentObject private var store: AppStore
    let result: CompetitionResult
    @State private var selectedAnswer: BattlefieldAnswerSelection?
    @State private var sharing = false
    @State private var inspecting = false
    @State private var trial: BattlefieldTrial?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            progressTable
            if result.entrants.contains(where: \.hasEstimatedUsage) {
                BattlefieldNotice(text: L10n.text("≈ 表示包含实时估算或取消请求的部分用量。缓存率仅在全部尝试均返回准确缓存用量时显示。最终账单以服务商为准。"))
            }
        }
        .navigationDestination(item: $trial) { trial in
            GameDestination(problem: trial.problem, store: store, trialSource: trial.source)
        }
        .sheet(item: $selectedAnswer) { selection in
            BattlefieldAnswerView(snapshot: selection) { program in
                selectedAnswer = nil
                trial = BattlefieldTrial(problem: selection.problem, source: program)
            }
        }.sheet(isPresented: $sharing) { BattlefieldShareView(result: result) }
        .sheet(isPresented: $inspecting) {
            BattlefieldSheet(title: L10n.text("比赛配置与提示词")) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(result.id.uuidString).font(.caption.monospaced())
                        Text(L10n.text("每题最多 %ld 次机会", result.configuration.attemptsPerProblem))
                        Text(result.configuration.settingsDescription)
                        if let legacy = result.configuration.legacyMode {
                            Text(L10n.text("旧版比赛设置：%@", legacy.title))
                            if let limit = result.configuration.legacyTokenLimit, legacy == .tokenLimited {
                                Text("Legacy token budget: " + limit.formatted())
                                Text(
                                    result.configuration.legacyTokenBudgetScope == .shared
                                        ? L10n.text("全场共享") : L10n.text("每个 AI 独立"))
                            }
                        }
                        Text(result.scoringDescription).font(.callout).foregroundStyle(Palette.muted)
                        BattlefieldRulesView(source: result.systemPrompt)
                    }.textSelection(.enabled).padding(24)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(result.status.title).font(.largeTitle.bold())
                    Spacer()
                    actions
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text(result.status.title).font(.title.bold())
                    actions
                }
            }
            HStack(spacing: 12) {
                Pill(text: result.configuration.settingsDescription)
                Text(L10n.text("%ld 个 AI · %ld 道题", result.entrants.count, result.problems.count))
                    .font(.callout).foregroundStyle(Palette.muted)
            }
            Text(result.startedAt, format: .dateTime.year().month().day().hour().minute()).font(.caption)
                .foregroundStyle(Palette.muted)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = max(0, (result.finishedAt ?? context.date).timeIntervalSince(result.startedAt))
                HStack(spacing: 16) {
                    Label(battlefieldDuration(elapsed), systemImage: "clock")
                    if result.configuration.timeLimitEnabled {
                        Text(L10n.text("时限 %@", battlefieldDuration(result.configuration.timeLimitSeconds)))
                    }
                    Label(result.totalTokens.formatted() + " tokens", systemImage: "sparkles")
                }.font(.caption.monospaced()).foregroundStyle(Palette.muted)
            }

        }
    }

    private var actions: some View {
        HStack {
            Button {
                inspecting = true
            } label: {
                Image(systemName: "doc.text.magnifyingglass")
            }
            .accessibilityLabel(L10n.text("比赛配置与提示词"))
            if result.status == .running {
                Button(role: .destructive) {
                    Task { await battlefield.stop() }
                } label: {
                    Label("终止比赛", systemImage: "stop.fill")
                }.buttonStyle(.bordered).accessibilityIdentifier("stopBattlefield")
            } else {
                Button {
                    sharing = true
                } label: {
                    Label("分享结果图片", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent).accessibilityIdentifier("shareBattlefield")
            }
        }
    }

    private var progressTable: some View {
        let ranking = result.ranked
        let answers = Dictionary(
            uniqueKeysWithValues: ranking.map { entrant in
                (entrant.id, Dictionary(uniqueKeysWithValues: entrant.answers.map { ($0.id, $0) }))
            })
        return VStack(alignment: .leading, spacing: 16) {
            Text("逐题进度").font(.title2.bold())
            Text(result.scoringDescription).font(.caption).foregroundStyle(Palette.muted)
            Text("点击答案查看完整程序、反馈与重试记录，或进入棋盘试运行。")
                .font(.caption).foregroundStyle(Palette.muted)
            ScrollView(.horizontal) {
                Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        Text("题目").font(.caption.bold()).frame(width: 80, alignment: .leading)
                        ForEach(Array(ranking.enumerated()), id: \.element.id) { index, entrant in
                            modelHeader(entrant, rank: index + 1)
                        }
                    }
                    Divider().gridCellUnsizedAxes(.horizontal)
                    ForEach(result.problems) { problem in
                        GridRow {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(problem.number).font(.system(.callout, design: .monospaced))
                                Text("\(problem.byteLimit) bytes").font(.caption2).foregroundStyle(Palette.muted)
                            }.frame(width: 80, alignment: .leading).padding(.top, 12)
                            ForEach(ranking) { entrant in
                                if let answer = answers[entrant.id]?[problem.id] {
                                    answerCell(answer, entrant: entrant, problem: problem)
                                }
                            }
                        }
                    }
                }
            }
        }.panel()
    }

    private func modelHeader(_ entrant: EntrantResult, rank: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "%02d", rank)).font(.title2.bold()).foregroundStyle(Palette.mint)
                Text(entrant.entrant.preset.model.displayName).font(.headline).lineLimit(2).padding(
                    .trailing, entrant.error == nil ? 0 : 20)
            }
            HStack {
                Text(entrant.entrant.providerName).lineLimit(1)
                Spacer(minLength: 4)
                Text(L10n.text("通过 %ld/%ld", entrant.solved, result.problems.count))
            }.font(.caption).foregroundStyle(Palette.muted)
            metric(
                L10n.text("输入 / 输出 Token"),
                (entrant.hasEstimatedUsage ? "≈ " : "")
                    + "\(entrant.inputTokens.formatted()) / \(entrant.outputTokens.formatted())")
            metric(L10n.text("输入缓存率"), battlefieldCache(entrant))
            metric(L10n.text("总 Token"), (entrant.hasEstimatedUsage ? "≈ " : "") + entrant.totalTokens.formatted())
            Divider()
            HStack(alignment: .firstTextBaseline) {
                Text(battlefieldPercentage(result.scoreFraction(for: entrant))).font(
                    .system(size: 30, weight: .bold, design: .rounded)
                )
                .contentTransition(.numericText()).foregroundStyle(Palette.mint)
                .accessibilityIdentifier("score-\(entrant.entrant.preset.model.id)")
                Spacer(minLength: 4)
                Text(L10n.text("%@ 分", battlefieldScore(result.score(for: entrant))))
                    .font(.caption).foregroundStyle(Palette.muted).monospacedDigit()
                    .accessibilityIdentifier("points-\(entrant.entrant.preset.model.id)")
            }

        }.frame(width: 224, alignment: .leading).padding(12)
            .background(Palette.paper, in: RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .topTrailing) {
                if let error = entrant.error {
                    BattlefieldErrorIndicator(message: error).padding(10)
                }
            }
            .help(entrant.entrant.providerName + " / " + entrant.entrant.preset.model.id)
    }

    private func answerCell(_ answer: ProblemAnswer, entrant: EntrantResult, problem: Problem) -> some View {
        let attempt =
            [.requesting, .judging].contains(answer.status)
            ? answer.attempts.last : result.scoringPolicy.bestAttempt(answer, problem: problem)
        let score = battlefieldScore(result.scoringPolicy.score(answer, problem: problem))
        return Button {
            selectedAnswer = BattlefieldAnswerSelection(
                resultID: result.id, entrant: entrant, answer: answer, problem: problem, scoring: result.scoringPolicy)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: answer.status.symbol)
                    Text(answer.status.title).font(.caption.bold())
                    Spacer(minLength: 4)
                    if let attempt {
                        Text(L10n.text("第 %ld 次尝试", attempt.id)).font(.caption2.monospaced()).foregroundStyle(
                            Palette.muted)
                    }
                    Text(score).font(.caption.monospaced().bold())
                }.foregroundStyle(answer.status.color)
                HStack(spacing: 6) {
                    if let program = attempt?.program {
                        Text(String(program.prefix(180)).replacingOccurrences(of: "\n", with: " ⏎ ")).font(
                            .system(.caption, design: .monospaced)
                        )
                        .foregroundStyle(Palette.ink).lineLimit(1)
                    } else {
                        Text(answer.status.title).font(.caption).foregroundStyle(Palette.muted).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if let attempt { BattlefieldAttemptTime(attempt: attempt, compact: true) }
                }
            }.frame(width: 224, height: 38, alignment: .topLeading).padding(.horizontal, 12).padding(.vertical, 10)
                .background(answer.status.color.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain)
            .accessibilityIdentifier("answer-\(entrant.entrant.preset.model.id)-\(problem.id)")
            .accessibilityLabel(
                problem.number + " " + entrant.entrant.preset.model.displayName
                    + " " + answer.status.title + " " + score)
    }

    private func metric(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name).foregroundStyle(Palette.muted)
            Spacer(minLength: 4)
            Text(value).monospacedDigit()
        }.font(.caption2)
    }

}

private struct BattlefieldAnswerView: View {
    @EnvironmentObject private var battlefield: BattlefieldModel
    @State private var collapsedAttempts: Set<Int> = []
    @State private var expandedReasoning: Set<Int> = []
    let snapshot: BattlefieldAnswerSelection
    let onTry: (String) -> Void
    private func providerFailed(_ attempt: AnswerAttempt) -> Bool {
        ["error", "content_filter"].contains(attempt.finishReason ?? "")
    }
    private var selection: BattlefieldAnswerSelection {
        guard let live = battlefield.liveResult, live.id == snapshot.resultID,
            let entrant = live.entrants.first(where: { $0.id == snapshot.entrant.id }),
            let answer = entrant.answers.first(where: { $0.id == snapshot.answer.id })
        else { return snapshot }
        return BattlefieldAnswerSelection(
            resultID: live.id, entrant: entrant, answer: answer, problem: snapshot.problem, scoring: live.scoringPolicy)
    }
    var body: some View {
        BattlefieldSheet(
            title: selection.problem.number + " · " + selection.entrant.entrant.preset.model.displayName,
            layout: .answer
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    let status: ProblemAnswerStatus =
                        selection.answer.attempts.last.map(providerFailed) == true
                        ? .error
                        : (selection.answer.attempts.last?.finishReason == "length"
                            ? .burnout : selection.answer.status)
                    Pill(text: status.title, color: status.color)
                    Text(L10n.text(selection.problem.title)).font(.title2.bold())
                    Text(
                        "\(selection.problem.byteLimit) bytes · \(battlefieldScore(selection.scoring.score(selection.answer, problem: selection.problem))) points"
                    ).font(
                        .caption.monospaced())
                    if selection.answer.attempts.isEmpty {
                        if selection.answer.status == .burnout {
                            BattlefieldNotice(text: L10n.text("Burnout：此题剩余额度不足以发送提示词，已跳过后续请求。"))
                        } else {
                            Text("尚未作答").foregroundStyle(Palette.muted)
                        }
                    }
                    ForEach(selection.answer.attempts) { attempt in
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(L10n.text("第 %ld 次尝试", attempt.id)).font(.headline)
                                Spacer(minLength: 8)
                                BattlefieldAttemptTime(attempt: attempt)
                            }
                            if attempt.finishedAt == nil {
                                HStack(spacing: 8) {
                                    ProgressView().controlSize(.small)
                                    Text(
                                        L10n.text(
                                            !attempt.response.isEmpty
                                                ? "正在生成回答…"
                                                : (attempt.reasoning?.content.isEmpty == false ? "正在思考…" : "正在等待服务商…")
                                        )
                                    )
                                }.foregroundStyle(Palette.mint)
                                    .accessibilityIdentifier("answer-phase-\(attempt.id)")
                            } else if attempt.error != nil || providerFailed(attempt) {
                                BattlefieldNotice(text: L10n.text("请求已结束。下方是中断前收到的部分内容，这些文字不代表仍在生成。"))
                                    .accessibilityIdentifier("answer-interrupted-\(attempt.id)")
                            } else if attempt.evaluation == nil && selection.answer.status == .cancelled {
                                BattlefieldNotice(text: L10n.text("请求已停止，已收到的部分内容已保留。"))
                            }
                            Text(
                                (attempt.usage.estimated || attempt.usage.partial ? "≈ " : "")
                                    + "\(attempt.usage.input) input / \(attempt.usage.output) output tokens"
                            )
                            .font(.caption.monospaced()).foregroundStyle(Palette.muted)
                            Text(
                                "max output: \(attempt.requestedMaxOutputTokens.map { $0.formatted() } ?? L10n.text("服务商决定")) · finish: \(attempt.finishReason ?? "—")"
                            )
                            .font(.caption.monospaced())
                            if attempt.finishReason == "length" {
                                BattlefieldNotice(text: L10n.text("Burnout：已达到输出上限（包含推理），不再重试此题。已收到的内容已保留。"))
                            } else if selection.answer.status == .burnout,
                                attempt.id == selection.answer.attempts.last?.id
                            {
                                BattlefieldNotice(text: L10n.text("Burnout：已用完此题的 Token 预算，不再重试此题。其他题目继续。"))
                            }
                            if let evaluation = attempt.evaluation, !providerFailed(attempt),
                                attempt.finishReason != "length"
                            {
                                Label(
                                    evaluation.accepted ? L10n.text("通过") : L10n.text("未通过"),
                                    systemImage: evaluation.accepted ? "checkmark.circle.fill" : "xmark.circle"
                                )
                                .foregroundStyle(evaluation.accepted ? Palette.mint : Palette.danger)
                                Text(
                                    L10n.text(
                                        "点亮 %ld/%ld · %ld/%ld bytes · %@ 分",
                                        evaluation.litTargets, evaluation.targetCount, evaluation.bytes,
                                        selection.problem.byteLimit,
                                        battlefieldScore(
                                            selection.scoring.score(evaluation, byteLimit: selection.problem.byteLimit))
                                    )
                                )
                                .font(.caption.monospaced())
                                Text(evaluation.feedback).font(.system(.callout, design: .monospaced))
                            }
                            if let error = attempt.error { Text(error).foregroundStyle(Palette.danger) }
                            if providerFailed(attempt), attempt.error == nil {
                                Text(L10n.text("服务商终止了生成（finish_reason: %@）。", attempt.finishReason ?? "error"))
                                    .foregroundStyle(Palette.danger)
                            }
                            if let program = attempt.program, !program.isEmpty {
                                Text("程序").font(.subheadline.bold())
                                Text(program).font(.system(.body, design: .monospaced)).frame(
                                    maxWidth: .infinity, alignment: .leading
                                )
                                .padding(12).background(Palette.paper, in: RoundedRectangle(cornerRadius: 8))
                                Button {
                                    onTry(program)
                                } label: {
                                    Label("在棋盘中试运行", systemImage: "play.rectangle")
                                }.buttonStyle(.borderedProminent)
                                    .accessibilityIdentifier("tryBattlefieldAnswer-\(attempt.id)")
                            }
                            DisclosureGroup(
                                "完整回答",
                                isExpanded: Binding(
                                    get: { !collapsedAttempts.contains(attempt.id) },
                                    set: {
                                        if $0 {
                                            collapsedAttempts.remove(attempt.id)
                                        } else {
                                            collapsedAttempts.insert(attempt.id)
                                        }
                                    }
                                )
                            ) {
                                VStack(alignment: .leading, spacing: 12) {
                                    if let reasoning = attempt.reasoning {
                                        let expanded = expandedReasoning.contains(attempt.id)
                                        Button {
                                            if expanded {
                                                expandedReasoning.remove(attempt.id)
                                            } else {
                                                expandedReasoning.insert(attempt.id)
                                            }
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                                                    .accessibilityHidden(true)
                                                Text("模型推理").font(.subheadline.bold())
                                                Spacer()
                                            }.contentShape(Rectangle()).padding(.vertical, 6)
                                        }.buttonStyle(.plain)
                                            .accessibilityIdentifier("reasoningToggle-\(attempt.id)")
                                            .accessibilityValue(L10n.text(expanded ? "已展开" : "已收起"))
                                        if expanded {
                                            BattlefieldRulesView(
                                                source: reasoning.content.isEmpty
                                                    ? L10n.text("服务商返回了空的推理内容。") : reasoning.content
                                            ).padding(.top, 8)
                                        }
                                    }
                                    Text("最终回答").font(.subheadline.bold())
                                    Text(
                                        attempt.response.isEmpty
                                            ? L10n.text(attempt.finishedAt == nil ? "尚未收到最终回答。" : "本次请求未返回最终回答。")
                                            : attempt.response
                                    )
                                    .accessibilityIdentifier("answer-response-\(attempt.id)")
                                    if let diagnostic = attempt.providerResponse {
                                        Text("服务商错误详情").font(.subheadline.bold())
                                        Text(diagnostic).accessibilityIdentifier("answer-provider-error-\(attempt.id)")
                                    }
                                }.font(.system(.callout, design: .monospaced)).padding(.top, 8)
                            }
                        }.panel()
                    }
                    DisclosureGroup("题目与模型参数快照") {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(BattlefieldPrompt.problem(selection.problem)).font(
                                .system(.caption, design: .monospaced))
                            Text(selection.entrant.entrant.preset.parameters.extraJSON).font(
                                .system(.caption, design: .monospaced))
                            Text("模型输出额度由全局比赛设置决定。")
                            if let legacy = selection.entrant.entrant.preset.parameters.maxOutputTokens {
                                Text("Legacy max output: \(legacy)")
                            }
                            Text(
                                "temperature: \(selection.entrant.entrant.preset.parameters.temperature.map(String.init(describing:)) ?? "default")"
                            )
                            Text(
                                "top_p: \(selection.entrant.entrant.preset.parameters.topP.map(String.init(describing:)) ?? "default")"
                            )
                        }.padding(.top, 8)
                    }
                }.padding(24).textSelection(.enabled)
            }.background(Palette.paper)
        }
    }
}

private struct BattlefieldAttemptTime: View {
    let attempt: AnswerAttempt
    var compact = false

    var body: some View {
        Group {
            if attempt.finishedAt != nil {
                timing(at: .now)
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in timing(at: context.date) }
            }
        }.font(.caption2.monospaced()).foregroundStyle(Palette.muted)
    }

    private func timing(at now: Date) -> some View {
        let duration = battlefieldDuration(attempt.elapsedTime(at: now))
        return Label {
            Text(compact ? duration : L10n.text("用时 %@", duration))
        } icon: {
            Image(systemName: "clock")
        }
        .fixedSize().accessibilityElement(children: .ignore).accessibilityLabel(L10n.text("用时 %@", duration))
        .accessibilityIdentifier(compact ? "attempt-cell-time-\(attempt.id)" : "attempt-time-\(attempt.id)")
    }
}

private struct BattlefieldErrorIndicator: View {
    let message: String
    @State private var expanded = false
    var body: some View {
        Button {
            expanded.toggle()
        } label: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Palette.danger)
        }.buttonStyle(.plain).accessibilityLabel(L10n.text("调用失败"))
            .help(message)
            .popover(isPresented: $expanded) {
                Text(message).font(.callout).foregroundStyle(Palette.danger).textSelection(.enabled)
                    .padding(16).frame(maxWidth: 300)
            }
    }
}
