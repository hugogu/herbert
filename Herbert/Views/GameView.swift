import HerbertCore
import SwiftUI

struct GameDestination: View {
    let problem: Problem
    let store: AppStore

    var body: some View {
        if let model = try? GameModel(problem: problem, store: store) {
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
    @StateObject private var editor = EditorController()
    @State private var showGuide = false
    @State private var showBest = false

    init(model: GameModel) { _model = StateObject(wrappedValue: model) }

    private var nextProblem: Problem? { store.problems.first { $0.id > model.problem.id } }

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 760
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heading
                    stats
                    if wide {
                        HStack(alignment: .top, spacing: 20) {
                            BoardView(model: model).frame(minHeight: 470, idealHeight: 520, maxHeight: 560)
                                .frame(maxWidth: .infinity)
                            VStack(spacing: 18) {
                                editorPanel
                                statusPanel
                                controls
                            }
                            .frame(width: min(380, geometry.size.width * 0.40))
                        }
                    } else {
                        BoardView(model: model).frame(height: min(400, max(270, geometry.size.width - 24)))
                        editorPanel
                        statusPanel
                    }
                    if model.isCompleted { completionPanel }
                    if let error = store.storageMessage {
                        Label(error, systemImage: "externaldrive.badge.exclamationmark")
                            .font(.caption).foregroundStyle(Palette.danger).panel()
                    }
                }.padding(wide ? 28 : 20).frame(maxWidth: 1200).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !wide { controls.padding(.horizontal, 20).padding(.vertical, 12).background(.regularMaterial) }
            }
            .background(Palette.paper)
        }
        .navigationTitle("\(model.problem.number)")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    store.toggleFavorite(model.problem.id)
                } label: {
                    Image(systemName: store.progress(for: model.problem.id).isFavorite ? "bookmark.fill" : "bookmark")
                }.accessibilityLabel("收藏关卡")
                Button {
                    model.pause()
                    showGuide = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .accessibilityLabel("游戏规则")
            }
        }
        .sheet(isPresented: $showGuide) {
            NavigationStack {
                GuideView().toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("完成") { showGuide = false } }
                }
            }.frame(minWidth: 320, idealWidth: 600, minHeight: 480)
        }
        .onChange(of: model.source) { _, _ in model.edited() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { model.pause() } }
        .onAppear { store.visit(model.problem.id) }
        .onDisappear { model.disappear() }
        .sensoryFeedback(.success, trigger: model.isCompleted)
        .sensoryFeedback(.warning, trigger: model.lastEvent == .trap)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: L10n.text("PROBLEM %@  /  ORIGINAL COLLECTION", model.problem.number))
            Text(model.problem.title).font(.system(size: 25, weight: .bold, design: .rounded))
            Text("由 \(model.problem.author) 创作 · 点亮所有目标，试着把代码再缩短一点。")
                .font(.system(size: 12)).foregroundStyle(Palette.muted)
        }
    }

    private var stats: some View {
        HStack(spacing: 0) {
            stat("已点亮", value: "\(model.session.visitedTargets.count) / \(model.session.board.targets.count)")
            Divider().frame(height: 28)
            stat(
                "代码长度", value: "\(model.bytes) / \(model.problem.byteLimit) B",
                danger: model.bytes > model.problem.byteLimit)
            Divider().frame(height: 28)
            stat("执行步数", value: "\(model.session.steps)")
        }.padding(.vertical, 16).background(.white, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 1))
    }

    private func stat(_ title: String, value: String, danger: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(title)).font(.system(size: 10)).foregroundStyle(Palette.muted)
            Text(value).font(.system(size: 17, weight: .semibold, design: .monospaced))
                .foregroundStyle(danger ? Palette.danger : Palette.ink).contentTransition(.numericText()).lineLimit(1)
                .minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
    }

    private var editorPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    .frame(minHeight: 140, idealHeight: 180, maxHeight: 240)
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
            HStack {
                Text("字母和数值各算 1 byte，标点不计。")
                    .font(.system(size: 10)).foregroundStyle(Palette.muted)
                Spacer(minLength: 0)
                if store.progress(for: model.problem.id).bestSolution != nil {
                    Button {
                        showBest.toggle()
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .buttonStyle(.plain).accessibilityLabel("查看我的最短解")
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
        }.panel(padding: 18)
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
                Text("\(model.session.programBytes) byte · 最短解已保存到本机")
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
