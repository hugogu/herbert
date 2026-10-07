import HerbertCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var problems: [Problem] = []
    @Published private(set) var snapshot = ProgressSnapshot()
    @Published var storageMessage: String?
    @Published var catalogMessage: String?
    private var repository: (any ProgressRepository)?
    private var canSave = true
    private var saveTask: Task<Void, Never>?

    init() {
        do { problems = try ProblemCatalog.bundled() } catch { catalogMessage = error.localizedDescription }
        do {
            let local: LocalProgressRepository
            if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                local = LocalProgressRepository(
                    fileURL: FileManager.default.temporaryDirectory
                        .appendingPathComponent("Herbert-UITests/progress.json"))
                if ProcessInfo.processInfo.arguments.contains("--reset-progress") {
                    try local.save(ProgressSnapshot())
                }
            } else {
                local = try .applicationDefault()
            }
            repository = local
            snapshot = try local.load()
        } catch {
            canSave = false
            storageMessage = L10n.text("存档读取失败，已暂停自动保存以保护原文件。\n%@", error.localizedDescription)
        }
    }

    var completedCount: Int { snapshot.records.filter { $0.bestBytes != nil }.count }
    var favoriteCount: Int { snapshot.records.filter(\.isFavorite).count }
    var resumeProblem: Problem? {
        problems.first { $0.id == snapshot.lastProblemID } ?? problems.first
    }

    func progress(for id: Int) -> ProblemProgress {
        snapshot.records.first { $0.problemID == id } ?? ProblemProgress(problemID: id)
    }

    func visit(_ id: Int) {
        snapshot.lastProblemID = id
        scheduleSave()
    }

    func setDraft(_ source: String, for id: Int) {
        update(id) { $0.draft = source }
    }

    func toggleFavorite(_ id: Int) { update(id) { $0.isFavorite.toggle() } }

    func complete(_ problem: Problem, source: String, bytes: Int) {
        update(problem.id) { record in
            if record.bestBytes == nil || bytes < record.bestBytes! {
                record.bestBytes = bytes
                record.bestSolution = source
            }
            if record.completedAt == nil { record.completedAt = .now }
        }
    }

    private func update(_ id: Int, mutation: (inout ProblemProgress) -> Void) {
        var record = progress(for: id)
        mutation(&record)
        record.updatedAt = .now
        if let index = snapshot.records.firstIndex(where: { $0.problemID == id }) {
            snapshot.records[index] = record
        } else {
            snapshot.records.append(record)
        }
        scheduleSave()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    func flush() {
        saveTask?.cancel()
        guard canSave, let repository else { return }
        do {
            try repository.save(snapshot)
            storageMessage = nil
        } catch { storageMessage = L10n.text("保存失败：%@。请导出备份后重试。", error.localizedDescription) }
    }

    func importBackup(_ data: Data) async throws {
        let incoming = try LocalProgressRepository.decode(data)
        let catalog = problems
        let validated = try await Task.detached(priority: .userInitiated) {
            try ProgressTransfer.validate(incoming, catalog: catalog)
        }.value
        let result = try ProgressTransfer.merge(current: snapshot, validated: validated)
        guard let repository else { throw ProgressError.invalidBackup }
        try repository.save(result)
        snapshot = result
        canSave = true
        storageMessage = nil
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
