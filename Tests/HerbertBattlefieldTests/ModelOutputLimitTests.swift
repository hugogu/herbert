import Foundation
import HerbertCore
import XCTest

@testable import HerbertBattlefield

final class ModelOutputLimitTests: XCTestCase {
    private let gatewayRejection =
        #"{"error":{"code":"400","message":"Param Incorrect","param":"max_tokens is too large: 390861. This model supports at most 131072 completion tokens, whereas you provided 390861.","type":""}}"#

    private func problems() throws -> [Problem] {
        let first = try XCTUnwrap(ProblemCatalog.bundled().first)
        return [first, Problem(id: 90002, title: "Same board", author: "Test", byteLimit: 1, rows: first.rows)]
    }

    private func participant(_ model: AIModel = AIModel(id: "m")) -> CompetitionParticipant {
        CompetitionParticipant(
            entrant: Entrant(provider: ProviderConfiguration(kind: .compatible), preset: ModelPreset(model: model)),
            apiKey: "fixture")
    }

    private func budget(_ tokens: Int) -> CompetitionConfiguration {
        var configuration = CompetitionConfiguration()
        configuration.problemTokenLimitEnabled = true
        configuration.problemTokenLimit = tokens
        return configuration
    }

    func testDiscoveryReadsPublishedLimitsUnderProviderSpecificNames() throws {
        let data = Data(
            """
            {"data":[
            {"id":"deepseek","object":"model","owned_by":"deepseek","context_window":1048576,"max_output_tokens":393216},
            {"id":"groq","context_window":131072,"max_completion_tokens":32768},
            {"id":"mistral","max_context_length":131072},
            {"id":"vllm","max_model_len":32768},
            {"id":"openrouter","context_length":200000,"top_provider":{"max_completion_tokens":64000},
            "max_output_tokens":1},
            {"id":"invalid","context_length":0,"max_output_tokens":-5}]}
            """.utf8)
        let models = Dictionary(
            uniqueKeysWithValues: try OpenAICompatibleClient.decodeModels(data).map { ($0.id, $0) })
        XCTAssertEqual(models["deepseek"]?.contextLength, 1_048_576)
        XCTAssertEqual(models["deepseek"]?.maximumOutputTokens, 393_216)
        XCTAssertEqual(models["groq"]?.contextLength, 131_072)
        XCTAssertEqual(models["groq"]?.maximumOutputTokens, 32_768)
        XCTAssertEqual(models["mistral"]?.contextLength, 131_072)
        XCTAssertEqual(models["vllm"]?.contextLength, 32_768)
        XCTAssertNil(models["vllm"]?.maximumOutputTokens)
        XCTAssertEqual(models["openrouter"]?.contextLength, 200_000)
        XCTAssertEqual(models["openrouter"]?.maximumOutputTokens, 64_000)
        XCTAssertNil(models["invalid"]?.contextLength)
        XCTAssertNil(models["invalid"]?.maximumOutputTokens)
    }

