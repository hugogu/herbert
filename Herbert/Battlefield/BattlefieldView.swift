import HerbertBattlefield
import HerbertCore
import SwiftUI

private enum BattlefieldPage: String, CaseIterable {
    case providers = "AI 配置"
    case setup = "新比赛"
    case current = "当前比赛"
    case history = "比赛历史"

    var shortTitle: String {
        switch self {
        case .providers: "模型"
        case .setup: "新赛"
        case .current: "实况"
        case .history: "历史"
        }
    }
    var symbol: String {
        switch self {
        case .providers: "cpu"
        case .setup: "plus.circle"
        case .current: "flag.checkered"
        case .history: "clock.arrow.circlepath"
        }
    }
}

struct BattlefieldView: View {
    @EnvironmentObject private var battlefield: BattlefieldModel
    @State private var page = BattlefieldPage.setup
    @State private var historyResult: CompetitionResult?

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if page == .providers {
                    AIProvidersView()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            BattlefieldMessages()
                            switch page {
                            case .providers: EmptyView()
                            case .setup: BattlefieldSetupView(wide: geometry.size.width >= 800)
                            case .current:
                                if let result = battlefield.liveResult {
                                    BattlefieldDashboard(result: result)
                                } else {
                                    ContentUnavailableView(
                                        L10n.text("等待开赛"), systemImage: "flag.checkered",
                                        description: Text("选择模型和题目，开始第一场比赛。"))
                                }
                            case .history: history
                            }
                        }.padding(28).frame(maxWidth: page == .setup ? 1200 : .infinity, alignment: .leading).frame(
                            maxWidth: .infinity)
                    }
                }
            }
        }.background(Palette.paper).navigationTitle("AI Battlefield")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    #if os(iOS)
                        HStack(spacing: 2) {
                            ForEach(BattlefieldPage.allCases, id: \.self) { item in
                                Button {
                                    page = item
                                } label: {
                                    VStack(spacing: 3) {
                                        Image(systemName: item.symbol).font(.callout)
                                        Text(LocalizedStringKey(item.shortTitle)).font(.caption2.weight(.semibold))
                                    }.frame(minWidth: 54).padding(.vertical, 5)
                                        .foregroundStyle(page == item ? Palette.mint : Palette.muted)
                                        .background(
                                            page == item ? Palette.mintLight : .clear,
                                            in: RoundedRectangle(cornerRadius: 8))
                                }.buttonStyle(.plain)
                                    .accessibilityLabel(L10n.text(item.rawValue))
                                    .accessibilityAddTraits(page == item ? .isSelected : [])
                            }
                        }
                    #else
                        Picker("AI Battlefield", selection: $page) {
                            ForEach(BattlefieldPage.allCases, id: \.self) {
                                Text(LocalizedStringKey($0.rawValue)).tag($0)
                            }
                        }.pickerStyle(.segmented).labelsHidden()
                            .frame(width: 520)
                    #endif
                }
            }
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .onChange(of: battlefield.busy) { _, busy in if busy { page = .current } }
            .sheet(item: $historyResult) { result in
                BattlefieldSheet(title: L10n.text("比赛历史"), layout: .history) {
                    ScrollView { BattlefieldDashboard(result: result).padding(24) }
                        .background(Palette.paper)
                }
            }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("比赛历史").font(.largeTitle.bold())
            Text("每次比赛的题目、提示词、模型参数、回答和判分都会保存在本机。")
                .foregroundStyle(Palette.muted)
            if battlefield.history.isEmpty {
                ContentUnavailableView(L10n.text("暂无比赛记录"), systemImage: "clock.arrow.circlepath")
            }
            ForEach(battlefield.history) { summary in
                Button {
                    Task { historyResult = await battlefield.loadResult(summary.id) }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "flag.checkered").font(.title2).foregroundStyle(Palette.mint)
                        VStack(alignment: .leading, spacing: 7) {
                            Text(summary.startedAt, format: .dateTime.year().month().day().hour().minute()).font(
                                .headline)
                            Text(summary.status.title).font(.caption).foregroundStyle(
                                Palette.muted)
                            Text(
                                L10n.text(
                                    "%ld 个 AI · %ld 道题 · 最高 %@", summary.entrantCount,
                                    summary.problemCount, battlefieldPercentage(summary.topScoreFraction))
                            ).font(.caption)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Palette.muted)
                    }.foregroundStyle(Palette.ink).panel()
                }.buttonStyle(.plain).accessibilityIdentifier("history-\(summary.id)")
            }
        }
    }
}

