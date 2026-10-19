#if APP_STORE && !LOCAL_LEARNING
    import AuthenticationServices
    import HerbertCloud
    import HerbertCore
    import SwiftUI

    struct LeaderboardView: View {
        @EnvironmentObject private var store: AppStore
        @EnvironmentObject private var model: CloudModel
        @Environment(\.openURL) private var openURL
        @State private var showHiddenPlayers = false
        @State private var selection: Int
        @State private var total: Leaderboard?
        @State private var problemRanking: ProblemLeaderboard?
        @State private var loading = false
        @State private var error: String?

        init(problem: Problem? = nil) { _selection = State(initialValue: problem?.id ?? 0) }
        private var problem: Problem? { store.problems.first { $0.id == selection } }

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("全球排行榜").font(.largeTitle.bold())
                    Text("每位玩家每题取最佳成绩，总榜为各题成绩之和。服务器重新运行所有上传的程序。")
                        .font(.callout).foregroundStyle(Palette.muted)
                    Picker("排行榜范围", selection: $selection) {
                        Text("个人总榜").tag(0)
                        ForEach(store.problems.filter { $0.lesson != nil }) { puzzle in
                            Text("\(puzzle.number) · \(puzzle.displayTitle)").tag(puzzle.id)
                        }
                    }.accessibilityIdentifier("cloud-ranking-scope")
                    if !model.configured {
                        Label("此构建尚未配置排行榜服务。", systemImage: "network.slash")
                            .panel().accessibilityIdentifier("cloud-unconfigured")
                    } else {
                        if let problem {
                            Text("\(problem.number) · \(problem.displayTitle)").font(.title2.bold())
                            if let problemRanking {
                                if problemRanking.entries.isEmpty { Text("还没有上传的成绩。").padding() }
                                ForEach(problemRanking.entries.filter { model.hiddenPlayers[$0.userID] == nil }) {
                                    entry in
                                    rankingRow(
                                        rank: entry.rank, id: entry.userID, name: entry.displayName,
                                        points: entry.points
                                    ) {
                                        Text(
                                            L10n.text(
                                                "已点亮 %ld/%ld · %ld B", entry.litTargets, entry.targetCount, entry.bytes)
                                                + " · "
                                                + (entry.steps.map { L10n.text("%ld 条指令", $0) } ?? L10n.text("指令数未知"))
                                        )
                                        .font(.caption).foregroundStyle(Palette.muted)
                                    }
                                }
                            }
                        } else if let total {
                            Text(L10n.text("%ld 道原创练习", total.puzzleCount)).foregroundStyle(Palette.muted)
                            if total.entries.isEmpty { Text("还没有上传的成绩。").padding() }
                            ForEach(total.entries.filter { model.hiddenPlayers[$0.userID] == nil }) { entry in
                                rankingRow(
                                    rank: entry.rank, id: entry.userID, name: entry.displayName, points: entry.points
                                ) {
                                    Text(L10n.text("已完成 %ld/%ld", entry.solved, total.puzzleCount))
                                        .font(.caption).foregroundStyle(Palette.muted)
                                }
                            }
                        }
                        if !model.hiddenPlayers.isEmpty {
                            DisclosureGroup("本机隐藏的玩家", isExpanded: $showHiddenPlayers) {
                                ForEach(model.hiddenPlayers.keys.sorted(), id: \.self) { id in
                                    HStack {
                                        Text(model.hiddenPlayers[id] ?? id)
                                        Spacer()
                                        Button("取消隐藏") { model.showPlayer(id: id) }
                                            .secondaryButtonStyle().accessibilityIdentifier("cloud-unhide-" + id)
                                    }
                                }
                            }
                        }
                        Button {
                            Task { await reload() }
                        } label: {
                            Label("刷新", systemImage: "arrow.clockwise")
                        }.secondaryButtonStyle().disabled(loading)
                    }
                    if loading { SwiftUI.ProgressView().accessibilityIdentifier("cloud-busy") }
                    if let error { Text(error).foregroundStyle(Palette.danger).textSelection(.enabled) }
                }.padding(24).frame(maxWidth: 850).frame(maxWidth: .infinity)
            }.background(Palette.paper).navigationTitle("全球排行榜")
                .task(id: selection) { await reload() }
        }
        private func rankingRow<Detail: View>(
            rank: Int, id: String, name: String, points: Double, @ViewBuilder detail: () -> Detail
        ) -> some View {
            HStack(spacing: 16) {
                Text(String(format: "%02d", rank)).monospacedDigit().foregroundStyle(Palette.mint)
                VStack(alignment: .leading, spacing: 4) {
                    Text(name).font(.headline)
                    detail()
                }
                Spacer()
                Text(L10n.text("%@ 分", points.formatted(.number.precision(.fractionLength(0...2)))))
                    .font(.title3.bold()).foregroundStyle(Palette.mint)
                if id != model.user?.userID {
                    Menu {
                        Button {
                            if let url = LeaderboardSafety.reportURL(userID: id, displayName: name) { openURL(url) }
                        } label: {
                            Label("举报昵称", systemImage: "flag")
                        }
                        Button {
                            model.hidePlayer(id: id, name: name)
                        } label: {
                            Label("在本机隐藏此玩家", systemImage: "person.crop.circle.badge.minus")
                        }
                        .accessibilityIdentifier("cloud-hide-" + id)
                    } label: {
                        Image(systemName: "ellipsis.circle").accessibilityLabel("玩家选项")
                    }.buttonStyle(.plain).foregroundStyle(Palette.mint)
                        .accessibilityIdentifier("cloud-player-menu-" + id)
                }
            }.panel(padding: 16)
        }
        private func reload() async {
            let requested = selection
            loading = true
            error = nil
            total = nil
            problemRanking = nil
            defer { if selection == requested { loading = false } }
            do {
                if let problem {
                    let result = try await model.problemLeaderboard(problem)
                    guard !Task.isCancelled, selection == requested else { return }
                    problemRanking = result
                } else {
                    let result = try await model.totalLeaderboard()
                    guard !Task.isCancelled, selection == requested else { return }
                    total = result
                }
            } catch {
                if !Task.isCancelled, selection == requested { self.error = error.localizedDescription }
            }
        }
    }

    struct CloudAccountView: View {
        @EnvironmentObject private var store: AppStore
        @EnvironmentObject private var model: CloudModel
        @State private var confirmDeletion = false
        @State private var confirmUpload = false
        @State private var nicknameDraft: NicknameDraft?
        private struct NicknameDraft: Identifiable {
            let id = UUID()
            let name: String
        }
        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                Text("账号").font(.title2.bold())
                Text("选择分享已保存的原创题解答，服务器会重新运行程序并计算成绩。只有昵称和成绩会公开，程序不公开。本地练习无需登录。")
                    .font(.callout).foregroundStyle(Palette.muted)
                if model.configured {
                    account
                } else {
                    Label("此构建尚未配置排行榜服务。", systemImage: "network.slash").panel()
                }
                if model.busy { SwiftUI.ProgressView() }
                if let message = model.message {
                    Text(message).font(.callout).textSelection(.enabled).accessibilityIdentifier("cloud-message")
                }
            }
            .task {
                await model.load()
                if let suggestion = model.suggestedName { nicknameDraft = NicknameDraft(name: suggestion) }
            }
            .sheet(item: $nicknameDraft) { draft in NicknameEditor(model: model, initialName: draft.name) }
            .onChange(of: model.suggestedName) { _, suggestion in
                if let suggestion { nicknameDraft = NicknameDraft(name: suggestion) }
            }
            .confirmationDialog("上传并分享我的解答？", isPresented: $confirmUpload, titleVisibility: .visible) {
                Button("上传并验证") {
                    Task {
                        model.message = nil
                        await model.upload(store.visibleRecords, problems: store.problems)
                    }
                }
            } message: {
                Text("将上传你的 H 程序和练习编号，并公开显示匿名昵称及成绩。不会上传草稿、AI 配置或 API 密钥。")
            }
            .confirmationDialog("删除云账号？", isPresented: $confirmDeletion, titleVisibility: .visible) {
                Button("删除云账号", role: .destructive) { Task { await model.deleteAccount() } }
            } message: {
                Text("这会撤销 Apple 授权并移除排行榜成绩和已上传的程序。本地记录不受影响。")
            }
        }
        private var savedSolutionsCount: Int {
            store.visibleRecords.filter { record in
                record.bestSolution != nil && store.problems.contains { $0.id == record.problemID && $0.lesson != nil }
            }.count
        }
        private var account: some View {
            VStack(alignment: .leading, spacing: 16) {
                if let user = model.user {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(user.displayName, systemImage: "person.crop.circle").font(.headline)
                            Label("已通过 Apple 登录", systemImage: "checkmark.shield")
                                .font(.caption).foregroundStyle(Palette.mint)
                        }
                        Spacer()
                        Button {
                            nicknameDraft = NicknameDraft(name: model.suggestedName ?? user.displayName)
                        } label: {
                            Label("编辑昵称", systemImage: "pencil")
                        }.secondaryButtonStyle().accessibilityIdentifier("cloud-edit-name")
                    }
                    Button {
                        confirmUpload = true
                    } label: {
                        Label("上传并分享我的解答", systemImage: "arrow.up.circle")
                    }
                    .buttonStyle(PrimaryButtonStyle()).disabled(savedSolutionsCount == 0).accessibilityIdentifier(
                        "cloud-upload")
                    Text(L10n.text("将上传 %ld 道原创题的已保存解答，每题一份；不包含草稿或社区题。", savedSolutionsCount))
                        .font(.caption).foregroundStyle(Palette.muted).accessibilityIdentifier("cloud-upload-scope")
                    HStack {
                        Button("退出登录") { Task { await model.signOut() } }.secondaryButtonStyle()
                        Spacer()
                        Button("删除云账号", role: .destructive) { confirmDeletion = true }.buttonStyle(.plain)
                            .foregroundStyle(Palette.danger)
                    }
                } else {
                    Label("未登录", systemImage: "person.crop.circle").foregroundStyle(Palette.muted)
                    AppleLoginButton { Task { await model.signIn() } }
                        .frame(width: 240, height: 44)
                        .accessibilityIdentifier("cloud-apple-login")
                }
            }.panel().disabled(model.busy)
        }
    }

    private struct NicknameEditor: View {
        @ObservedObject var model: CloudModel
        @Environment(\.dismiss) private var dismiss
        @State private var nickname: String

        init(model: CloudModel, initialName: String) {
            self.model = model
            _nickname = State(initialValue: initialName)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 18) {
                Text("排行榜昵称").font(.title2.bold())
                Text("昵称将公开显示在排行榜上。你可以使用昵称，无需公开真实姓名。")
                    .font(.callout).foregroundStyle(Palette.muted)
                TextField(L10n.text("昵称（1–32 个字符）"), text: $nickname)
                    .textFieldStyle(.roundedBorder).accessibilityIdentifier("cloud-name-field")
                if let message = model.message {
                    Text(message).font(.callout).foregroundStyle(Palette.danger)
                }
                HStack {
                    Button("取消") { dismiss() }.secondaryButtonStyle()
                    Spacer()
                    Button("保存") {
                        Task {
                            if await model.updateDisplayName(nickname) { dismiss() }
                        }
                    }.buttonStyle(PrimaryButtonStyle())
                        .disabled(model.busy || nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("cloud-save-name")
                }
            }.padding(24).frame(idealWidth: 440).background(Palette.paper).disabled(model.busy)
        }
    }
#endif
