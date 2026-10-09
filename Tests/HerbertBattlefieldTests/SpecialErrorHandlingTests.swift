import Foundation
import HerbertCore
import XCTest

@testable import HerbertBattlefield

final class SpecialErrorHandlingTests: XCTestCase {
    func testGeminiProviderConfiguration() throws {
        let provider = ProviderConfiguration(kind: .gemini)
        XCTAssertEqual(provider.kind, .gemini)
        XCTAssertEqual(provider.name, "Google Gemini")
        XCTAssertEqual(provider.baseURL, "https://generativelanguage.googleapis.com/v1beta/openai")
        XCTAssertEqual(
            try provider.endpoint("models").absoluteString,
            "https://generativelanguage.googleapis.com/v1beta/openai/models")
        XCTAssertEqual(
            try provider.endpoint("chat/completions").absoluteString,
            "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions")

        let encoded = try JSONEncoder().encode(provider)
        let decoded = try JSONDecoder().decode(ProviderConfiguration.self, from: encoded)
        XCTAssertEqual(decoded.kind, .gemini)
        XCTAssertEqual(decoded.name, "Google Gemini")
        XCTAssertEqual(decoded.baseURL, "https://generativelanguage.googleapis.com/v1beta/openai")
    }

    func testProviderDiagnosticsClassification() {
        // Image 1: Gemini 503 high demand
        let gemini503Payload = """
            [
              {
                "error" : {
                  "code" : 503,
                  "message" : "This model is currently experiencing high demand. Spikes in demand are usually temporary. Please try again later.",
                  "status" : "UNAVAILABLE"
                }
              }
            ]
            """
        let geminiError = AIHTTPError(status: 503, providerResponse: gemini503Payload)
        let geminiClassification = ProviderDiagnostics.classify(geminiError, detail: gemini503Payload)
        XCTAssertEqual(geminiClassification, .overloaded)
        XCTAssertEqual(geminiClassification.status, .overloaded)
        XCTAssertTrue(geminiClassification.isRetriable)
        XCTAssertFalse(geminiClassification.shouldStopEntrant)

        // Image 2: Network timeout
        let timeoutError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        let timeoutClassification = ProviderDiagnostics.classify(
            timeoutError, detail: "NSURLErrorDomain -1001\nThe request timed out.")
        XCTAssertEqual(timeoutClassification, .timedout)
        XCTAssertEqual(timeoutClassification.status, .timedout)
        XCTAssertFalse(timeoutClassification.isRetriable)
        XCTAssertFalse(timeoutClassification.shouldStopEntrant)

        // Image 3: 502 Upstream error exceeded wall-clock limit
        let venice502Payload = """
            {
              "error" : {
                "code" : 502,
                "message" : "Upstream error from Venice: Streaming request exceeded the 900 second wall-clock limit.",
                "metadata" : {
                  "error_type" : "provider_unavailable"
                }
              }
            }
            """
        let veniceError = AIHTTPError(status: 200, providerResponse: venice502Payload)
        let veniceClassification = ProviderDiagnostics.classify(veniceError, detail: venice502Payload)
        XCTAssertEqual(veniceClassification, .timedout)
        XCTAssertEqual(veniceClassification.status, .timedout)
        XCTAssertFalse(veniceClassification.isRetriable)
        XCTAssertFalse(veniceClassification.shouldStopEntrant)

        // Image 4: 502 Connection lost
        let fireworks502Payload = """
            {
              "error" : {
                "code" : 502,
                "message" : "Network connection lost.",
                "metadata" : {
                  "error_type" : "provider_unavailable"
                }
              }
            }
            """
        let fireworksError = AIHTTPError(status: 200, providerResponse: fireworks502Payload)
        let fireworksClassification = ProviderDiagnostics.classify(fireworksError, detail: fireworks502Payload)
        XCTAssertEqual(fireworksClassification, .tempUnavailable)
        XCTAssertEqual(fireworksClassification.status, .tempUnavailable)
        XCTAssertTrue(fireworksClassification.isRetriable)
        XCTAssertFalse(fireworksClassification.shouldStopEntrant)

        // Image 5: 403 Forbidden / Terms of Service violation
        let tos403Payload = """
            {
              "error" : {
                "code" : 403,
                "message" : "The request is prohibited due to a violation of provider Terms Of Service."
              }
            }
            """
        let tosError = AIHTTPError(status: 403, providerResponse: tos403Payload)
        let tosClassification = ProviderDiagnostics.classify(tosError, detail: tos403Payload)
        XCTAssertEqual(tosClassification, .accessDenied)
        XCTAssertEqual(tosClassification.status, .accessDenied)
        XCTAssertFalse(tosClassification.isRetriable)
        XCTAssertTrue(tosClassification.shouldStopEntrant)

        // Generic 401 Unauthorized
        let auth401Error = AIHTTPError(status: 401, providerResponse: "Invalid API key")
        let authClassification = ProviderDiagnostics.classify(auth401Error, detail: "Invalid API key")
        XCTAssertEqual(authClassification.status, .error)
        XCTAssertFalse(authClassification.isRetriable)
        XCTAssertTrue(authClassification.shouldStopEntrant)
    }

