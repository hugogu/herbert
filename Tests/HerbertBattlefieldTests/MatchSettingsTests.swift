import Foundation
import HerbertCore
import XCTest

@testable import HerbertBattlefield

final class MatchSettingsTests: XCTestCase, @unchecked Sendable {
    private func problems() throws -> [Problem] {
        let first = try XCTUnwrap(ProblemCatalog.bundled().first)
        return [
            first, Problem(id: 90002, title: "Independent problem", author: "Test", byteLimit: 1, rows: first.rows),
        ]
    }
    private func participants() -> [CompetitionParticipant] {
        [4096, 8192].enumerated().map { index, legacy in
            var preset = ModelPreset(model: AIModel(id: "model-\(index)"))
            preset.parameters.maxOutputTokens = legacy
            return CompetitionParticipant(
                entrant: Entrant(provider: ProviderConfiguration(kind: .compatible), preset: preset), apiKey: "fixture")
        }
    }
    func testDefaultsAndLegacyMatchConfigurationRoundTrip() throws {
        let defaults = CompetitionConfiguration()
        XCTAssertFalse(defaults.timeLimitEnabled)
        XCTAssertFalse(defaults.problemTokenLimitEnabled)
        XCTAssertEqual(defaults.attemptsPerProblem, 3)
        let encoded = try JSONEncoder().encode(defaults)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNil(object["mode"])
        XCTAssertNil(object["tokenBudgetScope"])
        let old = try JSONDecoder().decode(
            CompetitionConfiguration.self,
            from: Data(
                #"{"mode":"tokenLimited","timeLimitSeconds":600,"tokenLimit":12345,"tokenBudgetScope":"perModel","attemptsPerProblem":2,"extraPrompt":"old"}"#
                    .utf8))
        XCTAssertEqual(old.legacyMode, .tokenLimited)
        XCTAssertEqual(old.legacyTokenLimit, 12345)
        XCTAssertEqual(old.legacyTokenBudgetScope, .perModel)
        XCTAssertEqual(try JSONDecoder().decode(CompetitionConfiguration.self, from: JSONEncoder().encode(old)), old)
        XCTAssertNil(old.forNewMatch().legacyMode)
        XCTAssertEqual(old.forNewMatch().attemptsPerProblem, 2)
        let timed = try JSONDecoder().decode(
            CompetitionConfiguration.self, from: Data(#"{"mode":"timed","timeLimitSeconds":12}"#.utf8))
        XCTAssertTrue(timed.timeLimitEnabled)
        XCTAssertEqual(timed.timeLimitSeconds, 12)
    }
    func testOutputExhaustionCancelsRetriesButOtherProblemsAndModelsContinue() async throws {
        let client = BudgetClient(kind: .length)
        let result = try await BattlefieldEngine(client: client).run(
            configuration: CompetitionConfiguration(), problems: problems(), participants: participants()
        ) { _ in }
        XCTAssertEqual(result.status, .completed)
        XCTAssertTrue(
            result.entrants.allSatisfy { $0.answers[0].status == .burnout && $0.answers[1].status == .solved })
        XCTAssertTrue(
            result.entrants.allSatisfy {
                $0.answers[0].attempts.count == 1 && $0.answers[0].attempts[0].evaluation == nil
            })
        let requests = await client.requests
        XCTAssertEqual(requests.count, 4)
        XCTAssertTrue(requests.allSatisfy { $0.maxOutputTokens == nil })
    }
    func testStreamingProblemLimitCancelsOnlyCurrentRequestAndResetsForNextProblem() async throws {
        let client = BudgetClient(kind: .streamLimit)
        var configuration = CompetitionConfiguration()
        configuration.problemTokenLimitEnabled = true
        configuration.problemTokenLimit = 10_000
        let result = try await BattlefieldEngine(client: client).run(
            configuration: configuration, problems: problems(), participants: participants()
        ) { _ in }
        XCTAssertEqual(result.status, .completed)
        XCTAssertTrue(
            result.entrants.allSatisfy { $0.answers[0].status == .burnout && $0.answers[1].status == .solved })
        XCTAssertTrue(
            result.entrants.allSatisfy {
                $0.answers[0].attempts[0].reasoning?.content == "Partial plan"
                    && $0.answers[0].attempts[0].usage.partial
            })
        let cancelled = await client.cancelled
        XCTAssertEqual(cancelled, 2)
        let requests = await client.requests
        XCTAssertEqual(requests.count, 4)
        XCTAssertEqual(requests[0].maxOutputTokens, requests[1].maxOutputTokens)
        XCTAssertNotNil(requests[0].maxOutputTokens)
        XCTAssertTrue(requests.allSatisfy { ($0.maxOutputTokens ?? 0) > 0 && ($0.maxOutputTokens ?? Int.max) < 10_000 })
    }
    func testRetryBudgetIsCumulativeWithinOneProblem() async throws {
        let client = BudgetClient(kind: .retry)
        var configuration = CompetitionConfiguration()
        configuration.problemTokenLimitEnabled = true
        configuration.problemTokenLimit = 50_000
        configuration.attemptsPerProblem = 2
        _ = try await BattlefieldEngine(client: client).run(
            configuration: configuration, problems: [problems()[0]], participants: [participants()[0]]
        ) { _ in }
        let requests = await client.requests
        XCTAssertEqual(requests.count, 2)
        let first = try XCTUnwrap(requests[0].maxOutputTokens)
        let second = try XCTUnwrap(requests[1].maxOutputTokens)
        XCTAssertLessThan(second, first - 99)
    }
    func testProviderAwareReasoningDefaultsAndExplicitOverrides() throws {
        var provider = ProviderConfiguration(kind: .openRouter)
        var preset = ModelPreset(
            model: AIModel(id: "m", supportedParameters: ["reasoning"], supportedReasoningEfforts: ["xhigh", "high"]))
        var entrant = Entrant(provider: provider, preset: preset)
        let defaults = ReasoningDefaults.parameters(for: entrant)["reasoning"] as? [String: Any]
        XCTAssertEqual(defaults?["effort"] as? String, "xhigh")
        XCTAssertEqual(defaults?["enabled"] as? Bool, true)
        let overridden = ReasoningDefaults.applying(to: ["reasoning": ["enabled": false]], entrant: entrant)
        XCTAssertEqual((overridden["reasoning"] as? [String: Any])?["enabled"] as? Bool, false)
        XCTAssertNil((overridden["reasoning"] as? [String: Any])?["effort"])
        preset.parameters.automaticReasoning = false
        XCTAssertTrue(ReasoningDefaults.parameters(for: Entrant(provider: provider, preset: preset)).isEmpty)
        provider.kind = .siliconFlow
        preset.parameters.automaticReasoning = true
        preset.model.supportedReasoningEfforts = nil
        preset.model.id = "deepseek-ai/DeepSeek-V4-Flash"
        entrant = Entrant(provider: provider, preset: preset)
        XCTAssertEqual(ReasoningDefaults.parameters(for: entrant)["enable_thinking"] as? Bool, true)
        XCTAssertEqual(ReasoningDefaults.parameters(for: entrant)["reasoning_effort"] as? String, "max")
        preset.model.id = "another-model"
        let thinkingOnly = ReasoningDefaults.parameters(for: Entrant(provider: provider, preset: preset))
        XCTAssertEqual(thinkingOnly["enable_thinking"] as? Bool, true)
        XCTAssertNil(thinkingOnly["reasoning_effort"])
        let unknown = Entrant(
            provider: ProviderConfiguration(kind: .compatible), preset: ModelPreset(model: AIModel(id: "unknown")))
        XCTAssertTrue(ReasoningDefaults.parameters(for: unknown).isEmpty)
        for id in ["models/gemini-2.5-flash", "gemini-3.1-pro"] {
            let gemini = Entrant(
                provider: ProviderConfiguration(kind: .gemini), preset: ModelPreset(model: AIModel(id: id)))
            XCTAssertEqual(ReasoningDefaults.parameters(for: gemini)["reasoning_effort"] as? String, "high")
            XCTAssertEqual(
                ReasoningDefaults.applying(to: ["reasoning_effort": "low"], entrant: gemini)["reasoning_effort"]
                    as? String,
                "low")
            var disabled = gemini.preset
            disabled.parameters.automaticReasoning = false
            XCTAssertTrue(
                ReasoningDefaults.parameters(for: Entrant(provider: provider, preset: disabled)).isEmpty)
        }
        let olderGemini = Entrant(
            provider: ProviderConfiguration(kind: .gemini), preset: ModelPreset(model: AIModel(id: "gemini-2.0-flash")))
        XCTAssertTrue(ReasoningDefaults.parameters(for: olderGemini).isEmpty)
    }
}

private actor BudgetClient: AIClient {
    enum Kind: Sendable { case length, streamLimit, retry }
    let kind: Kind
    var requests: [AICompletionRequest] = []
    var cancelled = 0
    init(kind: Kind) { self.kind = kind }
    func models(provider: ProviderConfiguration, apiKey: String) async throws -> [AIModel] { [] }
    func complete(_ request: AICompletionRequest, progress: @escaping @Sendable (AIProgress) async -> Void) async throws
        -> AIReply
    {
        requests.append(request)
        let first = request.messages[1].content.contains("ID 10001")
        if first && kind == .length {
            return AIReply(
                text: "", usage: TokenUsage(input: 100, output: 100), finishReason: "length",
                reasoning: AIReasoning(content: "Partial plan"))
        }
        if first && kind == .streamLimit {
            await progress(
                AIProgress(
                    text: "", usage: TokenUsage(input: 100, output: 9900),
                    reasoning: AIReasoning(content: "Partial plan")))
            do { try await Task.sleep(for: .seconds(30)) } catch {
                cancelled += 1
                await progress(AIProgress(text: "Late output", usage: TokenUsage(input: 1, output: 1)))
                throw error
            }
        }
        let text = kind == .retry && request.messages.count == 2 ? "z" : "```h\ns\n```"
        return AIReply(text: text, usage: TokenUsage(input: 100, output: 1))
    }
}
