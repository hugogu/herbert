import Foundation
import HerbertCore
import XCTest

@testable import HerbertBattlefield

@MainActor
final class ProviderRetryTests: XCTestCase {
    static let quotaPayload =
        #"[{"error":{"code":429,"status":"RESOURCE_EXHAUSTED","details":[{"@type":"type.googleapis.com/google.rpc.RetryInfo","retryDelay":"28s"}],"message":"Quota exceeded. Please retry in 28.626942979s."}}]"#

    func testQuotaAndInBand429AreOverloadedAndUseTheLongestProviderHint() {
        for status in [429, 200] {
            let error = AIHTTPError(status: status, providerResponse: Self.quotaPayload)
            XCTAssertEqual(ProviderDiagnostics.classify(error), .overloaded)
            XCTAssertEqual(
                ProviderRetryPolicy.delay(for: error, consecutiveFailure: 1, jitter: 0), 28.626942979,
                accuracy: 0.000001)
        }
        let header = AIHTTPError(status: 429, providerResponse: Self.quotaPayload, retryAfter: 60)
        XCTAssertEqual(ProviderRetryPolicy.delay(for: header, consecutiveFailure: 1, jitter: 0), 60)
    }

    func testRetryAfterAcceptsSecondsAndHTTPDateAndRejectsInvalidHints() throws {
        let now = Date(timeIntervalSince1970: 1_000_000_000)
        XCTAssertEqual(ProviderRetryPolicy.retryAfter(" 28 ", now: now), 28)
        XCTAssertEqual(ProviderRetryPolicy.retryAfter("Sun, 09 Sep 2001 01:47:10 GMT", now: now), 30)
        XCTAssertEqual(ProviderRetryPolicy.retryAfter("Sun, 09 Sep 2001 01:46:00 GMT", now: now), 0)
        for invalid in ["-3", "nan", "inf", "1e300", "tomorrow"] {
            XCTAssertNil(ProviderRetryPolicy.retryAfter(invalid, now: now))
        }
        XCTAssertEqual(
            ProviderRetryPolicy.payloadDelay(
                #"{"error":{"retry_after":12,"message":"Please retry after 14 seconds."}}"#), 14)
        XCTAssertNil(
            ProviderRetryPolicy.payloadDelay(#"{"error":{"details":[{"retryDelay":"-4s"}],"message":"Retry later"}}"#))
    }

    func testAllOverloadsHaveIncreasingBoundedBackoffAndPositiveJitter() {
        for error in [
            AIHTTPError(status: 503), AIHTTPError(status: 429),
            AIHTTPError(status: 200, providerResponse: #"{"error":{"message":"high demand"}}"#),
        ] {
            XCTAssertEqual(ProviderDiagnostics.classify(error), .overloaded)
            XCTAssertEqual(ProviderRetryPolicy.delay(for: error, consecutiveFailure: 1, jitter: 0), 2)
            XCTAssertEqual(ProviderRetryPolicy.delay(for: error, consecutiveFailure: 2, jitter: 0), 4)
            XCTAssertEqual(ProviderRetryPolicy.delay(for: error, consecutiveFailure: 10, jitter: 0), 60)
            XCTAssertEqual(ProviderRetryPolicy.delay(for: error, consecutiveFailure: 1, jitter: 1), 2.5)
        }
    }

    func testEngineWaitsBeforeRetryAndReusesExactInitialMessages() async throws {
        let client = RetryClient(failures: [AIHTTPError(status: 429, providerResponse: Self.quotaPayload)])
        let waits = RetryWaits()
        let engine = BattlefieldEngine(client: client, retrySleep: { await waits.record($0) })
        let problem = try XCTUnwrap(ProblemCatalog.bundled().first)
        let result = try await engine.run(configuration: .init(), problems: [problem], participants: [participant()]) {
            _ in
        }
        let delays = await waits.delays
        XCTAssertEqual(delays.count, 1)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(delays.first), 28.626942979)
        let messages = await client.messages
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0], BattlefieldPrompt.messages(for: problem))
        XCTAssertEqual(messages[0], messages[1])
        let answer = result.entrants[0].answers[0]
        XCTAssertEqual(answer.status, .solved)
        XCTAssertNil(answer.retryAt)
        XCTAssertEqual(answer.attempts.count, 2)
        XCTAssertNil(answer.attempts[0].evaluation)
        XCTAssertNotNil(answer.attempts[0].finishedAt)
        let restored = try JSONDecoder().decode(CompetitionResult.self, from: JSONEncoder().encode(result))
        XCTAssertEqual(restored.entrants[0].answers[0], answer)
    }

    func testExhaustedProblemStillWaitsBeforeNextRequestWithoutAddingAttempts() async throws {
        let client = RetryClient(failures: [
            AIHTTPError(status: 503), AIHTTPError(status: 503), AIHTTPError(status: 503),
        ])
        let waits = RetryWaits()
        let engine = BattlefieldEngine(client: client, retrySleep: { await waits.record($0) })
        var config = CompetitionConfiguration()
        config.attemptsPerProblem = 1
        let result = try await engine.run(
            configuration: config, problems: Array(try ProblemCatalog.bundled().prefix(3)),
            participants: [participant()]
        ) { _ in }
        let delays = await waits.delays
        XCTAssertEqual(delays.count, 2, "No wait is needed after the final request")
        XCTAssertTrue((2...2.5).contains(delays[0]))
        XCTAssertTrue((4...5).contains(delays[1]))
        XCTAssertTrue(
            result.entrants[0].answers.allSatisfy {
                $0.status == .overloaded && $0.attempts.count == 1 && $0.retryAt == nil
            })
    }

    func testStopCancelsLongRetryWaitWithoutSendingAnotherRequest() async throws {
        try await checkCancelledRetryWait(timed: false)
    }

    func testDeadlineCancelsLongRetryWaitWithoutSendingAnotherRequest() async throws {
        try await checkCancelledRetryWait(timed: true)
    }

    private func checkCancelledRetryWait(timed: Bool) async throws {
        let client = RetryClient(failures: [AIHTTPError(status: 429, providerResponse: Self.quotaPayload)])
        let engine = BattlefieldEngine(client: client)
        let waiting = expectation(description: "Retry wait is visible")
        waiting.assertForOverFulfill = false
        var config = CompetitionConfiguration()
        config.timeLimitEnabled = timed
        config.timeLimitSeconds = 0.3
        let problem = try XCTUnwrap(ProblemCatalog.bundled().first)
        let participants = [participant()]
        let configuration = config
        let run = Task {
            try await engine.run(configuration: configuration, problems: [problem], participants: participants) {
                result in
                if result.entrants[0].answers[0].retryAt != nil { waiting.fulfill() }
            }
        }
        await fulfillment(of: [waiting], timeout: 2)
        if !timed { await engine.stop() }
        let result = try await run.value
        XCTAssertEqual(result.status, timed ? .timeLimit : .userStopped)
        let calls = await client.messages.count
        XCTAssertEqual(calls, 1)
        XCTAssertNil(result.entrants[0].answers[0].retryAt)
        XCTAssertEqual(result.entrants[0].answers[0].attempts.count, 1)
    }

    func testWaitingEntrantDoesNotBlockOtherModels() async throws {
        let client = RetryClient(failures: [AIHTTPError(status: 429, providerResponse: Self.quotaPayload)])
        let engine = BattlefieldEngine(client: client)
        let independent = expectation(description: "Healthy entrant finishes while busy entrant waits")
        independent.assertForOverFulfill = false
        let problem = try XCTUnwrap(ProblemCatalog.bundled().first)
        let run = Task {
            try await engine.run(
                configuration: .init(), problems: [problem], participants: [participant(), participant(model: "ready")]
            ) { result in
                if result.entrants[0].answers[0].retryAt != nil && result.entrants[1].solved == 1 {
                    independent.fulfill()
                }
            }
        }
        await fulfillment(of: [independent], timeout: 2)
        await engine.stop()
        let result = try await run.value
        XCTAssertEqual(result.entrants[1].answers[0].status, .solved)
        XCTAssertEqual(result.entrants[0].answers[0].attempts.count, 1)
    }

    func testRetryDateIsOptionalForOldHistory() throws {
        let old = try JSONDecoder().decode(
            ProblemAnswer.self, from: Data(#"{"id":10001,"status":"overloaded","attempts":[]}"#.utf8))
        XCTAssertNil(old.retryAt)
        var answer = old
        answer.retryAt = Date(timeIntervalSince1970: 123)
        XCTAssertEqual(try JSONDecoder().decode(ProblemAnswer.self, from: JSONEncoder().encode(answer)), answer)
    }

    private func participant(model: String = "busy") -> CompetitionParticipant {
        CompetitionParticipant(
            entrant: Entrant(
                provider: ProviderConfiguration(kind: .gemini), preset: ModelPreset(model: AIModel(id: model))),
            apiKey: "fixture")
    }
}

private actor RetryWaits {
    var delays: [TimeInterval] = []
    func record(_ delay: TimeInterval) { delays.append(delay) }
}

private actor RetryClient: AIClient {
    var failures: [AIHTTPError]
    var messages: [[AIMessage]] = []
    init(failures: [AIHTTPError]) { self.failures = failures }
    func models(provider: ProviderConfiguration, apiKey: String) async throws -> [AIModel] { [] }
    func complete(_ request: AICompletionRequest, progress: @escaping @Sendable (AIProgress) async -> Void) async throws
        -> AIReply
    {
        messages.append(request.messages)
        if request.participant.entrant.preset.model.id == "busy", !failures.isEmpty { throw failures.removeFirst() }
        return AIReply(text: "```h\ns\n```", usage: TokenUsage())
    }
}