private struct BattlefieldSetupView: View {
    @EnvironmentObject private var battlefield: BattlefieldModel
    @EnvironmentObject private var store: AppStore
    @State private var configuration = CompetitionConfiguration()
    @State private var selectedModels = Set<String>()
    @State private var selectedProblems = Set<Int>()
    @State private var choosingProblems = false
    @State private var choosingModels = false
    @State private var showingPrompt = false
    @State private var initialized = false
    @State private var editingModel: BattlefieldModelOption?
    let wide: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "SAME PUZZLES. DIFFERENT MINDS.")
                Text("相同规则，同场解题。让程序运行结果说话。")
                    .font(.title3).foregroundStyle(Palette.muted)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("比赛设置").font(.title2.bold())
                Toggle("限制比赛时间", isOn: $configuration.timeLimitEnabled)
                    .accessibilityIdentifier("matchTimeLimitEnabled")
                if configuration.timeLimitEnabled {
                    HStack {
                        Text("时限（秒）")
                        Spacer()
                        TextField("时限（秒）", value: $configuration.timeLimitSeconds, format: .number)
                            .textFieldStyle(.roundedBorder).frame(width: 120)
                            .accessibilityIdentifier("matchTimeLimit")
                    }
                }
                Toggle("限制每题 Token 用量", isOn: $configuration.problemTokenLimitEnabled)
                    .accessibilityIdentifier("problemTokenLimitEnabled")
                if configuration.problemTokenLimitEnabled {
                    HStack {
                        Text("每模型每题 Token 上限")
                        Spacer()
                        TextField("每模型每题 Token 上限", value: $configuration.problemTokenLimit, format: .number)
                            .textFieldStyle(.roundedBorder).frame(width: 150)
                            .accessibilityIdentifier("problemTokenLimit")
                    }
                }
                Text("所有模型使用相同的每题预算，累计该题所有尝试的输入与输出（含推理）。不限用量时使用服务商声明的最大输出能力；能力未知时由服务商决定。")
                    .font(.caption).foregroundStyle(Palette.muted)
                Stepper(value: $configuration.attemptsPerProblem, in: 1...10) {
                    Text(L10n.text("每题最多 %ld 次机会", configuration.attemptsPerProblem))
                }.accessibilityIdentifier("attemptLimit")
            }.panel()
            if wide {
                HStack(alignment: .top, spacing: 20) {
                    entrantsPanel.frame(maxWidth: .infinity)
                    puzzlesPanel.frame(maxWidth: .infinity)
                }
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    entrantsPanel
                    puzzlesPanel
                }
            }
            BattlefieldNotice(text: L10n.text("点击开始后，将向所选服务商发送规则、题目和本次对话。服务商可能保存请求并按其价格收费，请确认你同意这些数据发送和费用。"))
            #if os(iOS)
                Text("进入后台会终止比赛并保存结果。请保持 App 在前台。")
                    .font(.caption).foregroundStyle(Palette.muted)
            #endif
            Button {
                battlefield.start(
                    configuration: configuration, selected: selectedModels,
                    problems: store.problems.filter { selectedProblems.contains($0.id) })
            } label: {
                Label("同意并开始比赛", systemImage: "flag.checkered")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(
                battlefield.busy || battlefield.initializing || selectedModels.isEmpty || selectedModels.count > 32
                    || selectedProblems.isEmpty
            )
            .opacity(battlefield.busy || selectedModels.isEmpty || selectedProblems.isEmpty ? 0.5 : 1)
            .accessibilityIdentifier("startBattlefield")
        }.onAppear {
            if !initialized {
                initialized = true
                configuration = battlefield.settings.competition.forNewMatch()
                selectedModels = Set(battlefield.modelOptions.filter(\.isDefault).map(\.id))
                selectedProblems = Set(store.problems.filter { $0.lesson != nil }.map(\.id))
            }
        }
        .sheet(isPresented: $choosingProblems) {
            BattlefieldProblemPicker(selected: $selectedProblems)
        }.sheet(isPresented: $choosingModels) {
            BattlefieldModelPicker(selected: $selectedModels)
        }.sheet(item: $editingModel) { option in
            AIModelEditor(providerID: option.provider.id, preset: option.preset)
        }.sheet(isPresented: $showingPrompt) {
            BattlefieldSheet(title: L10n.text("统一规则提示词")) {
                ScrollView {
                    BattlefieldRulesView(source: BattlefieldPrompt.rules).padding(24)
                }
            }
        }
    }

    private var entrantsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("参赛模型").font(.title2.bold())
                Spacer()
                Text("\(selectedModels.count) / 32").font(.caption.monospaced()).foregroundStyle(Palette.muted)
                Button("选择参赛模型") { choosingModels = true }.accessibilityIdentifier("chooseBattlefieldModels")
            }
            if battlefield.modelOptions.isEmpty {
                BattlefieldNotice(text: L10n.text("先在 AI 配置中添加服务商并检测模型。"))
            }
            ForEach(battlefield.modelOptions.filter { selectedModels.contains($0.id) }) { option in
                HStack {
                    Toggle(
                        isOn: Binding(
                            get: { selectedModels.contains(option.id) },
                            set: { on in
                                if on { selectedModels.insert(option.id) } else { selectedModels.remove(option.id) }
                            })
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.preset.model.displayName).font(.headline)
                            Text(option.provider.name)
                                .font(.caption).foregroundStyle(Palette.muted)
                        }
                    }.disabled(battlefield.busy).accessibilityIdentifier("entrant-\(option.preset.model.id)")
                    Button {
                        editingModel = option
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }.accessibilityLabel(L10n.text("模型参数"))
                        .accessibilityIdentifier("entrantParameters-\(option.preset.model.id)")
                        .disabled(battlefield.busy)
                }
            }
        }.panel()
    }

    private var puzzlesPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("比赛题目").font(.title2.bold())
                Spacer()
                Button {
                    choosingProblems = true
                } label: {
                    Label(
                        L10n.text("已选择 %ld 道", selectedProblems.count),
                        systemImage: "square.grid.2x2")
                }.accessibilityIdentifier("chooseBattlefieldProblems")
            }
            Text("默认使用 30 道原创题目，按题号顺序解答。各个 AI 并行比赛，每个 AI 逐题作答。")
                .font(.callout).foregroundStyle(Palette.muted)
            Divider()
            Text("每题按点亮目标比例与代码长度计分，取各次尝试的最高分。同分时 Token 消耗更少者在前。错误答案会收到反馈后重试。")
                .font(.callout).foregroundStyle(Palette.muted)
            Button("查看统一规则提示词") { showingPrompt = true }
            DisclosureGroup("附加提示词（所有 AI 相同）") {
                TextEditor(text: $configuration.extraPrompt).font(.system(.body, design: .monospaced))
                    .frame(minHeight: 90).padding(.top, 8)
            }
        }.panel()
    }
}

