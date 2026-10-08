import HerbertBattlefield
import HerbertCore
import SwiftUI

private struct BattlefieldAnswerSelection: Identifiable {
    let entrant: EntrantResult
    let answer: ProblemAnswer
    let problem: Problem
    var id: String { "\(entrant.id)/\(answer.id)" }
}

struct BattlefieldDashboard: View {
    @EnvironmentObject private var battlefield: BattlefieldModel
    let result: CompetitionResult
    @State private var selectedAnswer: BattlefieldAnswerSelection?
    @State private var sharing = false
    @State private var inspecting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            HStack {
                Text("实时排名").font(.title2.bold())
                Spacer()
                Text("100 / PROBLEM").font(.caption.monospaced()).foregroundStyle(Palette.muted)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 270), spacing: 16)], spacing: 16) {
                ForEach(Array(result.ranked.enumerated()), id: \.element.id) { index, entrant in
                    rankCard(entrant, rank: index + 1)
                }
            }
            if result.entrants.contains(where: \.hasEstimatedUsage) {
                BattlefieldNotice(text: L10n.text("≈ 表示包含实时估算或取消请求的部分用量。缓存率仅在全部尝试均返回准确缓存用量时显示。最终账单以服务商为准。"))
            }
            VStack(alignment: .leading, spacing: 16) {
                Text("逐题进度").font(.title2.bold())
                Text("点击状态查看程序、反馈与重试记录。")
                    .font(.caption).foregroundStyle(Palette.muted)
                ScrollView(.horizontal) {
                    Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                        GridRow {
                            Text("题目").frame(width: 64, alignment: .leading)
                            ForEach(result.ranked) { entrant in
                                Text(entrant.entrant.preset.model.name).font(.caption.bold()).lineLimit(2)
                                    .frame(width: 115, height: 44).help(
                                        entrant.entrant.providerName + " / " + entrant.entrant.preset.model.id)
                            }
                        }
                        ForEach(result.problems) { problem in
                            GridRow {
                                Text(battlefieldProblemID(problem.id)).font(.system(.callout, design: .monospaced))
                                    .frame(width: 64, alignment: .leading)
                                ForEach(result.ranked) { entrant in
                                    if let answer = entrant.answers.first(where: { $0.id == problem.id }) {
                                        Button {
                                            selectedAnswer = BattlefieldAnswerSelection(
                                                entrant: entrant, answer: answer, problem: problem)
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: answer.status.symbol)
                                                Text(answer.status.title).font(.caption)
                                            }.frame(width: 115, height: 34)
                                                .foregroundStyle(answer.status.color)
                                                .background(
                                                    answer.status.color.opacity(0.08),
                                                    in: RoundedRectangle(cornerRadius: 8))
                                        }.buttonStyle(.plain)
                                            .accessibilityIdentifier(
                                                "answer-\(entrant.entrant.preset.model.id)-\(problem.id)"
                                            )
                                            .accessibilityLabel(
                                                battlefieldProblemID(problem.id) + " "
                                                    + entrant.entrant.preset.model.name + " " + answer.status.title)
                                    }
                                }
                            }
                        }
                    }
                }
            }.panel()
        }
        .sheet(item: $selectedAnswer) { selection in
            BattlefieldAnswerView(selection: selection)
        }.sheet(isPresented: $sharing) { BattlefieldShareView(result: result) }
        .sheet(isPresented: $inspecting) {
            BattlefieldSheet(title: L10n.text("比赛配置与提示词")) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(result.id.uuidString).font(.caption.monospaced())
                        Text(L10n.text("每题最多 %ld 次机会", result.configuration.attemptsPerProblem))
                        Text("模式：") + Text(result.configuration.mode.title)
                        Text("时限（秒）：") + Text(result.configuration.timeLimitSeconds.formatted())
                        Text("Token 总预算：") + Text(result.configuration.tokenLimit.formatted())
                        Text(
                            result.configuration.tokenBudgetScope == .shared ? L10n.text("全场共享") : L10n.text("每个 AI 独立")
                        )
                        Text(result.systemPrompt).font(.system(.callout, design: .monospaced))
                    }.textSelection(.enabled).padding(24)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            Eyebrow(text: "AI BATTLEFIELD / LIVE RESULTS")
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
                Pill(text: result.configuration.mode.title)
                Text(L10n.text("%ld 个 AI · %ld 道题", result.entrants.count, result.problems.count))
                    .font(.callout).foregroundStyle(Palette.muted)
            }
            Text(result.startedAt, format: .dateTime.year().month().day().hour().minute()).font(.caption)
                .foregroundStyle(Palette.muted)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = max(0, (result.finishedAt ?? context.date).timeIntervalSince(result.startedAt))
                HStack(spacing: 16) {
                    Label(duration(elapsed), systemImage: "clock")
                    if result.configuration.mode == .timed {
                        Text(L10n.text("时限 %@", duration(result.configuration.timeLimitSeconds)))
                    }
                    Label(result.totalTokens.formatted() + " tokens", systemImage: "sparkles")
                }.font(.caption.monospaced()).foregroundStyle(Palette.muted)
            }
            if result.configuration.mode == .tokenLimited {
                Text(
                    (result.configuration.tokenBudgetScope == .shared ? L10n.text("全场共享") : L10n.text("每个 AI 独立"))
                        + " · " + result.configuration.tokenLimit.formatted() + " tokens"
                )
                .font(.caption).foregroundStyle(Palette.muted)
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

    private func rankCard(_ entrant: EntrantResult, rank: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text(String(format: "%02d", rank)).font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(rank == 1 ? Palette.mint : Palette.muted)
                Spacer()
                Text(entrant.score.formatted()).font(.system(size: 34, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("score-\(entrant.entrant.preset.model.id)")
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(entrant.entrant.preset.model.name).font(.headline).lineLimit(2)
                Text(entrant.entrant.providerName).font(.caption).foregroundStyle(Palette.muted)
            }
            Divider()
            metric(L10n.text("已通过"), "\(entrant.solved) / \(result.problems.count)")
            metric(L10n.text("代码总 byte"), entrant.bytes.formatted())
            metric(
                L10n.text("输入 / 输出 Token"),
                (entrant.hasEstimatedUsage ? "≈ " : "")
                    + "\(entrant.inputTokens.formatted()) / \(entrant.outputTokens.formatted())")
            metric(L10n.text("已确认 Token"), entrant.confirmedTokens.formatted())
            metric(L10n.text("输入缓存率"), battlefieldCache(entrant))
            if entrant.exhaustedBudget { Pill(text: L10n.text("Token 预算用完"), color: Palette.amber) }
            if let error = entrant.error {
                Text(error).font(.caption).foregroundStyle(Palette.danger).textSelection(.enabled)
            }
        }.panel()
    }

    private func metric(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name).foregroundStyle(Palette.muted)
            Spacer(minLength: 4)
            Text(value).monospacedDigit()
        }.font(.caption)
    }

    private func duration(_ seconds: Double) -> String {
        let seconds = Int(seconds)
        return String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
    }
}