    func testRejectionsStateTheLargestAcceptedOutputCap() {
        let cases: [(detail: String, limit: Int?)] = [
            (gatewayRejection, 131_072),
            (
                #"{"error":{"code":"invalid_request_error","message":"Invalid max_tokens value, the valid range of max_tokens is [1, 393216] (request_id: dddf6eb3-40f2-4e4a-a71c-6907024c245f)","param":null,"type":"invalid_request_error"}}"#,
                393_216
            ),
            (
                #"{"type":"error","error":{"type":"invalid_request_error","message":"max_tokens: 100000 > 64000, which is the maximum allowed number of output tokens for claude-opus-4-1-20250805"}}"#,
                64_000
            ),
            (
                #"[{"error":{"code":400,"message":"Unable to submit request because it has a maxOutputTokens value of 100000 but the supported range is from 1 (inclusive) to 65537 (exclusive). Update the value and try again.","status":"INVALID_ARGUMENT"}}]"#,
                65_536
            ),
            (
                #"{"error":{"message":"`max_tokens` must be less than or equal to `32768`, the maximum value for `max_tokens` is less than the `context_window` for this model","type":"invalid_request_error"}}"#,
                32_768
            ),
            ("max_completion_tokens must be <= 8,192", 8192),
            (#"{"error":{"message":"assistant content is empty at index 2","type":"invalid_request_error"}}"#, nil),
            (
                #"{"error":{"code":402,"message":"This request requires more credits, or fewer max_tokens. You requested up to 65536 tokens, but can only afford 1234."}}"#,
                nil
            ),
            (
                #"{"error":{"message":"This model's maximum context length is 131072 tokens. However, you requested 140000 tokens."}}"#,
                nil
            ),
            // Retained model output never counts as a provider statement.
            (
                #"{"choices":[{"message":{"content":"max_tokens is at most 10"}}],"error":{"message":"unsupported model"}}"#,
                nil
            ),
            ("", nil),
        ]
        for item in cases {
            XCTAssertEqual(ProviderDiagnostics.outputTokenLimit(in: item.detail), item.limit, item.detail)
        }
        XCTAssertNil(ProviderDiagnostics.outputTokenLimit(in: nil))
    }

    func testRequestsNeverExceedTheModelLimitsWithOrWithoutABudget() async throws {
        let models: [(model: AIModel, accepted: ClosedRange<Int>)] = [
            (AIModel(id: "declared", contextLength: 1_048_576, maximumOutputTokens: 131_072), 131_072...131_072),
            (AIModel(id: "context-only", contextLength: 32_768), 1...32_767),
        ]
        for configuration in [budget(400_000), CompetitionConfiguration()] {
            for item in models {
                let client = ScriptedLimitClient([])
                let result = try await BattlefieldEngine(client: client).run(
                    configuration: configuration, problems: problems(), participants: [participant(item.model)]
                ) { _ in }
                XCTAssertEqual(result.entrants[0].answers.map(\.status), [.solved, .solved])
                let caps = await client.caps
                XCTAssertEqual(caps.count, 2)
                XCTAssertTrue(caps.allSatisfy { item.accepted.contains($0 ?? 0) }, "\(item.model.id): \(caps)")
            }
        }
    }

    func testUnlimitedRequestAsksForEverythingAndKeepsTheStatedMaximum() async throws {
        // DeepSeek defaults to 64K in thinking mode when max_tokens is omitted, but accepts up to 393,216.
        let rejection = AIHTTPError(
            status: 400,
            providerResponse:
                #"{"error":{"message":"Invalid max_tokens value, the valid range of max_tokens is [1, 393216]","type":"invalid_request_error"}}"#
        )
        let client = ScriptedLimitClient([.reject(rejection)])
        let result = try await BattlefieldEngine(client: client).run(
            configuration: CompetitionConfiguration(), problems: problems(), participants: [participant()]
        ) { _ in }
        let caps = await client.caps
        XCTAssertEqual(caps, [BattlefieldEngine.unlimitedOutputCap, 393_216, 393_216])
        XCTAssertEqual(result.entrants[0].answers.map(\.status), [.solved, .solved])
        XCTAssertEqual(result.entrants[0].answers[0].attempts.map(\.requestedMaxOutputTokens), [393_216])
    }

    func testGuessedCapFallsBackToTheProviderDefaultWhenNoMaximumIsStated() async throws {
        let unstated = AIHTTPError(status: 400, providerResponse: #"{"error":{"message":"max_tokens 参数非法"}}"#)
        // Chat Completions can omit the cap; Messages requires one and uses 65,536.
        for (kind, fallback) in [(ProviderKind.compatible, nil), (.anthropic, 65_536)] as [(ProviderKind, Int?)] {
            let client = ScriptedLimitClient([.reject(unstated)])
            let entrant = Entrant(
                provider: ProviderConfiguration(kind: kind), preset: ModelPreset(model: AIModel(id: "m")))
            let result = try await BattlefieldEngine(client: client).run(
                configuration: CompetitionConfiguration(), problems: problems(),
                participants: [CompetitionParticipant(entrant: entrant, apiKey: "fixture")]
            ) { _ in }
            let caps = await client.caps
            XCTAssertEqual(caps, [BattlefieldEngine.unlimitedOutputCap, fallback, fallback], "\(kind)")
            XCTAssertEqual(result.entrants[0].answers.map(\.status), [.solved, .solved])
            XCTAssertEqual(result.entrants[0].answers[0].attempts.map(\.requestedMaxOutputTokens), [fallback])
        }
        // A request the provider rejects either way still fails, after one more try.
        let client = ScriptedLimitClient([.reject(unstated), .reject(unstated)])
        let result = try await BattlefieldEngine(client: client).run(
            configuration: CompetitionConfiguration(), problems: problems(), participants: [participant()]
        ) { _ in }
        let caps = await client.caps
        XCTAssertEqual(caps, [BattlefieldEngine.unlimitedOutputCap, nil])
        XCTAssertEqual(result.entrants[0].answers[0].status, .error)
    }

    func testRejectedCapIsResentWithinTheStatedLimitAndKeptForTheMatch() async throws {
        let rejection = AIHTTPError(
            status: 200, providerResponse: gatewayRejection,
            partialReply: AIReply(text: "", usage: TokenUsage(), finishReason: "error"))
        let client = ScriptedLimitClient([.reject(rejection)])
        let result = try await BattlefieldEngine(client: client).run(
            configuration: budget(400_000), problems: problems(), participants: [participant()]
        ) { _ in }
        let caps = await client.caps
        XCTAssertEqual(caps.count, 3)
        XCTAssertGreaterThan(try XCTUnwrap(caps[0]), 131_072)
        XCTAssertEqual(Array(caps.dropFirst()), [131_072, 131_072])
        XCTAssertEqual(result.entrants[0].answers.map(\.status), [.solved, .solved])
        let attempts = result.entrants[0].answers[0].attempts
        XCTAssertEqual(attempts.count, 1)
        XCTAssertEqual(attempts[0].requestedMaxOutputTokens, 131_072)
        XCTAssertNil(attempts[0].error)
        XCTAssertNil(result.entrants[0].error)
    }

    func testOtherRejectionsAndPartialOutputAreNotResent() async throws {
        let declared = AIModel(id: "declared", maximumOutputTokens: 131_072)
        let failures: [(error: AIHTTPError, model: AIModel)] = [
            // Only a guessed cap falls back to the provider default.
            (
                AIHTTPError(
                    status: 400, providerResponse: #"{"error":{"message":"assistant content is empty at index 2"}}"#),
                declared
            ),
            (
                AIHTTPError(status: 402, providerResponse: #"{"error":{"message":"max_tokens must be at most 1000"}}"#),
                AIModel(id: "m")
            ),
            (
                AIHTTPError(
                    status: 200, providerResponse: gatewayRejection,
                    partialReply: AIReply(text: "partial", usage: TokenUsage(), finishReason: "error")),
                AIModel(id: "m")
            ),
        ]
        for failure in failures {
            let client = ScriptedLimitClient([.reject(failure.error)])
            let result = try await BattlefieldEngine(client: client).run(
                configuration: budget(400_000), problems: problems(), participants: [participant(failure.model)]
            ) { _ in }
            let caps = await client.caps
            XCTAssertEqual(caps.count, 1, "\(failure.error.status)")
            XCTAssertNotEqual(result.entrants[0].answers[0].status, .solved)
            XCTAssertNotNil(result.entrants[0].answers[0].attempts[0].error)
        }
    }

    func testOverloadDoesNotTurnAGuessedCapIntoTheProviderDefault() async throws {
        let overloaded = AIHTTPError(
            status: 200,
            providerResponse:
                #"{"error":{"code":503,"message":"This model is currently experiencing high demand. Please try again later."}}"#,
            partialReply: AIReply(text: "", usage: TokenUsage(), finishReason: "error"))
        let client = ScriptedLimitClient([.reject(overloaded)])
        let result = try await BattlefieldEngine(client: client, retrySleep: { _ in }).run(
            configuration: CompetitionConfiguration(), problems: Array(try problems().prefix(1)),
            participants: [participant()]
        ) { _ in }
        let caps = await client.caps
        XCTAssertEqual(caps, [BattlefieldEngine.unlimitedOutputCap, BattlefieldEngine.unlimitedOutputCap])
        XCTAssertEqual(result.entrants[0].answers[0].status, .solved)
    }

    func testStatedLimitIsKeptOnlyAfterTheProviderAcceptsIt() async throws {
        let rejection = AIHTTPError(
            status: 400, providerResponse: #"{"error":{"message":"max_tokens must be at most 1000"}}"#)
        let overloaded = AIHTTPError(status: 429, providerResponse: #"{"error":{"message":"busy"}}"#)
        let client = ScriptedLimitClient([.reject(rejection), .reject(overloaded)])
        let result = try await BattlefieldEngine(client: client, retrySleep: { _ in }).run(
            configuration: budget(400_000), problems: Array(try problems().prefix(1)), participants: [participant()]
        ) { _ in }
        let caps = await client.caps
        XCTAssertEqual(caps.count, 3)
        XCTAssertEqual(caps[1], 1000)
        // The next attempt asks for the remaining budget again rather than the unconfirmed limit.
        XCTAssertGreaterThan(try XCTUnwrap(caps[2]), 390_000)
        let answer = result.entrants[0].answers[0]
        XCTAssertEqual(answer.status, .solved)
        XCTAssertEqual(answer.attempts.map(\.requestedMaxOutputTokens), [1000, caps[2]])
        XCTAssertEqual(answer.attempts[0].error, "AI HTTP 429")
    }
}

private actor ScriptedLimitClient: AIClient {
    enum Step: Sendable { case reject(AIHTTPError) }
    private var steps: [Step]
    private(set) var caps: [Int?] = []
    init(_ steps: [Step]) { self.steps = steps }
    func models(provider: ProviderConfiguration, apiKey: String) async throws -> [AIModel] { [] }
    func complete(_ request: AICompletionRequest, progress: @escaping @Sendable (AIProgress) async -> Void) async throws
        -> AIReply
    {
        caps.append(request.maxOutputTokens)
        if !steps.isEmpty, case .reject(let error) = steps.removeFirst() { throw error }
        return AIReply(text: "```h\ns\n```", usage: TokenUsage(input: 100, output: 1, estimated: false))
    }
}
