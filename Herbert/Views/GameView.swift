import HerbertBattlefield
import HerbertCore
import SwiftUI

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

struct GameDestination: View {
    let problem: Problem
    let store: AppStore
    var trialSource: String?

    var body: some View {
        if let model = try? GameModel(problem: problem, store: store, trialSource: trialSource) {
            GameView(model: model)
        } else {
            ContentUnavailableView(
                "关卡数据无效", systemImage: "exclamationmark.triangle",
                description: Text("返回关卡列表后重试。"))
        }
    }
}

struct GameView: View {
    @StateObject private var model: GameModel
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @StateObject private var editor = EditorController()
    @State private var showGuide = false
    @State private var showProblemInfo = false
    @State private var promptCopied = false
    @State private var showBest = false
    @State private var showOriginalBestInfo = false
    @State private var revealedHints = 0

    init(model: GameModel) { _model = StateObject(wrappedValue: model) }

    private var nextProblem: Problem? {
        guard !model.isTrial else { return nil }
        guard let index = store.problems.firstIndex(where: { $0.id == model.problem.id }),
            store.problems.indices.contains(index + 1)
        else { return nil }
        return store.problems[index + 1]
    }

    var body: some View {
        GeometryReader { geometry in
            // Keep narrow portrait layouts stacked when the keyboard reduces their height.
            let compact =
                geometry.size.height < 500 && geometry.size.width >= 560
                && geometry.size.width > geometry.size.height
            let wide = geometry.size.width >= 760 || compact
            ScrollView {
                VStack(alignment: .leading, spacing: compact ? 12 : 20) {
                    heading(compact: compact, width: geometry.size.width)
                    if !compact, !model.isTrial, let lesson = model.problem.lesson { lessonPanel(lesson) }
                    if !compact { stats }
                    if wide {
                        HStack(alignment: .top, spacing: compact ? 12 : 20) {
                            BoardView(model: model, compact: compact)
                                .frame(height: compact ? max(200, min(340, geometry.size.height - 80)) : 520)
                                .frame(maxWidth: .infinity)
                            VStack(spacing: compact ? 10 : 18) {
                                editorPanel(compact: compact)
                                statusPanel
                                controls
                            }
                            .frame(width: min(compact ? 420 : 380, geometry.size.width * (compact ? 0.46 : 0.40)))
                        }
                    } else {
                        BoardView(model: model).frame(height: min(400, max(270, geometry.size.width - 24)))
                        editorPanel(compact: false)
                        statusPanel
                    }
                    if compact { stats }
                    if model.isCompleted { completionPanel }
                    if let error = store.storageMessage {
                        Label(error, systemImage: "externaldrive.badge.exclamationmark")
                            .font(.caption).foregroundStyle(Palette.danger).panel()
                    }
                }.padding(compact ? 12 : wide ? 28 : 20).frame(maxWidth: 1200).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !wide { controls.padding(.horizontal, 20).padding(.vertical, 12).background(.regularMaterial) }
            }
            .background(Palette.paper)
        }
        .navigationTitle("\(model.problem.number)")
        .navigationBarBackButtonHidden(model.isTrial)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if model.isTrial {
                    Button {
                        dismiss()
                    } label: {
                        Label("返回比赛", systemImage: "arrow.left")
                    }.accessibilityIdentifier("backToBattlefield")
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                if !model.isTrial {
                    Button {
                        store.toggleFavorite(model.problem.id)
                    } label: {
                        Image(
                            systemName: store.progress(for: model.problem.id).isFavorite ? "bookmark.fill" : "bookmark")
                    }.accessibilityLabel("收藏关卡")
                }
            }
        }
        .sheet(isPresented: $showGuide) {
            NavigationStack {
                GuideView().toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("完成") { showGuide = false } }
                }
            }
            #if os(macOS)
                .frame(minWidth: 320, idealWidth: 600, minHeight: 480)
            #endif
        }
        .onChange(of: model.source) { _, _ in model.edited() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { model.pause() } }
        .onAppear { if !model.isTrial { store.visit(model.problem.id) } }
        .onDisappear { model.disappear() }
        .sensoryFeedback(.success, trigger: model.isCompleted)
        .sensoryFeedback(.warning, trigger: model.lastEvent == .trap)
    }

    private func heading(compact: Bool, width: CGFloat) -> some View {
        let layout =
            width >= 560
            ? AnyLayout(HStackLayout(spacing: 12))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
        return layout {
            Text(model.problem.displayTitle).font(.system(size: compact ? 18 : 25, weight: .bold, design: .rounded))
                .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("problem-title")
            headingTags(compact: compact)
        }
    }

    private func headingTags(compact: Bool) -> some View {
        HStack(spacing: 8) {
            Button {
                model.pause()
                promptCopied = false
                showProblemInfo = true
            } label: {
                Label(LocalizedStringKey(model.isTrial ? "AI 试运行" : "题目说明"), systemImage: "info.circle")
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Palette.mintLight.opacity(0.7), in: Capsule()).frame(minHeight: 44)
            }
            .accessibilityIdentifier("problem-details")
            .popover(isPresented: $showProblemInfo, arrowEdge: .top) { problemInfo(compact: compact) }
            Button {
                model.pause()
                showGuide = true
            } label: {
                Label("游戏规则", systemImage: "questionmark.circle")
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Palette.mintLight.opacity(0.7), in: Capsule()).frame(minHeight: 44)
            }.accessibilityIdentifier("game-rules")
        }.font(.system(size: 11, weight: .semibold)).buttonStyle(.plain).foregroundStyle(Palette.mint).fixedSize()
    }

    private func problemInfo(compact: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(LocalizedStringKey(model.isTrial ? "AI 试运行" : "题目说明")).font(.headline)
                Spacer()
                Button("完成") { showProblemInfo = false }.accessibilityIdentifier("close-problem-details")
            }.padding(16)
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    let prompt = BattlefieldPrompt.manual(model.problem)
                    #if os(macOS)
                        NSPasteboard.general.clearContents()
                        promptCopied = NSPasteboard.general.setString(prompt, forType: .string)
                    #else
                        UIPasteboard.general.string = prompt
                        promptCopied = true
                    #endif
                } label: {
                    Label(
                        LocalizedStringKey(promptCopied ? "已复制 AI 提示词" : "复制 AI 提示词"),
                        systemImage: promptCopied ? "checkmark" : "doc.on.doc"
                    )
                    .frame(maxWidth: .infinity, minHeight: 32)
                }.buttonStyle(.borderedProminent).accessibilityIdentifier("copy-ai-prompt")
                Text("包含规则、示例与当前棋盘，与 AI Battlefield 使用相同的提示词。")
                    .font(.caption).foregroundStyle(Palette.muted)
            }.padding(16)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Eyebrow(
                        text: L10n.text(
                            model.problem.lesson == nil
                                ? "PROBLEM %@  /  COMMUNITY COLLECTION" : "LESSON %@  /  ORIGINAL COURSE",
                            model.problem.number))
                    Text(model.problem.displayTitle).font(.headline)
                    Text("由 \(model.problem.author) 创作 · 点亮所有目标，试着把代码再缩短一点。")
                        .font(.callout).foregroundStyle(Palette.muted).accessibilityIdentifier("problem-credit")
                    if model.isTrial {
                        Text("AI 答案试运行：可以修改和运行，不会更改个人草稿、最短解或比赛成绩。")
                            .font(.callout).foregroundStyle(Palette.muted).accessibilityIdentifier("trial-explanation")
                    } else if compact, let lesson = model.problem.lesson {
                        lessonPanel(lesson)
                    }
                }.padding(20)
            }
        }.frame(width: 340, height: compact ? 280 : 340)
            #if os(iOS)
                .presentationCompactAdaptation(.popover)
            #endif
    }

    private func lessonPanel(_ lesson: ProblemLesson) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text("第 %ld 章 · %@", lesson.chapter, L10n.text(lesson.chapterTitle)))
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.mint)
            Text(L10n.text(lesson.objective)).font(.system(size: 13)).foregroundStyle(Palette.ink)
                .accessibilityIdentifier("lesson-objective")
            ForEach(Array(lesson.hints.prefix(revealedHints).enumerated()), id: \.offset) { index, hint in
                Text(L10n.text("提示 %ld：%@", index + 1, L10n.text(hint)))
                    .font(.system(size: 12)).foregroundStyle(Palette.muted)
                    .accessibilityIdentifier("lesson-hint-\(index + 1)")
            }
            if revealedHints < lesson.hints.count {
                Button("显示下一条提示") { revealedHints += 1 }
                    .font(.system(size: 12, weight: .medium)).buttonStyle(.plain).foregroundStyle(Palette.mint)
                    .accessibilityIdentifier("reveal-hint")
            }
        }.panel(padding: 16)
    }

    private var stats: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                stat("已点亮", value: "\(model.session.visitedTargets.count) / \(model.session.board.targets.count)")
                Divider().frame(height: 28)
                stat(
                    "代码长度", value: "\(model.bytes) / \(model.problem.byteLimit) B",
                    danger: model.bytes > model.problem.byteLimit, identifier: "game-program-size")
                Divider().frame(height: 28)
                stat("执行步数", value: "\(model.session.steps)")
            }.padding(.vertical, 16)
            if model.problem.lesson == nil {
                Divider().padding(.horizontal, 16)
                Button {
                    showOriginalBestInfo = true
                } label: {
                    HStack(spacing: 8) {
                        Label("原站最短参考", systemImage: "trophy")
                            .foregroundStyle(Palette.muted)
                        Spacer(minLength: 4)
                        Text(originalBestValue)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Palette.mint)
                        Image(systemName: "info.circle").foregroundStyle(Palette.muted)
                    }.font(.system(size: 12)).frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain).padding(.horizontal, 16)
                .accessibilityLabel(L10n.text("原站最短参考") + ": " + originalBestValue)
                .accessibilityIdentifier("original-best-reference")
                .accessibilityHint("查看原站最短参考的说明")
                .popover(isPresented: $showOriginalBestInfo, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("原站最短参考").font(.headline)
                            Spacer()
                            Button("完成") { showOriginalBestInfo = false }
                                .accessibilityIdentifier("close-original-best-info")
                        }
                        Text("这是收录题库时原站 Best 栏的答案长度，不会改变本题的通关长度限制。它与「我的最短解」分别记录，原站之后可能已有更短的答案。")
                            .font(.system(size: 13)).foregroundStyle(Palette.muted).fixedSize(
                                horizontal: false, vertical: true
                            )
                            .accessibilityIdentifier("original-best-explanation")
                        Link("原版 Problems ↗", destination: URL(string: "http://herbert.tealang.info/problems.php")!)
                            .font(.system(size: 13))
                    }.padding(20).frame(width: 340)
                        #if os(iOS)
                            .presentationCompactAdaptation(.sheet)
                            .presentationDetents([.medium])
                            .presentationDragIndicator(.visible)
                        #endif
                }
            }
        }.background(.white, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 1))
    }

    private var originalBestValue: String {
        model.problem.originalBest.map { "\($0) B" } ?? L10n.text("暂无记录")
    }

    private func stat(_ title: String, value: String, danger: Bool = false, identifier: String = "") -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(title)).font(.system(size: 10)).foregroundStyle(Palette.muted)
            Text(value).font(.system(size: 17, weight: .semibold, design: .monospaced))
                .foregroundStyle(danger ? Palette.danger : Palette.ink).contentTransition(.numericText()).lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityIdentifier(identifier)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
    }

    private func editorPanel(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            HStack {
                Eyebrow(text: "YOUR PROGRAM")
                Spacer()
                #if os(iOS)
                    Button("收起键盘") { editor.dismiss() }.font(.system(size: 11)).buttonStyle(.plain)
                #endif
                Pill(text: "H LANGUAGE")
            }
            ZStack(alignment: .topLeading) {
                if model.source.isEmpty {
                    Text("在这里写下你的思路…\n\n试试 s 前进、l 左转、r 右转")
                        .font(.system(size: 15, design: .monospaced)).foregroundStyle(Palette.muted.opacity(0.65))
                        .padding(.top, 14).padding(.leading, 12).allowsHitTesting(false)
                }
                CodeEditor(text: $model.source, controller: editor)
                    .frame(
                        minHeight: compact ? 60 : 140, idealHeight: compact ? 80 : 180, maxHeight: compact ? 100 : 240)
            }.background(Palette.paper.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
            HStack(spacing: 8) {
                commandKey("s", label: "前进", insertion: "s")
                commandKey("l", label: "左转", insertion: "l")
                commandKey("r", label: "右转", insertion: "r")
                Menu {
                    ForEach(["a", "X", "(", ")", ",", ":", "+", "-", "1", "2", "3", "4", "\n"], id: \.self) { text in
                        Button(LocalizedStringKey(text == "\n" ? "换行" : text)) { editor.insert(text) }
                    }
                    Divider()
                    Button("过程模板 a(X):…") { editor.insert("a(X):sa(X-1)\na(4)") }
                } label: {
                    Image(systemName: "ellipsis").frame(width: 40, height: 44).background(
                        Palette.paper, in: RoundedRectangle(cornerRadius: 10))
                }
                .menuStyle(.borderlessButton).accessibilityLabel("更多代码符号")
            }
            if !compact || (!model.isTrial && store.progress(for: model.problem.id).bestSolution != nil) {
                HStack {
                    if !compact {
                        Text("字母和数值各算 1 byte，标点不计。")
                            .font(.system(size: 10)).foregroundStyle(Palette.muted)
                    }
                    Spacer(minLength: 0)
                    if !model.isTrial, store.progress(for: model.problem.id).bestSolution != nil {
                        Button {
                            showBest.toggle()
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        .buttonStyle(.plain).accessibilityLabel("查看我的最短解")
                    }
                }
            }
            if showBest, let best = store.progress(for: model.problem.id).bestSolution {
                VStack(alignment: .leading, spacing: 10) {
                    Text("我的最短解").font(.caption).foregroundStyle(Palette.muted)
                    Text(best).font(.system(size: 15, design: .monospaced)).textSelection(.enabled)
                    Button("载入最短解") {
                        model.source = best
                        showBest = false
                    }
                    .font(.caption).buttonStyle(.bordered)
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(
                    Palette.mintLight, in: RoundedRectangle(cornerRadius: 12))
            }
        }.panel(padding: compact ? 12 : 18)
    }

    private func commandKey(_ key: String, label: String, insertion: String) -> some View {
        Button {
            editor.insert(insertion)
        } label: {
            HStack(spacing: 6) {
                Text(key).font(.system(size: 17, weight: .bold, design: .monospaced))
                Text(LocalizedStringKey(label)).font(.system(size: 10))
            }.frame(maxWidth: .infinity).frame(height: 44)
                .foregroundStyle(Palette.mint).background(
                    Palette.mintLight.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain).accessibilityLabel(L10n.text("插入 %@ %@", key, L10n.text(label)))
            .accessibilityIdentifier("insert-\(key)")
    }

    private var statusPanel: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: model.message == nil ? "terminal" : "exclamationmark.circle")
            Text(model.message ?? statusText).lineSpacing(3)
                .accessibilityIdentifier("game-status")
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

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    editor.dismiss()
                    model.toggleRun()
                } label: {
                    Label(
                        LocalizedStringKey(model.isRunning ? "暂停" : model.isCompleted ? "再运行" : "运行"),
                        systemImage: model.isRunning ? "pause.fill" : "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.return, modifiers: .command)
                .accessibilityIdentifier("run-program")
                Button {
                    editor.dismiss()
                    model.step()
                } label: {
                    Image(systemName: "forward.end.fill").frame(width: 48, height: 48)
                }
                .buttonStyle(.plain).background(.white, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1))
                .accessibilityLabel("单步执行").accessibilityIdentifier("step-program")
                Button {
                    model.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise").frame(width: 48, height: 48)
                }
                .buttonStyle(.plain).background(.white, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1))
                .accessibilityLabel("重置棋盘").accessibilityIdentifier("reset-program")
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

    private var completionPanel: some View {
        HStack(spacing: 18) {
            Image(systemName: "sparkles").font(.system(size: 30)).foregroundStyle(Palette.mint)
            VStack(alignment: .leading, spacing: 6) {
                Text("漂亮，全部点亮！").font(.system(size: 20, weight: .bold)).accessibilityIdentifier("completion-title")
                Text(
                    !model.session.isAccepted
                        ? L10n.text("%ld byte · 超过长度限制，仅供试运行，未保存为解答", model.session.programBytes)
                        : model.isTrial
                            ? L10n.text("%ld byte · AI 答案试运行完成", model.session.programBytes)
                            : L10n.text("%ld byte · 最短解已保存到本机", model.session.programBytes)
                )
                .font(.system(size: 12)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
            if let next = nextProblem {
                NavigationLink(value: next) {
                    Image(systemName: "arrow.right").font(.system(size: 20)).frame(width: 48, height: 48)
                }
                .buttonStyle(.plain).foregroundStyle(.white).background(
                    Palette.mint, in: RoundedRectangle(cornerRadius: 14)
                )
                .accessibilityLabel("下一关").accessibilityIdentifier("next-problem")
            }
        }.padding(20).background(Palette.mintLight, in: RoundedRectangle(cornerRadius: 20))
    }
}