private struct BattlefieldAnswerView: View {
    let selection: BattlefieldAnswerSelection
    var body: some View {
        BattlefieldSheet(
            title: battlefieldProblemID(selection.problem.id) + " · " + selection.entrant.entrant.preset.model.name
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Pill(text: selection.answer.status.title, color: selection.answer.status.color)
                    Text(L10n.text(selection.problem.title)).font(.title2.bold())
                    Text("\(selection.problem.byteLimit) bytes · \(selection.answer.score) points").font(
                        .caption.monospaced())
                    if selection.answer.attempts.isEmpty { Text("尚未作答").foregroundStyle(Palette.muted) }
                    ForEach(selection.answer.attempts) { attempt in
                        VStack(alignment: .leading, spacing: 14) {
                            Text(L10n.text("第 %ld 次尝试", attempt.id)).font(.headline)
                            Text(
                                (attempt.usage.estimated || attempt.usage.partial ? "≈ " : "")
                                    + "\(attempt.usage.input) input / \(attempt.usage.output) output tokens"
                            )
                            .font(.caption.monospaced()).foregroundStyle(Palette.muted)
                            if let cap = attempt.requestedMaxOutputTokens {
                                Text("max output: \(cap) · finish: \(attempt.finishReason ?? "—")").font(
                                    .caption.monospaced())
                            }
                            if let evaluation = attempt.evaluation {
                                Label(
                                    evaluation.accepted ? L10n.text("通过") : L10n.text("未通过"),
                                    systemImage: evaluation.accepted ? "checkmark.circle.fill" : "xmark.circle"
                                )
                                .foregroundStyle(evaluation.accepted ? Palette.mint : Palette.danger)
                                Text(evaluation.feedback).font(.system(.callout, design: .monospaced))
                            }
                            if let error = attempt.error { Text(error).foregroundStyle(Palette.danger) }
                            if let program = attempt.program {
                                Text("程序").font(.subheadline.bold())
                                Text(program).font(.system(.body, design: .monospaced)).frame(
                                    maxWidth: .infinity, alignment: .leading
                                )
                                .padding(12).background(Palette.paper, in: RoundedRectangle(cornerRadius: 8))
                            }
                            DisclosureGroup("完整回答") {
                                Text(attempt.response).font(.system(.callout, design: .monospaced)).padding(.top, 8)
                            }
                        }.panel()
                    }
                    DisclosureGroup("题目与模型参数快照") {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(BattlefieldPrompt.problem(selection.problem)).font(
                                .system(.caption, design: .monospaced))
                            Text(selection.entrant.entrant.preset.parameters.extraJSON).font(
                                .system(.caption, design: .monospaced))
                            Text("max output: \(selection.entrant.entrant.preset.parameters.maxOutputTokens)")
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
