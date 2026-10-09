import Foundation
import HerbertCore

public enum ProviderKind: String, Codable, CaseIterable, Sendable {
    case openRouter, siliconFlow, compatible

    public var defaultURL: String {
        switch self {
        case .openRouter: "https://openrouter.ai/api/v1"
        case .siliconFlow: "https://api.siliconflow.cn/v1"
        case .compatible: "https://api.openai.com/v1"
        }
    }

    public var title: String {
        switch self {
        case .openRouter: "OpenRouter"
        case .siliconFlow: "SiliconFlow"
        case .compatible: "OpenAI compatible"
        }
    }
}

public struct AIModel: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    /// Provider pricing qualifiers are presentation metadata, never part of the model ID.
    public var displayName: String {
        name.replacingOccurrences(
            of: #"\s*\(free\)\s*$"#, with: "", options: [.regularExpression, .caseInsensitive]
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    public var contextLength: Int?
    public var supportedParameters: [String]?
    public var maximumOutputTokens: Int?

    public init(
        id: String, name: String? = nil, contextLength: Int? = nil,
        supportedParameters: [String]? = nil, maximumOutputTokens: Int? = nil
    ) {
        self.id = id
        self.name = name ?? id
        self.contextLength = contextLength
        self.supportedParameters = supportedParameters
        self.maximumOutputTokens = maximumOutputTokens
    }
}

public enum OutputTokenParameter: String, Codable, CaseIterable, Sendable {
    case maxTokens = "max_tokens"
    case maxCompletionTokens = "max_completion_tokens"
}

public struct ModelParameters: Codable, Hashable, Sendable {
    public static let defaultMaxOutputTokens = 65_536
    public var maxOutputTokens = Self.defaultMaxOutputTokens
    public var temperature: Double?
    public var topP: Double?
    public var extraJSON = "{}"

    public init() {}

    public func validated() throws -> ModelParameters {
        guard (1...65_536).contains(maxOutputTokens),
            temperature.map({ $0.isFinite && (0...2).contains($0) }) ?? true,
            topP.map({ $0.isFinite && $0 > 0 && $0 <= 1 }) ?? true,
            extraJSON.utf8.count <= 8192,
            let data = extraJSON.data(using: .utf8),
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw BattlefieldError.invalidParameters }
        let allowed: Set<String> = [
            "seed", "top_k", "min_p", "frequency_penalty", "presence_penalty",
            "reasoning_effort", "reasoning", "thinking", "enable_thinking", "thinking_budget",
        ]
        guard Set(object.keys).isSubset(of: allowed) else { throw BattlefieldError.invalidParameters }
        return self
    }
}

public struct ModelPreset: Codable, Hashable, Identifiable, Sendable {
    public var id = UUID()
    public var model: AIModel
    public var parameters = ModelParameters()
    public var isDefault = true
    public init(model: AIModel) { self.model = model }
}

public struct ProviderConfiguration: Codable, Hashable, Identifiable, Sendable {
    public var id = UUID()
    public var name: String
    public var kind: ProviderKind
    public var baseURL: String
    public var outputTokenParameter = OutputTokenParameter.maxTokens
    public var models: [AIModel] = []
    public var presets: [ModelPreset] = []
    public var discoveredAt: Date?

    public init(kind: ProviderKind, name: String? = nil) {
        self.kind = kind
        self.name = name ?? kind.title
        baseURL = kind.defaultURL
    }

    public func endpoint(_ path: String) throws -> URL {
        guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
            url.scheme == "https", let host = url.host, !host.isEmpty,
            url.user == nil, url.password == nil, url.query == nil, url.fragment == nil
        else { throw BattlefieldError.invalidEndpoint }
        return url.appendingPathComponent(path)
    }

    public func validated() throws -> ProviderConfiguration {
        _ = try endpoint("models")
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            name.count <= 120, models.count <= 10_000, presets.count <= 10_000,
            Set(models.map(\.id)).count == models.count,
            Set(presets.map(\.id)).count == presets.count,
            Set(presets.map { $0.model.id }).count == presets.count,
            presets.allSatisfy({ !$0.model.id.isEmpty && $0.model.id.count <= 512 })
        else { throw BattlefieldError.invalidConfiguration }
        for preset in presets { _ = try preset.parameters.validated() }
        return self
    }
}

public enum CompetitionMode: String, Codable, CaseIterable, Sendable {
    case timed, tokenLimited, bestEffort
}

public enum TokenBudgetScope: String, Codable, CaseIterable, Sendable {
    case shared, perModel
}

