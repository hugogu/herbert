#if APP_STORE && !LOCAL_LEARNING
    import AuthenticationServices
    import HerbertCloud
    import SwiftUI

    struct LeaderboardView: View {
        @EnvironmentObject private var store: AppStore
        @StateObject private var model = CloudModel()
        @State private var confirmDeletion = false
        @State private var confirmUpload = false

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("全球排行榜").font(.largeTitle.bold())
                    Text("自愿上传原创练习的最短解；服务器会重新运行程序并计算成绩。本地游玩无需登录。")
                        .foregroundStyle(Palette.muted)
                    if !model.configured {
                        Label("此构建尚未配置排行榜服务。", systemImage: "network.slash")
                            .panel().accessibilityIdentifier("cloud-unconfigured")
                    } else {
                        account
                        if let leaderboard = model.leaderboard {
                            VStack(spacing: 12) {
                                HStack {
                                    Text("已验证的成绩").font(.headline)
                                    Spacer()
                                    Text(L10n.text("%ld 道原创练习", leaderboard.puzzleCount)).foregroundStyle(Palette.muted)
                                }
                                if leaderboard.entries.isEmpty { Text("还没有上传的成绩。").padding() }
                                ForEach(leaderboard.entries) { entry in
                                    HStack(spacing: 16) {
                                        Text(String(format: "%02d", entry.rank)).monospacedDigit().foregroundStyle(
                                            Palette.mint)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(entry.displayName).font(.headline)
                                            Text(L10n.text("已完成 %ld/%ld", entry.solved, leaderboard.puzzleCount)).font(
                                                .caption
                                            ).foregroundStyle(Palette.muted)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing) {
                                            Text(entry.percentage / 100, format: .percent.precision(.fractionLength(2)))
                                                .font(.title2.bold())
                                            Text(L10n.text("%@ 分", entry.points.formatted())).font(.caption)
                                                .foregroundStyle(Palette.muted)
                                        }
                                    }.panel(padding: 16)
                                }
                            }
                        }
                        Button {
                            Task { await model.load() }
                        } label: {
                            Label("刷新", systemImage: "arrow.clockwise")
                        }
                        .secondaryButtonStyle()
                    }
                    if model.busy { SwiftUI.ProgressView().accessibilityIdentifier("cloud-busy") }
                    if let message = model.message {
                        Text(message).font(.callout).textSelection(.enabled).accessibilityIdentifier("cloud-message")
                    }
                }.padding(24).frame(maxWidth: 850).frame(maxWidth: .infinity)
            }.background(Palette.paper).navigationTitle("全球排行榜")
                .task { await model.load() }
                .confirmationDialog("上传原创练习的最短解？", isPresented: $confirmUpload, titleVisibility: .visible) {
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
                .disabled(model.busy)
        }
        private var account: some View {
            VStack(alignment: .leading, spacing: 16) {
                if let user = model.user {
                    Label(user.displayName, systemImage: "person.crop.circle").font(.headline)
                    Button {
                        confirmUpload = true
                    } label: {
                        Label("上传最短解", systemImage: "arrow.up.circle")
                    }
                    .prominentButtonStyle().accessibilityIdentifier("cloud-upload")
                    HStack {
                        Button("退出登录") { Task { await model.signOut() } }.secondaryButtonStyle()
                        Spacer()
                        Button("删除云账号", role: .destructive) { confirmDeletion = true }.buttonStyle(.plain)
                    }
                } else {
                    AppleLoginButton { Task { await model.signIn() } }
                        .frame(width: 240, height: 44)
                        .accessibilityIdentifier("cloud-apple-login")
                }
            }.panel()
        }
    }
#endif
