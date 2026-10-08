import Foundation
import HerbertCore
import XCTest

@testable import HerbertBattlefield

@MainActor
final class BattlefieldTests: XCTestCase {
    private func first(_ count: Int = 1) throws -> [Problem] { Array(try ProblemCatalog.bundled().prefix(count)) }

    private func participants(_ count: Int = 2) -> [CompetitionParticipant] {
        (0..<count).map { index in
            let provider = ProviderConfiguration(kind: .compatible, name: "Provider \(index)")
            let preset = ModelPreset(model: AIModel(id: "model-\(index)"))
            return CompetitionParticipant(
                entrant: Entrant(provider: provider, preset: preset), apiKey: "test-secret-\(index)")
        }
    }

    func testNativeJudgeFormatBytesCollisionsAndFeedback() throws {
        let first = try first()[0]
        XCTAssertEqual(try BattlefieldJudge.extractProgram("```h\ns\n```"), "s")
        XCTAssertTrue(try BattlefieldJudge.evaluate("s", problem: first).accepted)
        let invalid = try BattlefieldJudge.evaluate("z", problem: first)
        XCTAssertFalse(invalid.accepted)
        XCTAssertTrue(invalid.feedback.contains("Rejected"))
        XCTAssertFalse(try BattlefieldJudge.evaluate("ss", problem: first).accepted)
        XCTAssertThrowsError(try BattlefieldJudge.extractProgram("```h\ns\n```\n```h\ns\n```"))
        XCTAssertThrowsError(try BattlefieldJudge.extractProgram("```python\nprint('s')\n```"))
        let corridor = try ProblemCatalog.bundled()[5]
        let blocked = try BattlefieldJudge.evaluate("s", problem: corridor)
        XCTAssertFalse(blocked.accepted)
        XCTAssertEqual(blocked.steps, 1)
        XCTAssertTrue(blocked.feedback.contains("Unlit targets"))
        XCTAssertTrue(try BattlefieldJudge.evaluate("rsslsslss", problem: corridor).accepted)
    }

    func testJudgeCancellationOfInfiniteProgram() async throws {
        let original = try first()[0]
        let problem = Problem(
            id: original.id, title: original.title, author: original.author,
            byteLimit: 100, rows: original.rows)
        let task = Task.detached { try BattlefieldJudge.evaluate("a:a\na", problem: problem) }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {} catch { XCTFail("\(error)") }
    }

    func testProviderEndpointsAndProtectedParameters() throws {
        var provider = ProviderConfiguration(kind: .openRouter)
        XCTAssertEqual(try provider.endpoint("models").absoluteString, "https://openrouter.ai/api/v1/models")
        provider.baseURL += "/"
        XCTAssertEqual(try provider.endpoint("chat/completions").path, "/api/v1/chat/completions")
        for url in ["http://example.com/v1", "https://key@example.com/v1", "https://example.com?api_key=x"] {
            provider.baseURL = url
            XCTAssertThrowsError(try provider.validated())
        }
        var parameters = ModelParameters()
        parameters.extraJSON = "{\"reasoning_effort\":\"high\",\"seed\":42}"
        XCTAssertNoThrow(try parameters.validated())
        for protected in ["model", "messages", "max_tokens", "stream", "api_key", "temperature"] {
            parameters.extraJSON = "{\"\(protected)\":1}"
            XCTAssertThrowsError(try parameters.validated())
        }
    }

    func testModelDiscoveryFiltersDuplicatesAndNonTextModels() throws {
        let data = Data(
            """
            {"data":[{"id":"b","name":"Bee","supported_parameters":["temperature"],
            "top_provider":{"max_completion_tokens":1024},"context_length":8192},
            {"id":"a"},{"id":"a"},{"id":"image","architecture":{"output_modalities":["image"]}}]}
            """.utf8)
        let models = try OpenAICompatibleClient.decodeModels(data)
        XCTAssertEqual(models.map(\.id), ["a", "b"])
        XCTAssertEqual(models[1].maximumOutputTokens, 1024)
        XCTAssertEqual(models[1].supportedParameters, ["temperature"])
        XCTAssertThrowsError(try OpenAICompatibleClient.decodeModels(Data("{}".utf8)))
    }

