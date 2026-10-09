import Foundation
import HerbertCore
import XCTest

@testable import HerbertBattlefield

final class ReasoningRetryTests: XCTestCase, @unchecked Sendable {
    func testProviderFinishErrorNeverReachesJudgeOrRetryAndPreservesHistory() async throws {
        for reason in ["error", "content_filter"] {
            let client = RetryClient(
                first: AIReply(
                    text: "s", usage: TokenUsage(input: 10, output: 22, estimated: false),
                    finishReason: reason, reasoning: AIReasoning(content: "Still thinking")))
            let result = try await run(client)
            let answer = try XCTUnwrap(result.entrants.first?.answers.first)
            let attempt = try XCTUnwrap(answer.attempts.first)
            XCTAssertEqual(answer.status, .error)
            XCTAssertEqual(answer.attempts.count, 1)
            XCTAssertNil(attempt.evaluation)
            XCTAssertNil(attempt.program)
            XCTAssertNotNil(attempt.finishedAt)
            XCTAssertEqual(attempt.error, "AI response error")
            XCTAssertEqual(attempt.finishReason, reason)
            XCTAssertEqual(attempt.reasoning?.content, "Still thinking")
            XCTAssertEqual(attempt.response, "s")
            XCTAssertEqual(attempt.usage.output, 22)
            XCTAssertTrue(attempt.usage.partial)
            let requests = await client.requests
            XCTAssertEqual(requests.count, 1)
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            let repository = LocalBattlefieldRepository(directory: directory)
            try repository.saveResult(result)
            let restored = try repository.loadResult(result.id)
            let savedAttempt = try XCTUnwrap(restored.entrants.first?.answers.first?.attempts.first)
            XCTAssertEqual(restored.entrants.first?.answers.first?.status, .error)
            XCTAssertNotNil(savedAttempt.finishedAt)
            XCTAssertNil(savedAttempt.evaluation)
            XCTAssertEqual(savedAttempt.reasoning, attempt.reasoning)
            XCTAssertEqual(savedAttempt.finishReason, attempt.finishReason)
            XCTAssertEqual(savedAttempt.error, attempt.error)
            XCTAssertEqual(savedAttempt.usage, attempt.usage)
        }
    }

    func testNetworkFailuresRetainPartialReasoningAndActionableRedactedDiagnostics() async throws {
        for code in [URLError.timedOut, .networkConnectionLost] {
            let client = RetryClient(
                first: AIReply(
                    text: "", usage: TokenUsage(input: 10, output: 200),
                    reasoning: AIReasoning(content: "Still thinking")),
                failure: NSError(
                    domain: NSURLErrorDomain, code: code.rawValue,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Connection interrupted test-only-secret https://example.com?api_key=hidden"
                    ]))
            let result = try await run(client)
            let answer = try XCTUnwrap(result.entrants.first?.answers.first)
            let attempt = try XCTUnwrap(answer.attempts.first)
            let expectedStatus: ProblemAnswerStatus = code == .timedOut ? .timedout : .tempUnavailable
            XCTAssertEqual(answer.status, expectedStatus)
            XCTAssertNil(attempt.evaluation)
            XCTAssertNotNil(attempt.finishedAt)
            XCTAssertEqual(attempt.reasoning?.content, "Still thinking")
            XCTAssertTrue(attempt.error?.contains("NSURLErrorDomain \(code.rawValue)") == true)
            XCTAssertTrue(attempt.providerResponse?.contains("Connection interrupted") == true)
            XCTAssertTrue(attempt.usage.partial)
            let encoded = String(decoding: try JSONEncoder().encode(result), as: UTF8.self)
            XCTAssertFalse(encoded.contains("test-only-secret"))
            XCTAssertFalse(encoded.contains("api_key=hidden"))
        }
    }

    func testHTTPErrorPartialReplyOverridesThrottledProgress() async throws {
        let client = RetryClient(
            failure: AIHTTPError(
                status: 200, providerResponse: "upstream timeout",
                partialReply: AIReply(
                    text: "", usage: TokenUsage(input: 3, output: 7), finishReason: "error",
                    reasoning: AIReasoning(content: "latest reasoning"))))
        let result = try await run(client)
        let attempt = try XCTUnwrap(result.entrants.first?.answers.first?.attempts.first)
        XCTAssertEqual(attempt.reasoning?.content, "latest reasoning")
        XCTAssertEqual(attempt.finishReason, "error")
        XCTAssertEqual(attempt.usage.output, 7)
        XCTAssertNil(attempt.evaluation)
    }

    func testOutputLimitBurnsOutWithoutJudgeFeedbackOrRetry() async throws {
        let reasoning = String(repeating: "plan ", count: 14_000)
        let client = RetryClient(
            first: AIReply(
                text: "", usage: TokenUsage(input: 100, output: 4096, reasoning: 4096, estimated: false),
                finishReason: "length", reasoning: AIReasoning(content: reasoning)))
        let result = try await run(client)
        let attempts = try XCTUnwrap(result.entrants.first?.answers.first?.attempts)
        XCTAssertEqual(attempts.count, 1)
        XCTAssertEqual(attempts[0].reasoning?.content, reasoning)
        XCTAssertNil(attempts[0].program)
        XCTAssertNil(attempts[0].evaluation)
        XCTAssertEqual(attempts[0].finishReason, "length")
        let requests = await client.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(result.entrants.first?.answers.first?.status, .burnout)
        XCTAssertEqual(try JSONDecoder().decode(CompetitionResult.self, from: JSONEncoder().encode(result)), result)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LocalBattlefieldRepository(directory: directory)
        try repository.saveResult(result)
        let restored = try repository.loadResult(result.id)
        XCTAssertEqual(restored.id, result.id)
        XCTAssertEqual(restored.entrants.first?.answers.first?.attempts.map(\.reasoning), attempts.map(\.reasoning))
        XCTAssertEqual(restored.entrants.first?.answers.first?.attempts.map(\.response), attempts.map(\.response))
        XCTAssertEqual(restored.entrants.first?.answers.first?.status, .burnout)
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
    let failure: (any Error)?
    init(first: AIReply? = nil, failure: (any Error)? = nil) {
        self.first = first
        self.failure = failure
    }
    func models(provider: ProviderConfiguration, apiKey: String) async throws -> [AIModel] { [] }
    func complete(_ request: AICompletionRequest, progress: @escaping @Sendable (AIProgress) async -> Void) async throws
        -> AIReply
    {
        requests.append(request.messages)
        if let failure {
            if let first {
                await progress(AIProgress(text: first.text, usage: first.usage, reasoning: first.reasoning))
            }
            throw failure
        }
        let reply = requests.count == 1 ? first! : AIReply(text: "```h\ns\n```", usage: TokenUsage())
        await progress(AIProgress(text: reply.text, usage: reply.usage, isFinal: true, reasoning: reply.reasoning))
        return reply
    }
}