public struct CompetitionConfiguration: Codable, Equatable, Sendable {
    public var mode = CompetitionMode.timed
    public var timeLimitSeconds: Double = 600
    public var tokenLimit = 100_000
    public var tokenBudgetScope = TokenBudgetScope.shared
    public var attemptsPerProblem = 3
    public var extraPrompt = ""

    public init() {}

    public func validated() throws -> CompetitionConfiguration {
        guard timeLimitSeconds.isFinite, timeLimitSeconds > 0, timeLimitSeconds <= 86_400,
            (1...100_000_000).contains(tokenLimit), (1...10).contains(attemptsPerProblem),
            extraPrompt.utf8.count <= 8192
        else { throw BattlefieldError.invalidConfiguration }
        return self
    }
}

public struct Entrant: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let providerID: UUID
    public let providerName: String
    public let kind: ProviderKind
    public let baseURL: String
    public let outputTokenParameter: OutputTokenParameter
    public let preset: ModelPreset

    public init(provider: ProviderConfiguration, preset: ModelPreset) {
        id = preset.id
        providerID = provider.id
        providerName = provider.name
        kind = provider.kind
        baseURL = provider.baseURL
        outputTokenParameter = provider.outputTokenParameter
        self.preset = preset
    }

    public var provider: ProviderConfiguration {
        var result = ProviderConfiguration(kind: kind, name: providerName)
        result.id = providerID
        result.baseURL = baseURL
        result.outputTokenParameter = outputTokenParameter
        return result
    }
}

/// Credentials are runtime-only and cannot be encoded into history or share images.
public struct CompetitionParticipant: Sendable {
    public let entrant: Entrant
    public let apiKey: String
    public init(entrant: Entrant, apiKey: String) {
        self.entrant = entrant
        self.apiKey = apiKey
    }
}

public struct TokenUsage: Codable, Equatable, Sendable {
    public var input: Int
    public var output: Int
    public var total: Int
    public var cached: Int?
    public var reasoning: Int?
    public var estimated: Bool
    public var partial: Bool

    public init(
        input: Int = 0, output: Int = 0, total: Int? = nil, cached: Int? = nil,
        reasoning: Int? = nil, estimated: Bool = true, partial: Bool = false
    ) {
        let input = max(0, min(input, 1_000_000_000))
        let output = max(0, min(output, 1_000_000_000))
        self.input = input
        self.output = output
        self.total = max(total ?? (self.input + self.output), self.input + self.output)
        self.cached = cached.map { max(0, min($0, input)) }
        self.reasoning = reasoning.map { max(0, min($0, output)) }
        self.estimated = estimated
        self.partial = partial
    }

    public static func estimate(messages: [AIMessage], outputBytes: Int = 0) -> TokenUsage {
        TokenUsage(
            input: messages.reduce(0) {
                $0 + ($1.content.utf8.count + ($1.reasoning?.content.utf8.count ?? 0) + 3) / 4 + 16
            },
            output: (outputBytes + 3) / 4)
    }
}

public enum ProblemAnswerStatus: String, Codable, Sendable {
    case queued, requesting, judging, solved, failed, error, cancelled
}

public struct AnswerAttempt: Codable, Identifiable, Equatable, Sendable {
    public let id: Int
    public let startedAt: Date
    public var finishedAt: Date?
    public var response = ""
    public var reasoning: AIReasoning?
    public var providerResponse: String?
    public var program: String?
    public var evaluation: JudgeEvaluation?
    public var usage = TokenUsage()
    public var error: String?
    public var requestedMaxOutputTokens: Int?
    public var finishReason: String?
    public init(number: Int, startedAt: Date = .now) {
        id = number
        self.startedAt = startedAt
    }
}

public struct ProblemAnswer: Codable, Identifiable, Equatable, Sendable {
    public let id: Int
    public var status = ProblemAnswerStatus.queued
    public var attempts: [AnswerAttempt] = []
    public init(problemID: Int) { id = problemID }
    public var acceptedBytes: Int? { attempts.first { $0.evaluation?.accepted == true }?.evaluation?.bytes }
}