    func testUsageKeepsUnknownCacheDistinctFromZeroAndDoesNotDoubleCountReasoning() throws {
        let fallback = TokenUsage(input: 10, output: 20)
        let usage = OpenAICompatibleClient.decodeUsage(
            [
                "prompt_tokens": 100, "completion_tokens": 50, "total_tokens": 150,
                "prompt_tokens_details": ["cached_tokens": 80],
                "completion_tokens_details": ["reasoning_tokens": 30],
            ], fallback: fallback)
        XCTAssertEqual(usage.total, 150)
        XCTAssertEqual(usage.reasoning, 30)
        XCTAssertEqual(usage.cached, 80)
        XCTAssertFalse(usage.estimated)
        let missing = OpenAICompatibleClient.decodeUsage(
            ["prompt_tokens": 100, "completion_tokens": 50], fallback: fallback)
        XCTAssertNil(missing.cached)
        let legacy = OpenAICompatibleClient.decodeUsage(
            [
                "prompt_tokens": 100, "completion_tokens": 50, "prompt_cache_hit_tokens": 0,
            ], fallback: fallback)
        XCTAssertEqual(legacy.cached, 0)
    }

    func testSSEAccumulatesReasoningAndCumulativeUsageOnce() throws {
        var stream = ChatStreamAccumulator(messages: [AIMessage(role: "user", content: "test")])
        try stream.consume("{\"choices\":[{\"delta\":{\"reasoning_content\":\"thinking\"}}]}")
        try stream.consume("{\"choices\":[{\"delta\":{\"content\":\"s\"},\"finish_reason\":\"stop\"}]}")
        try stream.consume(
            "{\"choices\":[],\"usage\":{\"prompt_tokens\":10,\"completion_tokens\":8,\"total_tokens\":18}}")
        try stream.consume(
            "{\"choices\":[],\"usage\":{\"prompt_tokens\":10,\"completion_tokens\":8,\"total_tokens\":18}}")
        try stream.consume("[DONE]")
        XCTAssertEqual(stream.text, "s")
        XCTAssertEqual(stream.usage.total, 18)
        XCTAssertEqual(stream.reasoningBytes, 8)
        XCTAssertTrue(stream.done)
        XCTAssertThrowsError(try stream.consume("{\"error\":{\"message\":\"private\"}}"))
    }

