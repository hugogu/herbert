import HerbertCore
import XCTest

@testable import HerbertBattlefield

final class ManualRetryTests: XCTestCase {
    private func fixture() throws -> (Problem, CompetitionParticipant, CompetitionConfiguration) {
        let problem = try XCTUnwrap(ProblemCatalog.bundled().first)
        let participant = CompetitionParticipant(
            entrant: Entrant(
                provider: ProviderConfiguration(kind: .compatible), preset: ModelPreset(model: AIModel(id: "test"))),
            apiKey: "fixture")
        var configuration = CompetitionConfiguration()
        configuration.attemptsPerProblem = 1
        return (problem, participant, configuration)
    }

    func testSavedRetryAppendsOneAttemptPreservesSnapshotsAndPersists() async throws {
        let (problem, participant, configuration) = try fixture()
        let client = RetryClient()
        let engine = BattlefieldEngine(client: client)
        let initial = try await engine.run(
            configuration: configuration, problems: [problem], participants: [participant]
        ) { _ in }
        XCTAssertEqual(initial.entrants[0].answers[0].status, .failed)
        let retried = try await engine.retry(initial, participant: participant, problemID: problem.id) { _ in }
        XCTAssertEqual(retried.id, initial.id)
        XCTAssertEqual(retried.systemPrompt, initial.systemPrompt)
        XCTAssertEqual(retried.configuration, initial.configuration)
        XCTAssertEqual(retried.problems, initial.problems)
        XCTAssertEqual(retried.entrants[0].answers[0].status, .solved)
        let attempts = retried.entrants[0].answers[0].attempts
        XCTAssertEqual(attempts.map(\.id), [1, 2])
        XCTAssertEqual(attempts[0], initial.entrants[0].answers[0].attempts[0])
        XCTAssertEqual(attempts[1].manual, true)
        XCTAssertNotNil(attempts[1].finishedAt)
        XCTAssertEqual(retried.totalTokens, 60)
        XCTAssertEqual(retried.score(for: retried.entrants[0]), 80)
        let requests = await client.requests
        XCTAssertEqual(requests[1].messages.count, 4)
        XCTAssertEqual(requests[1].messages[0].content, initial.systemPrompt)
        XCTAssertTrue(requests[1].messages.last!.content.contains("Unlit targets"))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LocalBattlefieldRepository(directory: directory)
        try repository.saveResult(initial)
        try repository.saveResult(retried)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        XCTAssertEqual(
            try repository.loadResult(initial.id),
            try decoder.decode(CompetitionResult.self, from: encoder.encode(retried)))
        XCTAssertEqual(try repository.summaries().count, 1)
        do {
            _ = try await engine.retry(retried, participant: participant, problemID: problem.id) { _ in }
            XCTFail("Accepted answers cannot be manually retried")
        } catch {}
    }

    func testLiveRetryQueuesOnceAndRunsAfterCurrentPuzzle() async throws {
        let (problem, participant, configuration) = try fixture()
        let client = RetryClient()
        let engine = BattlefieldEngine(client: client)
        let recorder = RetryQueueRecorder()
        let result = try await engine.run(
            configuration: configuration, problems: [problem], participants: [participant]
        ) { snapshot in
            if snapshot.entrants[0].answers[0].status == .failed, await recorder.claim() {
                do {
                    try await engine.enqueueRetry(entrantID: participant.entrant.id, problemID: problem.id)
                    try await engine.enqueueRetry(entrantID: participant.entrant.id, problemID: problem.id)
                    await recorder.unexpectedDuplicate()
                } catch {}
            }
        }
        XCTAssertEqual(result.entrants[0].answers[0].attempts.count, 2)
        XCTAssertEqual(result.entrants[0].answers[0].status, .solved)
        let duplicate = await recorder.duplicateAccepted
        XCTAssertFalse(duplicate)
    }