    func testOverloadedErrorRetriesAndSucceedsOnSecondAttempt() async throws {
        let gemini503 = AIHTTPError(
            status: 503,
            providerResponse: """
                [{"error":{"code":503,"message":"This model is currently experiencing high demand.","status":"UNAVAILABLE"}}]
                """
        )
        let client = SequenceClient(responses: [
            .failure(gemini503),
            .success(AIReply(text: "```h\ns\n```", usage: TokenUsage())),
        ])
        var config = CompetitionConfiguration()
        config.attemptsPerProblem = 2
        let result = try await run(client: client, configuration: config, problemCount: 1)
        let answer = try XCTUnwrap(result.entrants.first?.answers.first)
        XCTAssertEqual(answer.attempts.count, 2)
        XCTAssertEqual(answer.status, .solved)
        XCTAssertEqual(answer.attempts[0].error, "AI HTTP 503")
        XCTAssertEqual(answer.attempts[1].evaluation?.accepted, true)
    }

    func testOverloadedErrorExhaustsRetriesAndContinuesToNextProblem() async throws {
        let gemini503 = AIHTTPError(
            status: 503,
            providerResponse: """
                [{"error":{"code":503,"message":"This model is currently experiencing high demand.","status":"UNAVAILABLE"}}]
                """
        )
        let client = SequenceClient(responses: [
            .failure(gemini503),
            .failure(gemini503),
            .success(AIReply(text: "```h\nrsslsslss\n```", usage: TokenUsage())),
        ])
        var config = CompetitionConfiguration()
        config.attemptsPerProblem = 2
        let result = try await run(client: client, configuration: config, problemCount: 2)
        let entrant = try XCTUnwrap(result.entrants.first)
        XCTAssertEqual(entrant.answers[0].attempts.count, 2)
        XCTAssertEqual(entrant.answers[0].status, .overloaded)
        XCTAssertEqual(entrant.answers[1].status, .solved)
    }

    func testTempUnavailableRetriesAndContinuesToNextProblem() async throws {
        let lost502 = AIHTTPError(
            status: 200,
            providerResponse: """
                {"error":{"code":502,"message":"Network connection lost.","metadata":{"error_type":"provider_unavailable"}}}
                """
        )
        let client = SequenceClient(responses: [
            .failure(lost502),
            .failure(lost502),
            .success(AIReply(text: "```h\nrsslsslss\n```", usage: TokenUsage())),
        ])
        var config = CompetitionConfiguration()
        config.attemptsPerProblem = 2
        let result = try await run(client: client, configuration: config, problemCount: 2)
        let entrant = try XCTUnwrap(result.entrants.first)
        XCTAssertEqual(entrant.answers[0].attempts.count, 2)
        XCTAssertEqual(entrant.answers[0].status, .tempUnavailable)
        XCTAssertEqual(entrant.answers[1].status, .solved)
    }

