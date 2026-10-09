import Foundation

public struct BattlefieldSettings: Codable, Sendable {
    public var schemaVersion = 3
    public var providers: [ProviderConfiguration] = []
    public var competition = CompetitionConfiguration()
    public init() {}

    public func validated() throws -> BattlefieldSettings {
        guard (1...3).contains(schemaVersion), providers.count <= 100,
            Set(providers.map(\.id)).count == providers.count
        else { throw BattlefieldError.storageCorrupt }
        for provider in providers { _ = try provider.validated() }
        _ = try competition.validated()
        return self
    }

    public func upgradingMatchSettings() -> BattlefieldSettings {
        var upgraded = self
        upgraded.competition = competition.forNewMatch()
        for p in upgraded.providers.indices {
            for m in upgraded.providers[p].presets.indices {
                upgraded.providers[p].presets[m].parameters.maxOutputTokens = nil
            }
        }
        upgraded.schemaVersion = 3
        return upgraded
    }

}

public struct CompetitionSummary: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let status: CompetitionStatus
    public let mode: CompetitionMode?
    public let problemCount: Int
    public let entrantCount: Int
    public let leader: String?
    public let topScore: Double
    public let totalTokens: Int
    public var topScoreFraction: Double {
        guard problemCount > 0 else { return 0 }
        return min(1, max(0, topScore / (Double(problemCount) * 100)))
    }
    public init(_ result: CompetitionResult) {
        id = result.id
        startedAt = result.startedAt
        status = result.status
        mode = result.configuration.legacyMode
        problemCount = result.problems.count
        entrantCount = result.entrants.count
        leader = result.ranked.first?.entrant.preset.model.name
        topScore = result.ranked.first.map { result.score(for: $0) } ?? 0
        totalTokens = result.totalTokens
    }
}

public protocol BattlefieldRepository: Sendable {
    func loadSettings() throws -> BattlefieldSettings
    func saveSettings(_ settings: BattlefieldSettings) throws
    func summaries() throws -> [CompetitionSummary]
    func loadResult(_ id: UUID) throws -> CompetitionResult
    func saveResult(_ result: CompetitionResult) throws
}

public struct LocalBattlefieldRepository: BattlefieldRepository {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }
    public static func applicationDefault() throws -> LocalBattlefieldRepository {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        return LocalBattlefieldRepository(
            directory: root.appendingPathComponent("Herbert/Battlefield", isDirectory: true))
    }

    private var settingsURL: URL { directory.appendingPathComponent("providers.json") }
    private var historyURL: URL { directory.appendingPathComponent("history", isDirectory: true) }
    private var indexURL: URL { historyURL.appendingPathComponent("index.json") }

    private func decode<T: Decodable>(_ type: T.Type, url: URL, limit: Int = 64 * 1024 * 1024) throws -> T {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= limit else { throw BattlefieldError.storageCorrupt }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(type, from: Data(contentsOf: url))
    }

    private func write<T: Encodable>(_ object: T, url: URL, limit: Int = 64 * 1024 * 1024) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(object)
        guard data.count <= limit else { throw BattlefieldError.storageCorrupt }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    public func loadSettings() throws -> BattlefieldSettings {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return BattlefieldSettings() }
        return try decode(BattlefieldSettings.self, url: settingsURL, limit: 8 * 1024 * 1024)
            .validated().upgradingMatchSettings()
    }

    public func saveSettings(_ settings: BattlefieldSettings) throws {
        try write(settings.validated(), url: settingsURL, limit: 8 * 1024 * 1024)
    }

    public func summaries() throws -> [CompetitionSummary] {
        var index =
            FileManager.default.fileExists(atPath: indexURL.path)
            ? try decode([CompetitionSummary].self, url: indexURL, limit: 8 * 1024 * 1024) : []
        guard Set(index.map(\.id)).count == index.count else { throw BattlefieldError.storageCorrupt }
        // A crash after writing a result but before its index must not hide that result.
        let indexed = Set(index.map(\.id))
        if FileManager.default.fileExists(atPath: historyURL.path) {
            for url in try FileManager.default.contentsOfDirectory(at: historyURL, includingPropertiesForKeys: nil) {
                if url.pathExtension == "json",
                    let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent),
                    !indexed.contains(id)
                {
                    index.append(CompetitionSummary(try loadResult(id)))
                }
            }
        }
        return index.sorted { $0.startedAt > $1.startedAt }
    }

    public func loadResult(_ id: UUID) throws -> CompetitionResult {
        let result = try decode(CompetitionResult.self, url: historyURL.appendingPathComponent("\(id.uuidString).json"))
        guard result.schemaVersion == 1, result.id == id, result.problems.count <= 2000,
            result.entrants.count <= 32, Set(result.problems.map(\.id)).count == result.problems.count,
            Set(result.entrants.map(\.id)).count == result.entrants.count,
            result.entrants.allSatisfy({ $0.answers.map(\.id) == result.problems.map(\.id) })
        else {
            throw BattlefieldError.storageCorrupt
        }
        _ = try result.configuration.validated()
        return result
    }

    public func saveResult(_ result: CompetitionResult) throws {
        var index = try summaries()
        try write(result, url: historyURL.appendingPathComponent("\(result.id.uuidString).json"))
        index.removeAll { $0.id == result.id }
        index.insert(CompetitionSummary(result), at: 0)
        try write(index, url: indexURL, limit: 8 * 1024 * 1024)
    }
}

/// Serializes checkpoints so an older asynchronous save cannot replace a final result.
public actor BattlefieldPersistence {
    private let repository: any BattlefieldRepository
    public init(repository: any BattlefieldRepository) { self.repository = repository }
    public func save(_ result: CompetitionResult) throws { try repository.saveResult(result) }
    public func summaries() throws -> [CompetitionSummary] { try repository.summaries() }
    public func load(_ id: UUID) throws -> CompetitionResult { try repository.loadResult(id) }
}