    func testManualRetryCannotResetTokenOrTimeBudgetAndIdleTimeIsExcluded() async throws {
        let (problem, participant, _) = try fixture()
        var configuration = CompetitionConfiguration()
        configuration.problemTokenLimitEnabled = true
        configuration.problemTokenLimit = 10_000
        configuration.timeLimitEnabled = true
        configuration.timeLimitSeconds = 60
        var saved = CompetitionResult(
            configuration: configuration, problems: [problem], entrants: [participant.entrant])
        saved.entrants[0].answers[0].status = .burnout
        var attempt = AnswerAttempt(number: 1)
        attempt.usage = TokenUsage(input: 100, output: 9900)
        saved.entrants[0].answers[0].attempts = [attempt]
        saved.finish(.completed, at: saved.startedAt.addingTimeInterval(10))
        XCTAssertFalse(saved.canRetry(entrantID: participant.entrant.id, problemID: problem.id))
        let engine = BattlefieldEngine(client: RetryClient())
        do {
            _ = try await engine.retry(saved, participant: participant, problemID: problem.id) { _ in }
            XCTFail("Manual retries retain cumulative token usage")
        } catch {}
        saved.entrants[0].answers[0].attempts = []
        let resumed = saved.finishedAt!.addingTimeInterval(86_400)
        saved.resume(at: resumed)
        XCTAssertEqual(saved.elapsedTime(at: resumed.addingTimeInterval(5)), 15)
        saved.finish(.timeLimit, at: resumed.addingTimeInterval(50))
        XCTAssertFalse(saved.canRetry(entrantID: participant.entrant.id, problemID: problem.id))
    }

    func testManualRetryRejectsMismatchedSnapshotBeforeMakingRequest() async throws {
        let (problem, participant, configuration) = try fixture()
        let next = try ProblemCatalog.bundled()[1]
        var saved = CompetitionResult(
            configuration: configuration, problems: [problem, next], entrants: [participant.entrant])
        saved.entrants[0].answers[1].status = .failed
        saved.entrants[0].answers.removeFirst()
        saved.finish(.completed)
        let client = RetryClient()
        do {
            _ = try await BattlefieldEngine(client: client).retry(saved, participant: participant, problemID: next.id) {
                _ in
            }
            XCTFail("Mismatched answer indices must be rejected")
        } catch { XCTAssertEqual(error as? BattlefieldError, .invalidConfiguration) }
        let requests = await client.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testManualRetryHonorsPersistedOverloadWait() async throws {
        let (problem, participant, configuration) = try fixture()
        var saved = CompetitionResult(
            configuration: configuration, problems: [problem], entrants: [participant.entrant])
        var attempt = AnswerAttempt(number: 1)
        attempt.retryAfter = Date.now.addingTimeInterval(28)
        saved.entrants[0].answers[0].attempts = [attempt]
        saved.entrants[0].answers[0].status = .overloaded
        saved.finish(.completed)
        let recorder = RetryQueueRecorder()
        let engine = BattlefieldEngine(
            client: RetryClient(), retrySleep: { delay in await recorder.recordDelay(delay) })
        let result = try await engine.retry(saved, participant: participant, problemID: problem.id) { _ in }
        let delay = await recorder.delay
        XCTAssertGreaterThan(try XCTUnwrap(delay), 25)
        XCTAssertEqual(result.entrants[0].answers[0].attempts.count, 2)
    }

    func testManualRetryCancellationRetainsPreviousAttempt() async throws {
        let (problem, participant, configuration) = try fixture()
        let engine = BattlefieldEngine(client: RetryClient())
        let initial = try await engine.run(
            configuration: configuration, problems: [problem], participants: [participant]
        ) { _ in }
        let result = try await engine.retry(initial, participant: participant, problemID: problem.id) { snapshot in
            if snapshot.entrants[0].answers[0].status == .requesting { await engine.stop() }
        }
        XCTAssertEqual(result.status, .userStopped)
        XCTAssertEqual(result.entrants[0].answers[0].attempts.count, 2)
        XCTAssertEqual(result.entrants[0].answers[0].attempts[0], initial.entrants[0].answers[0].attempts[0])
        XCTAssertNotNil(result.entrants[0].answers[0].attempts[1].finishedAt)
    }
}

private actor RetryQueueRecorder {
    var delay: TimeInterval?
    func recordDelay(_ delay: TimeInterval) { self.delay = delay }
    private var claimed = false
    var duplicateAccepted = false
    func claim() -> Bool {
        if claimed { return false }
        claimed = true
        return true
    }
    func unexpectedDuplicate() { duplicateAccepted = true }
}

private actor RetryClient: AIClient {
    var requests: [AICompletionRequest] = []
    func models(provider: ProviderConfiguration, apiKey: String) async throws -> [AIModel] { [] }
    func complete(_ request: AICompletionRequest, progress: @escaping @Sendable (AIProgress) async -> Void) async throws
        -> AIReply
    {
        requests.append(request)
        return AIReply(
            text: "```h\n\(requests.count == 1 ? "r" : "s")\n```",
            usage: TokenUsage(input: 10, output: 20, estimated: false))
    }
}