    func testParallelEntrantsUseIdenticalPromptsAndNativeFeedback() async throws {
        let client = ScriptedAI(behavior: .retry)
        let engine = BattlefieldEngine(client: client)
        var config = CompetitionConfiguration()
        config.mode = .timed
        let result = try await engine.run(configuration: config, problems: first(), participants: participants()) { _ in
        }
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.entrants.map { result.score(for: $0) }, [80, 80])
        XCTAssertEqual(result.entrants[0].answers[0].attempts.count, 2)
        XCTAssertEqual(result.entrants[0].answers[0].attempts[1].program, "s")
        let requests = await client.requests
        XCTAssertEqual(requests[0].messages, requests[1].messages)
        XCTAssertTrue(requests[2].messages.last!.content.contains("Rejected"))
        let maximumParallel = await client.maximumParallel
        XCTAssertGreaterThanOrEqual(maximumParallel, 2)
        let data = try JSONEncoder().encode(result)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("test-secret"))
        XCTAssertEqual(result.entrants[0].totalTokens, 42)
        XCTAssertEqual(result.entrants[0].cacheRate, 0.5)
    }

    func testRetriesAreBoundedAndInvalidProgramsNeverEarnPoints() async throws {
        let client = ScriptedAI(behavior: .wrong)
        let engine = BattlefieldEngine(client: client)
        var config = CompetitionConfiguration()
        config.mode = .bestEffort
        config.attemptsPerProblem = 2
        let result = try await engine.run(configuration: config, problems: first(), participants: participants(1)) {
            _ in
        }
        XCTAssertEqual(result.entrants[0].answers[0].attempts.count, 2)
        XCTAssertEqual(result.entrants[0].answers[0].status, .failed)
        XCTAssertEqual(result.score(for: result.entrants[0]), 0)
    }

    func testBestEffortFirstFinishedEntrantCancelsOthersAfterSuccessOrExhaustedAttempts() async throws {
        for behavior in [ScriptedAI.Behavior.race, .raceWrong] {
            let client = ScriptedAI(behavior: behavior)
            let engine = BattlefieldEngine(client: client)
            var configuration = CompetitionConfiguration()
            configuration.mode = .bestEffort
            configuration.attemptsPerProblem = 2
            let started = ContinuousClock.now
            let result = try await engine.run(
                configuration: configuration, problems: first(), participants: participants()
            ) { _ in }
            XCTAssertLessThan(ContinuousClock.now - started, .seconds(2))
            XCTAssertEqual(result.status, .completed)
            XCTAssertEqual(result.entrants[0].answers[0].status, behavior == .race ? .solved : .failed)
            XCTAssertEqual(result.score(for: result.entrants[0]), behavior == .race ? 80 : 0)
            XCTAssertEqual(result.entrants[1].answers[0].status, .cancelled)
            XCTAssertEqual(result.score(for: result.entrants[1]), 0)
            let cancelled = await client.cancelled
            XCTAssertEqual(cancelled, 1)
        }
    }

    func testTimedCompetitionCancelsAllInflightRequests() async throws {
        let client = ScriptedAI(behavior: .wait)
        let engine = BattlefieldEngine(client: client)
        var config = CompetitionConfiguration()
        config.timeLimitSeconds = 0.05
        let start = ContinuousClock.now
        let result = try await engine.run(configuration: config, problems: first(2), participants: participants()) {
            _ in
        }
        XCTAssertEqual(result.status, .timeLimit)
        XCTAssertLessThan(ContinuousClock.now - start, .seconds(2))
        XCTAssertTrue(result.entrants.flatMap(\.answers).allSatisfy { $0.status == .cancelled })
        let cancelled = await client.cancelled
        XCTAssertEqual(cancelled, 2)
    }

    func testUserStopCancelsWithoutAcceptingLateAnswers() async throws {
        let client = ScriptedAI(behavior: .wait)
        let engine = BattlefieldEngine(client: client)
        var config = CompetitionConfiguration()
        config.mode = .bestEffort
        let problems = try first()
        let entrants = participants()
        let run = Task {
            try await engine.run(configuration: config, problems: problems, participants: entrants) { _ in }
        }
        while await client.requests.count < 2 { try await Task.sleep(for: .milliseconds(5)) }
        await engine.stop()
        let result = try await run.value
        XCTAssertEqual(result.status, .userStopped)
        XCTAssertEqual(result.entrants.reduce(0) { $0 + result.score(for: $1) }, 0)
        XCTAssertTrue(result.entrants.flatMap(\.usages).allSatisfy(\.partial))
    }

    func testCompletedAnswerAtExactTokenLimitCountsThenStops() async throws {
        let client = ScriptedAI(behavior: .exactBudget)
        let engine = BattlefieldEngine(client: client)
        var config = CompetitionConfiguration()
        config.mode = .tokenLimited
        config.tokenLimit = 2000
        let result = try await engine.run(configuration: config, problems: first(2), participants: participants(1)) {
            _ in
        }
        XCTAssertEqual(result.status, .tokenLimit)
        XCTAssertEqual(result.score(for: result.entrants[0]), 80)
        XCTAssertEqual(result.totalTokens, 2000)
        XCTAssertEqual(result.entrants[0].answers[1].status, .cancelled)
    }

    func testPerModelBudgetsDoNotStopOtherEntrants() async throws {
        let client = ScriptedAI(behavior: .exactBudget)
        let engine = BattlefieldEngine(client: client)
        var config = CompetitionConfiguration()
        config.mode = .tokenLimited
        config.tokenBudgetScope = .perModel
        config.tokenLimit = 2000
        let result = try await engine.run(configuration: config, problems: first(2), participants: participants()) {
            _ in
        }
        XCTAssertEqual(result.status, .tokenLimit)
        XCTAssertEqual(result.entrants.map { result.score(for: $0) }, [80, 80])
        XCTAssertEqual(result.totalTokens, 4000)
    }

    func testBudgetTooSmallDoesNotSendRequests() async throws {
        let client = ScriptedAI(behavior: .correct)
        let engine = BattlefieldEngine(client: client)
        var config = CompetitionConfiguration()
        config.mode = .tokenLimited
        config.tokenLimit = 1
        let result = try await engine.run(configuration: config, problems: first(), participants: participants()) { _ in
        }
        XCTAssertEqual(result.status, .tokenLimit)
        let requestCount = await client.requests.count
        XCTAssertEqual(requestCount, 0)
    }

    func testProviderFailureStopsOnlyItsEntrantAndDoesNotLeakErrorBody() async throws {
        let client = ScriptedAI(behavior: .providerFailure)
        let engine = BattlefieldEngine(client: client)
        var config = CompetitionConfiguration()
        config.mode = .bestEffort
        let result = try await engine.run(configuration: config, problems: first(2), participants: participants()) {
            _ in
        }
        XCTAssertEqual(result.entrants[0].answers[0].status, .error)
        XCTAssertEqual(result.entrants[0].answers[1].status, .cancelled)
        XCTAssertEqual(result.entrants[1].answers[0].status, .solved)
        XCTAssertEqual(result.entrants[0].error, "AI HTTP 401")
    }

    func testSettingsHistoryPersistenceRecoveryAndCorruptionProtection() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LocalBattlefieldRepository(directory: directory)
        XCTAssertTrue(try repository.loadSettings().providers.isEmpty)
        var settings = BattlefieldSettings()
        var provider = ProviderConfiguration(kind: .siliconFlow)
        provider.presets = [ModelPreset(model: AIModel(id: "fixture"))]
        settings.providers = [provider]
        try repository.saveSettings(settings)
        XCTAssertEqual(try repository.loadSettings().providers, settings.providers)
        var result = CompetitionResult(
            configuration: settings.competition, problems: try first(),
            entrants: participants().map(\.entrant))
        result.finish(.userStopped)
        try repository.saveResult(result)
        let restored = try repository.loadResult(result.id)
        XCTAssertEqual(restored.id, result.id)
        XCTAssertEqual(restored.entrants, result.entrants)
        XCTAssertEqual(restored.problems, result.problems)
        XCTAssertEqual(restored.status, result.status)
        XCTAssertEqual(
            restored.startedAt.timeIntervalSince1970, result.startedAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(try repository.summaries().map(\.id), [result.id])
        try FileManager.default.removeItem(at: directory.appendingPathComponent("history/index.json"))
        XCTAssertEqual(try repository.summaries().map(\.id), [result.id])
        let url = directory.appendingPathComponent("providers.json")
        try Data("corrupt-but-preserve".utf8).write(to: url)
        XCTAssertThrowsError(try repository.loadSettings())
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "corrupt-but-preserve")
    }

    func testOversizedSettingsCannotReplaceReadableSettings() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LocalBattlefieldRepository(directory: directory)
        let original = BattlefieldSettings()
        try repository.saveSettings(original)
        var oversized = original
        var provider = ProviderConfiguration(kind: .compatible)
        provider.models = [AIModel(id: "m", name: String(repeating: "x", count: 8 * 1024 * 1024))]
        oversized.providers = [provider]
        XCTAssertThrowsError(try repository.saveSettings(oversized))
        XCTAssertTrue(try repository.loadSettings().providers.isEmpty)
    }
}