private struct BattlefieldModelPicker: View {
    @EnvironmentObject private var battlefield: BattlefieldModel
    @Binding var selected: Set<String>
    @State private var search = ""
    var body: some View {
        BattlefieldSheet(title: L10n.text("参赛模型")) {
            VStack {
                HStack {
                    Button("使用默认参赛模型") { selected = Set(battlefield.modelOptions.filter(\.isDefault).map(\.id)) }
                    Spacer()
                    Text("\(selected.count) / 32").monospacedDigit()
                }.padding(.horizontal)
                List(
                    battlefield.modelOptions.filter {
                        search.isEmpty || $0.preset.model.displayName.localizedCaseInsensitiveContains(search)
                            || $0.preset.model.id.localizedCaseInsensitiveContains(search)
                            || $0.provider.name.localizedCaseInsensitiveContains(search)
                    }
                ) { option in
                    Toggle(
                        isOn: Binding(
                            get: { selected.contains(option.id) },
                            set: { on in
                                if on { selected.insert(option.id) } else { selected.remove(option.id) }
                            })
                    ) {
                        VStack(alignment: .leading) {
                            Text(option.preset.model.displayName).font(.headline)
                            Text(option.provider.name + " / " + option.preset.model.id).font(.caption).foregroundStyle(
                                Palette.muted)
                        }
                    }.disabled(!selected.contains(option.id) && selected.count >= 32)
                }.searchable(text: $search, prompt: L10n.text("搜索模型"))
            }
        }
    }
}

private enum BattlefieldPuzzleSource: String, CaseIterable {
    case originals = "原创课程"
    case community = "社区题库"
    case selected = "已选题目"
}

private struct BattlefieldProblemPicker: View {
    @EnvironmentObject private var store: AppStore
    @Binding var selected: Set<Int>
    @State private var search = ""
    @State private var source = BattlefieldPuzzleSource.originals

