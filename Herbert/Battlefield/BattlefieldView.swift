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
                            Text(summary.status.title + " · " + summary.mode.title).font(.caption).foregroundStyle(
                                Palette.muted)
                            Text(
                                L10n.text(
                                    "%ld 个 AI · %ld 道题 · 最高 %@ 分", summary.entrantCount,
                                    summary.problemCount, battlefieldScore(summary.topScore))
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
                Text("比赛模式").font(.title2.bold())
                Picker("比赛模式", selection: $configuration.mode) {
                    ForEach(CompetitionMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented).accessibilityIdentifier("competitionMode")
                if configuration.mode == .timed {
                    HStack {
                        Text("时限（秒）")
                        Spacer()
                        TextField("时限（秒）", value: $configuration.timeLimitSeconds, format: .number)
                            .textFieldStyle(.roundedBorder).frame(width: 120)
                    }
                } else if configuration.mode == .tokenLimited {
                    HStack {
                        Text("Token 总预算")
                        Spacer()
                        TextField("Token 总预算", value: $configuration.tokenLimit, format: .number)
                            .textFieldStyle(.roundedBorder).frame(width: 150)
                    }
                    Picker("预算范围", selection: $configuration.tokenBudgetScope) {
                        Text("全场共享").tag(TokenBudgetScope.shared)
                        Text("每个 AI 独立").tag(TokenBudgetScope.perModel)
                    }
                    Text("预算包含所有尝试的输入与输出 Token。流式调用中使用估算，响应结束后核对服务商用量；取消时的实际账单可能高于已报告用量。")
                        .font(.caption).foregroundStyle(Palette.muted)
                } else {
                    Text("不限比赛时间和总 Token；每个 AI 都会完成全部所选题目的尝试，所有 AI 完成后才结束。也可以随时终止。")
                        .font(.callout).foregroundStyle(Palette.muted)
                }
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
                configuration = battlefield.settings.competition
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
                            Text(option.preset.model.name).font(.headline)
                            Text(
                                option.provider.name + " · " + String(option.preset.parameters.maxOutputTokens)
                                    + " max tokens"
                            )
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
                        search.isEmpty || $0.preset.model.name.localizedCaseInsensitiveContains(search)
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
                            Text(option.preset.model.name).font(.headline)
                            Text(option.provider.name + " / " + option.preset.model.id).font(.caption).foregroundStyle(
                                Palette.muted)
                        }
                    }.disabled(!selected.contains(option.id) && selected.count >= 32)
                }.searchable(text: $search, prompt: L10n.text("搜索模型"))
            }
        }
    }
}

private struct BattlefieldProblemPicker: View {
    @EnvironmentObject private var store: AppStore
    @Binding var selected: Set<Int>
    @State private var search = ""
    @State private var includeCommunity = false
    var body: some View {
        BattlefieldSheet(title: L10n.text("比赛题目")) {
            VStack {
                HStack {
                    Button("原创 30 题") {
                        selected = Set(store.problems.filter { $0.lesson != nil }.map(\.id))
                    }
                    Spacer()
                    Button("清空选择") { selected.removeAll() }.accessibilityIdentifier("clearBattlefieldProblems")
                }.padding(.horizontal)
                if store.problems.contains(where: { $0.lesson == nil }) {
                    Toggle("包括社区题目", isOn: $includeCommunity).padding(.horizontal)
                }
                List(
                    store.problems.filter {
                        (includeCommunity || $0.lesson != nil)
                            && (search.isEmpty || $0.number.localizedCaseInsensitiveContains(search)
                                || $0.title.localizedCaseInsensitiveContains(search))
                    }
                ) { problem in
                    Toggle(
                        isOn: Binding(
                            get: { selected.contains(problem.id) },
                            set: { on in
                                if on { selected.insert(problem.id) } else { selected.remove(problem.id) }
                            })
                    ) {
                        HStack {
                            Text(problem.number).font(.system(.body, design: .monospaced))
                            Text(L10n.text(problem.title))
                            Spacer()
                            Text("\(problem.byteLimit) bytes").font(.caption).foregroundStyle(Palette.muted)
                        }
                    }.accessibilityIdentifier("problemChoice-\(problem.id)")
                }.searchable(text: $search, prompt: L10n.text("搜索题目"))
                Text(L10n.text("已选择 %ld 道", selected.count)).padding(.bottom)
            }
        }
    }
}
