import HerbertCore
import SwiftUI

struct ProgressViewScreen: View {
    @EnvironmentObject private var store: AppStore
    @State private var exporting = false
    @State private var importing = false
    @State private var busy = false
    @State private var document = BackupDocument(data: Data())
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Eyebrow(text: "ONE SMALL STEP AT A TIME")
                Text("思考留下的足迹。").font(.system(size: 30, weight: .bold, design: .rounded))
                HStack(spacing: 16) {
                    counter("已完成", value: store.completedCount)
                    counter("已收藏", value: store.favoriteCount)
                    counter("草稿", value: store.visibleRecords.filter { !$0.draft.isEmpty }.count)
                }
                VStack(alignment: .leading, spacing: 16) {
                    Label("你的进度保存在这台设备上", systemImage: "internaldrive")
                        .font(.system(size: 16, weight: .semibold))
                    Text("草稿自动保存，每关保留最短解。导出 JSON 备份可迁移到另一台设备；导入会合并记录，保留更短的有效解。")
                        .font(.system(size: 13)).foregroundStyle(Palette.muted).lineSpacing(5)
                    HStack(spacing: 12) {
                        Button {
                            do {
                                store.flush()
                                document = BackupDocument(
                                    data: try LocalProgressRepository.encode(store.visibleSnapshot))
                                exporting = true
                            } catch { message = error.localizedDescription }
                        } label: {
                            Label("导出", systemImage: "square.and.arrow.up").frame(minHeight: 36)
                        }
                        .prominentButtonStyle().accessibilityIdentifier("export-backup")
                        Button {
                            importing = true
                        } label: {
                            Label("导入", systemImage: "square.and.arrow.down").frame(minHeight: 36)
                        }
                        .secondaryButtonStyle().accessibilityIdentifier("import-backup")
                    }.disabled(busy)
                    if busy { SwiftUI.ProgressView("正在验证并合并备份…").font(.caption) }
                    if let message {
                        Text(message).font(.caption).foregroundStyle(Palette.mint).accessibilityIdentifier(
                            "backup-message")
                    }
                    if let error = store.storageMessage { Text(error).font(.caption).foregroundStyle(Palette.danger) }
                }.panel()
                HStack {
                    Text("已完成的关卡").font(.system(size: 20, weight: .bold))
                    Spacer()
                    Pill(text: L10n.text("%ld SOLVED", store.completedCount))
                }
                let completed = store.visibleRecords.filter { $0.bestBytes != nil }.sorted {
                    ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
                }
                if completed.isEmpty {
                    ContentUnavailableView(
                        "第一份灵感，还在路上", systemImage: "sparkles", description: Text("完成一个关卡，你的最短解就会出现在这里。"))
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(completed, id: \.problemID) { record in
                            if let problem = store.problems.first(where: { $0.id == record.problemID }) {
                                NavigationLink(value: problem) {
                                    HStack(spacing: 14) {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.mint)
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(problem.displayTitle).font(.system(size: 14, weight: .semibold))
                                            Text("\(problem.number) · \(problem.author)").font(
                                                .system(size: 10, design: .monospaced)
                                            ).foregroundStyle(Palette.muted)
                                        }
                                        Spacer()
                                        Pill(text: "\(record.bestBytes ?? 0) B")
                                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.muted)
                                    }.panel(padding: 16)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
            }.padding(24).frame(maxWidth: 850).frame(maxWidth: .infinity)
        }.background(Palette.paper).navigationTitle("我的记录")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationDestination(for: Problem.self) { problem in GameDestination(problem: problem, store: store) }
            .fileExporter(
                isPresented: $exporting, document: document, contentType: .json, defaultFilename: "herbert-backup"
            ) { result in
                switch result {
                case .success: message = L10n.text("备份已导出。")
                case .failure(let error): message = L10n.text("导出失败：%@", error.localizedDescription)
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard fileSize <= 32 * 1024 * 1024 else { throw ProgressError.invalidBackup }
                    let data = try Data(contentsOf: url)
                    busy = true
                    Task {
                        do {
                            try await store.importBackup(data)
                            message = L10n.text("备份已合并，最短解已校验。")
                        } catch { message = L10n.text("导入失败：%@", error.localizedDescription) }
                        busy = false
                    }
                } catch { message = L10n.text("导入失败：%@", error.localizedDescription) }
            }
    }

    private func counter(_ title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(value)).font(.system(size: 30, weight: .medium, design: .monospaced))
            Text(LocalizedStringKey(title)).font(.system(size: 12)).foregroundStyle(Palette.muted)
        }.frame(maxWidth: .infinity, alignment: .leading).panel(padding: 16)
    }
}
