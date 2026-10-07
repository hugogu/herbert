import Foundation

public struct ProblemProgress: Codable, Equatable, Sendable {
    public var problemID: Int
    public var draft: String
    public var bestSolution: String?
    public var bestBytes: Int?
    public var completedAt: Date?
    public var isFavorite: Bool
    public var updatedAt: Date

    public init(
        problemID: Int, draft: String = "", bestSolution: String? = nil, bestBytes: Int? = nil,
        completedAt: Date? = nil, isFavorite: Bool = false, updatedAt: Date = .now
    ) {
        self.problemID = problemID
        self.draft = draft
        self.bestSolution = bestSolution
        self.bestBytes = bestBytes
        self.completedAt = completedAt
        self.isFavorite = isFavorite
        self.updatedAt = updatedAt
    }
}

public struct ProgressSnapshot: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var records: [ProblemProgress]
    public var lastProblemID: Int?

    public init(records: [ProblemProgress] = [], lastProblemID: Int? = nil) {
        self.records = records
        self.lastProblemID = lastProblemID
    }

    public func validated() throws -> ProgressSnapshot {
        guard schemaVersion == 1 else { throw ProgressError.unsupportedVersion(schemaVersion) }
        guard records.count <= 20_000, Set(records.map(\.problemID)).count == records.count,
            records.allSatisfy({
                $0.problemID > 0 && $0.draft.utf8.count <= 16_384 && ($0.bestSolution?.utf8.count ?? 0) <= 16_384
                    && ($0.bestBytes == nil || ($0.bestBytes! >= 0 && $0.bestSolution != nil && $0.completedAt != nil))
                    && ($0.bestSolution == nil || $0.bestBytes == HProgram.countBytes($0.bestSolution!))
            })
        else {
            throw ProgressError.invalidBackup
        }
        return self
    }
}

public enum ProgressError: Error, LocalizedError {
    case unsupportedVersion(Int)
    case invalidBackup

    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version): HerbertStrings.text("无法读取版本 %ld 的存档，请更新应用。", version)
        case .invalidBackup: HerbertStrings.text("存档格式或解题记录无效，原有数据未改变。")
        }
    }
}

public protocol ProgressRepository: Sendable {
    func load() throws -> ProgressSnapshot
    func save(_ snapshot: ProgressSnapshot) throws
}

public struct LocalProgressRepository: ProgressRepository {
    public let fileURL: URL

    public init(fileURL: URL) { self.fileURL = fileURL }

    public static func applicationDefault() throws -> LocalProgressRepository {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return LocalProgressRepository(
            fileURL: root.appendingPathComponent("Herbert", isDirectory: true).appendingPathComponent("progress.json"))
    }

    public func load() throws -> ProgressSnapshot {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return ProgressSnapshot() }
        return try Self.decode(Data(contentsOf: fileURL))
    }

    public func save(_ snapshot: ProgressSnapshot) throws {
        let data = try Self.encode(snapshot)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }

    public static func encode(_ snapshot: ProgressSnapshot) throws -> Data {
        _ = try snapshot.validated()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }

    public static func decode(_ data: Data) throws -> ProgressSnapshot {
        guard data.count <= 32 * 1024 * 1024 else { throw ProgressError.invalidBackup }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ProgressSnapshot.self, from: data).validated()
    }
}
