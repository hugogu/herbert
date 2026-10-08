import Foundation
import HerbertCore
import XCTest

@testable import HerbertBattlefield

final class ReasoningRetryTests: XCTestCase, @unchecked Sendable {
    func testReasoningOnlyAttemptKeepsFullTextAndRetriesWithoutEmptyAssistant() async throws {
        let reasoning = String(repeating: "plan ", count: 14_000)
        let client = RetryClient(
            first: AIReply(
                text: "", usage: TokenUsage(input: 100, output: 4096, reasoning: 4096, estimated: false),
                finishReason: "length", reasoning: AIReasoning(content: reasoning)))
        let result = try await run(client)
        let attempts = try XCTUnwrap(result.entrants.first?.answers.first?.attempts)
        XCTAssertEqual(attempts.count, 2)
        XCTAssertEqual(attempts[0].reasoning?.content, reasoning)
        XCTAssertNil(attempts[0].program)
        XCTAssertTrue(attempts[0].evaluation?.feedback.contains("No final H program") == true)
        XCTAssertEqual(attempts[0].finishReason, "length")
        XCTAssertTrue(attempts[1].evaluation?.accepted == true)
        let requests = await client.requests
        XCTAssertEqual(requests[1].map(\.role), ["system", "user"])
        XCTAssertTrue(requests[1][1].content.contains("Judge feedback:"))
        XCTAssertTrue(requests[1][1].content.contains("4096"))
        XCTAssertEqual(try JSONDecoder().decode(CompetitionResult.self, from: JSONEncoder().encode(result)), result)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LocalBattlefieldRepository(directory: directory)
        try repository.saveResult(result)
        let restored = try repository.loadResult(result.id)
        XCTAssertEqual(restored.id, result.id)
        XCTAssertEqual(restored.entrants.first?.answers.first?.attempts.map(\.reasoning), attempts.map(\.reasoning))
        XCTAssertEqual(restored.entrants.first?.answers.first?.attempts.map(\.response), attempts.map(\.response))
        XCTAssertEqual(restored.entrants.first?.answers.first?.status, .solved)
    }

    func testRetryInputEstimatesIncludeReplayedReasoning() {
        let reasoning = AIReasoning(content: String(repeating: "思考", count: 1000))
        let without = TokenUsage.estimate(messages: [AIMessage(role: "assistant", content: "s")])
        let withReasoning = TokenUsage.estimate(messages: [
            AIMessage(role: "assistant", content: "s", reasoning: reasoning)
        ])
        XCTAssertEqual(withReasoning.input - without.input, reasoning.content.utf8.count / 4)
        XCTAssertTrue(withReasoning.estimated)
    }

    func testRejectedAnswerCarriesReasoningIntoRetry() async throws {
        let reasoning = AIReasoning(content: "I chose the wrong command.")
        let client = RetryClient(first: AIReply(text: "z", usage: TokenUsage(), reasoning: reasoning))
        let result = try await run(client)
        let requests = await client.requests
        XCTAssertEqual(requests[1][2], AIMessage(role: "assistant", content: "z", reasoning: reasoning))
        XCTAssertEqual(result.entrants.first?.answers.first?.status, .solved)
    }

    func testProviderErrorIsRetainedWithSecretRedactedAndLegacyAttemptDecodes() async throws {
        let client = RetryClient(
            failure: AIHTTPError(
                status: 400, providerResponse: "invalid_request_error: empty content. key=test-only-secret"))
        let result = try await run(client)
        let attempt = try XCTUnwrap(result.entrants.first?.answers.first?.attempts.first)
        XCTAssertEqual(attempt.error, "AI HTTP 400")
        XCTAssertTrue(attempt.providerResponse?.contains("empty content") == true)
        let encoded = try JSONEncoder().encode(result)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("test-only-secret"))
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(attempt)) as? [String: Any])
        old.removeValue(forKey: "reasoning")
        old.removeValue(forKey: "providerResponse")
        let restored = try JSONDecoder().decode(AnswerAttempt.self, from: JSONSerialization.data(withJSONObject: old))
        XCTAssertNil(restored.reasoning)
        XCTAssertNil(restored.providerResponse)
        XCTAssertEqual(restored.error, "AI HTTP 400")
    }

    private func run(_ client: RetryClient) async throws -> CompetitionResult {
        let provider = ProviderConfiguration(kind: .compatible)
        let entrant = Entrant(provider: provider, preset: ModelPreset(model: AIModel(id: "kimi-for-coding")))
        let engine = BattlefieldEngine(client: client)
        return try await engine.run(
            configuration: CompetitionConfiguration(),
            problems: [try XCTUnwrap(ProblemCatalog.bundled().first)],
            participants: [CompetitionParticipant(entrant: entrant, apiKey: "test-only-secret")]
        ) { _ in }
    }
}

private actor RetryClient: AIClient {
    var requests: [[AIMessage]] = []
    let first: AIReply?
    let failure: AIHTTPError?
    init(first: AIReply? = nil, failure: AIHTTPError? = nil) {
        self.first = first
        self.failure = failure
    }
    func models(provider: ProviderConfiguration, apiKey: String) async throws -> [AIModel] { [] }
    func complete(_ request: AICompletionRequest, progress: @escaping @Sendable (AIProgress) async -> Void) async throws
        -> AIReply
    {
        requests.append(request.messages)
        if let failure { throw failure }
        let reply = requests.count == 1 ? first! : AIReply(text: "```h\ns\n```", usage: TokenUsage())
        await progress(AIProgress(text: reply.text, usage: reply.usage, isFinal: true, reasoning: reply.reasoning))
        return reply
    }
}