    func testTimedoutDoesNotRetryCurrentProblemAndContinuesToNextProblem() async throws {
        let timeoutError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        let client = SequenceClient(responses: [
            .failure(timeoutError),
            .success(AIReply(text: "```h\nrsslsslss\n```", usage: TokenUsage())),
        ])
        var config = CompetitionConfiguration()
        config.attemptsPerProblem = 2
        let result = try await run(client: client, configuration: config, problemCount: 2)
        let entrant = try XCTUnwrap(result.entrants.first)
        XCTAssertEqual(entrant.answers[0].attempts.count, 1)
        XCTAssertEqual(entrant.answers[0].status, .timedout)
        XCTAssertEqual(entrant.answers[1].status, .solved)
    }

    func testVeniceWallClockLimitBecomesTimedoutAndContinues() async throws {
        let veniceError = AIHTTPError(
            status: 200,
            providerResponse: """
                {"error":{"code":502,"message":"Upstream error from Venice: Streaming request exceeded the 900 second wall-clock limit."}}
                """
        )
        let client = SequenceClient(responses: [
            .failure(veniceError),
            .success(AIReply(text: "```h\nrsslsslss\n```", usage: TokenUsage())),
        ])
        var config = CompetitionConfiguration()
        config.attemptsPerProblem = 2
        let result = try await run(client: client, configuration: config, problemCount: 2)
        let entrant = try XCTUnwrap(result.entrants.first)
        XCTAssertEqual(entrant.answers[0].attempts.count, 1)
        XCTAssertEqual(entrant.answers[0].status, .timedout)
        XCTAssertEqual(entrant.answers[1].status, .solved)
    }

    func testAccessDeniedStopsEntrantImmediatelyAndCancelsRemainingProblems() async throws {
        let forbidden403 = AIHTTPError(
            status: 403,
            providerResponse: """
                {"error":{"code":403,"message":"The request is prohibited due to a violation of provider Terms Of Service."}}
                """
        )
        let client = SequenceClient(responses: [
            .failure(forbidden403),
            .success(AIReply(text: "```h\ns\n```", usage: TokenUsage())),
        ])
        var config = CompetitionConfiguration()
        config.attemptsPerProblem = 2
        let result = try await run(client: client, configuration: config, problemCount: 2)
        let entrant = try XCTUnwrap(result.entrants.first)
        XCTAssertEqual(entrant.answers[0].attempts.count, 1)
        XCTAssertEqual(entrant.answers[0].status, .accessDenied)
        XCTAssertEqual(entrant.answers[1].status, .cancelled)
        XCTAssertNotNil(entrant.finishedAt)
        XCTAssertTrue(entrant.error?.contains("403") == true)
    }

    private func run(
        client: SequenceClient, configuration: CompetitionConfiguration, problemCount: Int
    ) async throws -> CompetitionResult {
        let provider = ProviderConfiguration(kind: .gemini)
        let entrant = Entrant(provider: provider, preset: ModelPreset(model: AIModel(id: "models/gemini-2.5-flash")))
        let engine = BattlefieldEngine(client: client)
        let problems = Array(try ProblemCatalog.bundled().prefix(problemCount))
        return try await engine.run(
            configuration: configuration,
            problems: problems,
            participants: [CompetitionParticipant(entrant: entrant, apiKey: "test-gemini-key")]
        ) { _ in }
    }
}

private actor SequenceClient: AIClient {
    enum Response: Sendable {
        case success(AIReply)
        case failure(any Error)
    }

    private var responses: [Response]
    init(responses: [Response]) {
        self.responses = responses
    }

    func models(provider: ProviderConfiguration, apiKey: String) async throws -> [AIModel] { [] }

    func complete(
        _ request: AICompletionRequest, progress: @escaping @Sendable (AIProgress) async -> Void
    ) async throws -> AIReply {
        guard !responses.isEmpty else {
            return AIReply(text: "```h\ns\n```", usage: TokenUsage())
        }
        let next = responses.removeFirst()
        switch next {
        case .success(let reply):
            await progress(AIProgress(text: reply.text, usage: reply.usage, isFinal: true, reasoning: reply.reasoning))
            return reply
        case .failure(let error):
            throw error
        }
    }
}