public struct EntrantResult: Codable, Identifiable, Equatable, Sendable {
    public let entrant: Entrant
    public var answers: [ProblemAnswer]
    public var finishedAt: Date?
    public var error: String?
    public var exhaustedBudget = false
    public var id: UUID { entrant.id }
    public init(entrant: Entrant, problems: [Problem]) {
        self.entrant = entrant
        answers = problems.map { ProblemAnswer(problemID: $0.id) }
    }
    public var solved: Int { answers.filter { $0.status == .solved }.count }
    public var bytes: Int { answers.compactMap(\.acceptedBytes).reduce(0, +) }
    public var usages: [TokenUsage] { answers.flatMap(\.attempts).map(\.usage) }
    public var inputTokens: Int { usages.reduce(0) { $0 + $1.input } }
    public var outputTokens: Int { usages.reduce(0) { $0 + $1.output } }
    public var totalTokens: Int { usages.reduce(0) { $0 + $1.total } }
    public var confirmedTokens: Int { usages.filter { !$0.estimated }.reduce(0) { $0 + $1.total } }
    public var hasEstimatedUsage: Bool { usages.contains { $0.estimated || $0.partial } }
    public var cacheRate: Double? {
        guard !usages.isEmpty, inputTokens > 0,
            usages.allSatisfy({ !$0.estimated && !$0.partial && $0.cached != nil })
        else { return nil }
        return Double(usages.compactMap(\.cached).reduce(0, +)) / Double(inputTokens)
    }
}

public enum CompetitionStatus: String, Codable, Sendable {
    case running, completed, timeLimit, tokenLimit, userStopped, backgrounded, interrupted
}

public struct CompetitionResult: Codable, Identifiable, Equatable, Sendable {
    public var schemaVersion = 1
    public let id: UUID
    public let startedAt: Date
    public var updatedAt: Date
    public var finishedAt: Date?
    public var status = CompetitionStatus.running
    public let configuration: CompetitionConfiguration
    public let problems: [Problem]
    public let systemPrompt: String
    public var scoring: BattlefieldScoring?
    public var entrants: [EntrantResult]

    public init(configuration: CompetitionConfiguration, problems: [Problem], entrants: [Entrant]) {
        id = UUID()
        startedAt = .now
        updatedAt = startedAt
        self.configuration = configuration
        self.problems = problems
        systemPrompt =
            BattlefieldPrompt.rules
            + (configuration.extraPrompt.isEmpty
                ? "" : "\n\n## Additional instructions\n\n" + configuration.extraPrompt)
        scoring = .coverageAndLengthV1
        self.entrants = entrants.map { EntrantResult(entrant: $0, problems: problems) }
    }

    public var totalTokens: Int { entrants.reduce(0) { $0 + $1.totalTokens } }
    public var scoringPolicy: BattlefieldScoring { scoring ?? .legacyAccepted }
    public func score(for answer: ProblemAnswer) -> Double {
        guard let problem = problems.first(where: { $0.id == answer.id }) else { return 0 }
        return scoringPolicy.score(answer, problem: problem)
    }
    public func score(for entrant: EntrantResult) -> Double {
        let byID = Dictionary(uniqueKeysWithValues: problems.map { ($0.id, $0) })
        let total = entrant.answers.reduce(0.0) { total, answer in
            total + (byID[answer.id].map { scoringPolicy.score(answer, problem: $0) } ?? 0)
        }
        return (total * 100).rounded() / 100
    }
    public var maximumScore: Double { Double(problems.count) * 100 }
    public func scoreFraction(for entrant: EntrantResult) -> Double {
        guard maximumScore > 0 else { return 0 }
        return min(1, max(0, score(for: entrant) / maximumScore))
    }
    public var ranked: [EntrantResult] {
        let scores = Dictionary(uniqueKeysWithValues: entrants.map { ($0.id, score(for: $0)) })
        return entrants.sorted {
            if scores[$0.id] != scores[$1.id] { return scores[$0.id]! > scores[$1.id]! }
            if scoringPolicy == .legacyAccepted {
                if $0.bytes != $1.bytes { return $0.bytes < $1.bytes }
            } else if $0.totalTokens != $1.totalTokens {
                return $0.totalTokens < $1.totalTokens
            }
            let left = $0.finishedAt ?? .distantFuture
            let right = $1.finishedAt ?? .distantFuture
            if left != right { return left < right }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    public mutating func finish(_ reason: CompetitionStatus) {
        status = reason
        finishedAt = .now
        updatedAt = .now
        for e in entrants.indices {
            for p in entrants[e].answers.indices {
                if [.queued, .requesting, .judging].contains(entrants[e].answers[p].status) {
                    entrants[e].answers[p].status = .cancelled
                    if let a = entrants[e].answers[p].attempts.indices.last,
                        entrants[e].answers[p].attempts[a].finishedAt == nil
                    {
                        entrants[e].answers[p].attempts[a].usage.partial = true
                        entrants[e].answers[p].attempts[a].finishedAt = .now
                    }
                }
            }
        }
    }
}

public enum BattlefieldError: String, Error, LocalizedError, Sendable {
    case invalidEndpoint, invalidConfiguration, invalidParameters, missingKey, invalidResponse,
        responseTooLarge, redirected, storageCorrupt, alreadyRunning
    public var errorDescription: String? { rawValue }
}