actor ScriptedAI: AIClient {
    enum Behavior: Sendable { case correct, retry, wrong, wait, exactBudget, providerFailure, race, raceWrong }
    let behavior: Behavior
    var requests: [AICompletionRequest] = []
    var parallel = 0
    var maximumParallel = 0
    var cancelled = 0
    init(behavior: Behavior) { self.behavior = behavior }
    func models(provider: ProviderConfiguration, apiKey: String) async throws -> [AIModel] { [] }
    func complete(
        _ request: AICompletionRequest,
        progress: @escaping @Sendable (AIProgress) async -> Void
    ) async throws -> AIReply {
        requests.append(request)
        parallel += 1
        maximumParallel = max(parallel, maximumParallel)
        defer { parallel -= 1 }
        let slowRacer =
            [.race, .raceWrong].contains(behavior) && request.participant.entrant.preset.model.id == "model-1"
        do { try await Task.sleep(for: behavior == .wait || slowRacer ? .seconds(30) : .milliseconds(20)) } catch {
            cancelled += 1
            throw error
        }
        if behavior == .providerFailure && request.participant.entrant.preset.model.id == "model-0" {
            throw AIHTTPError(status: 401)
        }
        let wrong = behavior == .wrong || behavior == .raceWrong || (behavior == .retry && request.messages.count == 2)
        let text = wrong ? "z" : "```h\ns\n```"
        let usage = TokenUsage(input: behavior == .exactBudget ? 1999 : 20, output: 1, cached: 10, estimated: false)
        await progress(AIProgress(text: text, usage: usage, isFinal: true))
        return AIReply(text: text, usage: usage)
    }
}