    private var sources: [BattlefieldPuzzleSource] {
        store.problems.contains { $0.lesson == nil } ? [.originals, .community, .selected] : [.originals, .selected]
    }
    private var filtered: [Problem] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.problems.filter { problem in
            let included: Bool
            switch source {
            case .originals: included = problem.lesson != nil
            case .community: included = problem.lesson == nil
            case .selected: included = selected.contains(problem.id)
            }
            return included
                && (query.isEmpty
                    || "\(problem.number) \(problem.displayTitle) \(problem.title) \(problem.author)"
                        .localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        BattlefieldSheet(title: L10n.text("比赛题目"), layout: .puzzles) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                        TextField("搜索编号、名称或作者", text: $search).textFieldStyle(.plain)
                            .accessibilityIdentifier("battlefieldPuzzleSearch")
                        if !search.isEmpty {
                            Button {
                                search = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain).foregroundStyle(Palette.muted)
                            .accessibilityLabel("清除搜索")
                        }
                    }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))
                    Picker("题库", selection: $source) {
                        ForEach(sources, id: \.self) { item in
                            Text(LocalizedStringKey(item.rawValue)).tag(item)
                        }
                    }.pickerStyle(.segmented).labelsHidden()
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            selectionCount
                            Spacer()
                            selectionActions
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            selectionCount
                            selectionActions
                        }
                    }
                }.padding(20).background(Palette.paper)
                Divider()
                if filtered.isEmpty {
                    ContentUnavailableView(
                        L10n.text("这里还没有关卡"), systemImage: "magnifyingglass",
                        description: Text("试试其他筛选，或搜索关卡编号。"))
                } else {
                    List {
                        if source == .originals {
                            ForEach(Array(Set(filtered.compactMap { $0.lesson?.chapter })).sorted(), id: \.self) {
                                chapter in
                                let problems = filtered.filter { $0.lesson?.chapter == chapter }
                                Section {
                                    ForEach(problems) { problem in puzzleRow(problem) }
                                } header: {
                                    if let lesson = problems.first?.lesson {
                                        Text(L10n.text("第 %ld 章 · %@", chapter, L10n.text(lesson.chapterTitle)))
                                            .font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
                                    }
                                }
                            }
                        } else {
                            ForEach(filtered) { problem in puzzleRow(problem) }
                        }
                    }.listStyle(.plain)
                }
            }.background(.white).foregroundStyle(Palette.ink)
        }
    }

    private var selectionCount: some View {
        Label(L10n.text("已选择 %ld 道", selected.count), systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.mint)
            .accessibilityIdentifier("battlefieldPuzzleSelectionCount")
    }

    private var selectionActions: some View {
        HStack(spacing: 16) {
            Button("原创 30 题") {
                selected = Set(store.problems.filter { $0.lesson != nil }.map(\.id))
            }
            Button("选择当前列表") { selected.formUnion(filtered.map(\.id)) }
                .accessibilityIdentifier("selectVisibleBattlefieldProblems").disabled(filtered.isEmpty)
            Button("清空选择") { selected.removeAll() }
                .accessibilityIdentifier("clearBattlefieldProblems").disabled(selected.isEmpty)
        }.buttonStyle(.borderless).font(.caption.weight(.medium)).tint(Palette.mint)
    }

    private func puzzleRow(_ problem: Problem) -> some View {
        Toggle(
            isOn: Binding(
                get: { selected.contains(problem.id) },
                set: { on in
                    if on { selected.insert(problem.id) } else { selected.remove(problem.id) }
                })
        ) {
            HStack(spacing: 12) {
                if let board = try? Board(problem: problem) {
                    BoardDrawing(board: board, position: board.start, heading: .north, visited: [], miniature: true)
                        .frame(width: 46, height: 46).padding(4)
                        .background(Palette.paper, in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(problem.displayTitle).font(.body.weight(.medium)).lineLimit(1)
                    Text(problem.number + " · " + (problem.lesson.map { L10n.text($0.chapterTitle) } ?? problem.author))
                        .font(.caption).foregroundStyle(Palette.muted).lineLimit(1)
                }
                Spacer(minLength: 4)
                Text("≤ \(problem.byteLimit) B").font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.muted).fixedSize()
            }.padding(.vertical, 3)
        }.toggleStyle(BattlefieldPuzzleToggleStyle()).accessibilityIdentifier("problemChoice-\(problem.id)")
    }
}

private struct BattlefieldPuzzleToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.title3).foregroundStyle(configuration.isOn ? Palette.mint : Palette.muted)
                configuration.label
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityValue(configuration.isOn ? L10n.text("已选题目") : L10n.text("选择题目"))
            .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}
