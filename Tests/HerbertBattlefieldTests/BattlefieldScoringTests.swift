import Foundation
import HerbertCore
import XCTest

@testable import HerbertBattlefield

@MainActor
final class BattlefieldScoringTests: XCTestCase {
    private func puzzle(trap: Bool = false) -> Problem {
        var rows = Array(repeating: Array(repeating: Character("."), count: 25), count: 25)
        rows[12][12] = "u"
        rows[11][12] = "o"
        rows[9][12] = "o"
        if trap { rows[10][12] = "*" }
        return Problem(id: 1, title: "Scoring fixture", author: "Test", byteLimit: 10, rows: rows.map { String($0) })
    }

    private func attempt(_ program: String, problem: Problem, number: Int = 1, tokens: Int = 10) throws -> AnswerAttempt
    {
        var attempt = AnswerAttempt(number: number)
        attempt.program = program
        attempt.evaluation = try BattlefieldJudge.evaluate(program, problem: problem)
        attempt.usage = TokenUsage(input: tokens, estimated: false)
        return attempt
    }

    func testNativePartialCoverageShorterSolutionsAndHardByteLimit() throws {
        let problem = puzzle()
        let policy = BattlefieldScoring.coverageAndLengthV1
        let partial = try BattlefieldJudge.evaluate("s", problem: problem)
        XCTAssertFalse(partial.accepted)
        XCTAssertEqual(policy.score(partial, byteLimit: 10), 49)
        let short = try BattlefieldJudge.evaluate("sss", problem: problem)
        let padded = try BattlefieldJudge.evaluate("ssss", problem: problem)
        XCTAssertTrue(short.accepted)
        XCTAssertTrue(padded.accepted)
        XCTAssertEqual(policy.score(short, byteLimit: 10), 94)
        XCTAssertEqual(policy.score(padded, byteLimit: 10), 92)
        XCTAssertEqual(policy.score(try BattlefieldJudge.evaluate("z", problem: problem), byteLimit: 10), 0)
        XCTAssertEqual(
            policy.score(
                try BattlefieldJudge.evaluate(String(repeating: "s", count: 11), problem: problem), byteLimit: 10), 0)
    }

    func testTrapResetsCoverageButFailedRetryKeepsEarlierBest() throws {
        let problem = puzzle(trap: true)
        var answer = ProblemAnswer(problemID: problem.id)
        answer.status = .failed
        answer.attempts = [try attempt("s", problem: problem), try attempt("ss", problem: problem, number: 2)]
        let policy = BattlefieldScoring.coverageAndLengthV1
        XCTAssertEqual(answer.attempts[1].evaluation?.litTargets, 0)
        XCTAssertEqual(policy.score(answer, problem: problem), 49)
        XCTAssertEqual(policy.bestAttempt(answer, problem: problem)?.program, "s")
        answer.status = .cancelled
        XCTAssertEqual(policy.score(answer, problem: problem), 49)
    }

    func testRankingUsesScoreThenAllTokensIncludingRetriesAndCachedInput() throws {
        let problem = puzzle()
        let entrants = (0..<3).map {
            Entrant(
                provider: ProviderConfiguration(kind: .compatible), preset: ModelPreset(model: AIModel(id: "m\($0)")))
        }
        var result = CompetitionResult(
            configuration: CompetitionConfiguration(), problems: [problem], entrants: entrants)
        result.entrants[0].answers[0].attempts = [try attempt("s", problem: problem, tokens: 1)]
        result.entrants[1].answers[0].attempts = [
            try attempt("z", problem: problem, tokens: 15), try attempt("sss", problem: problem, number: 2, tokens: 10),
        ]
        result.entrants[2].answers[0].attempts = [try attempt("sss", problem: problem, tokens: 20)]
        result.entrants[2].answers[0].attempts[0].usage.cached = 20
        XCTAssertEqual(result.ranked.map(\.id), [entrants[2].id, entrants[1].id, entrants[0].id])
        XCTAssertEqual(result.score(for: result.entrants[0]), 49)
        XCTAssertEqual(result.score(for: result.entrants[1]), 94)
    }

    func testEngineAwardsPartialPointsAfterRetriesAndReturnsScoreFeedback() async throws {
        let problem = puzzle()
        let client = ScriptedAI(behavior: .correct)
        let engine = BattlefieldEngine(client: client)
        var configuration = CompetitionConfiguration()
        configuration.mode = .bestEffort
        configuration.attemptsPerProblem = 2
        let participant = CompetitionParticipant(
            entrant: Entrant(
                provider: ProviderConfiguration(kind: .compatible), preset: ModelPreset(model: AIModel(id: "fixture"))),
            apiKey: "test")
        let result = try await engine.run(
            configuration: configuration, problems: [problem], participants: [participant]
        ) { _ in }
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.entrants[0].answers[0].status, .failed)
        XCTAssertEqual(result.entrants[0].answers[0].attempts.count, 2)
        XCTAssertEqual(result.score(for: result.entrants[0]), 49)
        let requests = await client.requests
        XCTAssertTrue(requests[1].messages.last!.content.contains("Battlefield points: 49.0"))
    }

    func testFractionalScoresRoundPerAttemptAndHistoryRetainsPolicy() throws {
        let original = puzzle()
        let problem = Problem(id: 1, title: original.title, author: original.author, byteLimit: 3, rows: original.rows)
        var result = CompetitionResult(
            configuration: CompetitionConfiguration(), problems: [problem],
            entrants: [
                Entrant(
                    provider: ProviderConfiguration(kind: .compatible),
                    preset: ModelPreset(model: AIModel(id: "fixture")))
            ])
        result.entrants[0].answers[0].attempts = [try attempt("s", problem: problem)]
        result.entrants[0].answers[0].status = .failed
        XCTAssertEqual(result.score(for: result.entrants[0]), 46.67)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LocalBattlefieldRepository(directory: directory)
        try repository.saveResult(result)
        let restored = try repository.loadResult(result.id)
        XCTAssertEqual(restored.scoringPolicy, .coverageAndLengthV1)
        XCTAssertEqual(restored.score(for: restored.entrants[0]), 46.67)
        XCTAssertEqual(try repository.summaries()[0].topScore, 46.67)
    }

    func testPreScoringHistoryAndIntegerSummaryRemainReadableWithoutReranking() throws {
        let problem = puzzle()
        let entrants = (0..<2).map {
            Entrant(
                provider: ProviderConfiguration(kind: .compatible), preset: ModelPreset(model: AIModel(id: "m\($0)")))
        }
        var result = CompetitionResult(
            configuration: CompetitionConfiguration(), problems: [problem], entrants: entrants)
        for index in result.entrants.indices {
            result.entrants[index].answers[0].status = .solved
            result.entrants[index].answers[0].attempts = [
                try attempt(index == 0 ? "sss" : "ssss", problem: problem, tokens: index == 0 ? 100 : 1)
            ]
        }
        let encoder = JSONEncoder()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(result)) as? [String: Any])
        json.removeValue(forKey: "scoring")
        let legacy = try JSONDecoder().decode(
            CompetitionResult.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(legacy.scoringPolicy, .legacyAccepted)
        XCTAssertEqual(legacy.score(for: legacy.entrants[0]), 100)
        XCTAssertEqual(legacy.ranked[0].id, entrants[0].id)
        let summary = CompetitionSummary(legacy)
        let restoredSummary = try JSONDecoder().decode(CompetitionSummary.self, from: encoder.encode(summary))
        XCTAssertEqual(restoredSummary.topScore, 100)
    }
}
