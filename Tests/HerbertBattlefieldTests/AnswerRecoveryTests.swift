import HerbertCore
import XCTest

@testable import HerbertBattlefield

final class AnswerRecoveryTests: XCTestCase {
    func testExplicitFinalInReasoningIsRecoveredWithoutLosingRawOutput() throws {
        let raw = "Trying a candidate: ```h\nr\n```\n\nFinal answer:\n\n```h\na(N):sa(N-1)\na(8)rra(4)la(6)rra(2)\n```"
        let reply = AIReply(text: "", usage: TokenUsage(), reasoning: AIReasoning(content: raw))
        let recovered = try BattlefieldJudge.submission(in: reply)
        XCTAssertEqual(recovered.source, .reasoning)
        XCTAssertEqual(recovered.program, "a(N):sa(N-1)\na(8)rra(4)la(6)rra(2)")
        XCTAssertEqual(reply.reasoning?.content, raw)
        var attempt = AnswerAttempt(number: 1)
        attempt.reasoning = reply.reasoning
        XCTAssertEqual(attempt.trialSubmission, recovered, "Old history supports trials without rewriting raw content")
        XCTAssertEqual(try JSONDecoder().decode(AnswerAttempt.self, from: JSONEncoder().encode(attempt)), attempt)
    }

    func testFinalRecoveryIsConservativeAndHandlesMissingClosingFence() throws {
        let thinking = AIReasoning(content: "Maybe this works:\n```h\ns\n```\nStill checking.")
        XCTAssertThrowsError(
            try BattlefieldJudge.submission(in: AIReply(text: "", usage: TokenUsage(), reasoning: thinking)))
        XCTAssertThrowsError(
            try BattlefieldJudge.submission(in: AIReply(text: "```h\ns\n```\n```h\nr\n```", usage: TokenUsage())))
        XCTAssertThrowsError(
            try BattlefieldJudge.submission(in: AIReply(text: "```python\nprint('s')\n```", usage: TokenUsage())))
        XCTAssertEqual(try BattlefieldJudge.submission(in: AIReply(text: "```h\ns", usage: TokenUsage())).program, "s")
        XCTAssertEqual(
            try BattlefieldJudge.submission(in: AIReply(text: "## Final answer\n\ns", usage: TokenUsage())).program, "s"
        )
        let content = AIReply(
            text: "```h\nr\n```", usage: TokenUsage(), reasoning: AIReasoning(content: "Final answer:\n```h\ns\n```"))
        XCTAssertEqual(try BattlefieldJudge.submission(in: content).program, "r", "Final response takes priority")
    }

    func testRecoveredFinalIsJudgedButInterruptedReasoningIsNeverScored() async throws {
        let problem = try XCTUnwrap(ProblemCatalog.bundled().first)
        let participant = CompetitionParticipant(
            entrant: Entrant(
                provider: ProviderConfiguration(kind: .compatible), preset: ModelPreset(model: AIModel(id: "test"))),
            apiKey: "fixture")
        for finish in ["stop", "length", "error"] {
            let reasoning = AIReasoning(content: "Final answer:\n```h\ns\n```")
            let reply = AIReply(
                text: "", usage: TokenUsage(input: 10, output: 20), finishReason: finish, reasoning: reasoning)
            let engine = BattlefieldEngine(client: RecoveryClient(reply: reply))
            var configuration = CompetitionConfiguration()
            configuration.attemptsPerProblem = 1
            let result = try await engine.run(
                configuration: configuration, problems: [problem], participants: [participant]
            ) { _ in }
            let answer = try XCTUnwrap(result.entrants.first?.answers.first)
            XCTAssertEqual(answer.attempts.first?.reasoning, reasoning)
            if finish == "stop" {
                XCTAssertEqual(answer.status, .solved)
                XCTAssertEqual(answer.attempts.first?.programSource, .reasoning)
                XCTAssertEqual(result.score(for: answer), 80)
            } else {
                XCTAssertNil(answer.attempts.first?.evaluation)
                XCTAssertEqual(result.score(for: answer), 0)
            }
        }
    }
}

private struct RecoveryClient: AIClient {
    let reply: AIReply
    func models(provider: ProviderConfiguration, apiKey: String) async throws -> [AIModel] { [] }
    func complete(_ request: AICompletionRequest, progress: @escaping @Sendable (AIProgress) async -> Void) async throws
        -> AIReply
    { reply }
}
