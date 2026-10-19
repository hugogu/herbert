import HerbertCore
import XCTest

@testable import HerbertBattlefield

final class AnswerCancellationTests: XCTestCase {
    private func fixture() throws -> ([Problem], CompetitionParticipant, CompetitionConfiguration) {
        let first = try XCTUnwrap(ProblemCatalog.bundled().first)
        // A copy of the same board under another ID, so one program solves both puzzles.
        let second = Problem(
            id: 90_001, title: first.title, author: first.author, byteLimit: first.byteLimit, rows: first.rows)
        let participant = CompetitionParticipant(
            entrant: Entrant(
                provider: ProviderConfiguration(kind: .compatible), preset: ModelPreset(model: AIModel(id: "test"))),
            apiKey: "fixture")
        return ([first, second], participant, CompetitionConfiguration())
    }

    private func waitUntil(_ condition: @Sendable () async -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while await !condition() {
            guard ContinuousClock.now < deadline else { return XCTFail("Timed out waiting for the client") }
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    func testCancellingAGeneratingPuzzleKeepsItsPartialOutputAndMovesOn() async throws {
        let (problems, participant, configuration) = try fixture()
        let id = participant.entrant.id
        let client = StallingAI(stalling: [problems[0].id])
        let engine = BattlefieldEngine(client: client)
        let run = Task {
            try await engine.run(configuration: configuration, problems: problems, participants: [participant]) { _ in }
        }
        try await waitUntil { await client.streaming.contains(problems[0].id) }
        let queued = await engine.cancelAnswer(entrantID: id, problemID: problems[1].id)
        XCTAssertFalse(queued, "Only a puzzle being generated can be cancelled")
        let cancelled = await engine.cancelAnswer(entrantID: id, problemID: problems[0].id)
        XCTAssertTrue(cancelled)
        let result = try await run.value

        XCTAssertEqual(result.status, .completed)
        let answer = result.entrants[0].answers[0]
        XCTAssertEqual(answer.status, .userCancelled)
        XCTAssertEqual(answer.attempts.count, 1, "A cancelled puzzle gets no further automatic attempts")
        XCTAssertEqual(answer.attempts[0].response, "partial")
        XCTAssertNotNil(answer.attempts[0].finishedAt)
        XCTAssertTrue(answer.attempts[0].usage.partial)
        XCTAssertEqual(result.entrants[0].answers[1].status, .solved)
        let requests = await client.requests.count
        XCTAssertEqual(requests, 2)
        let cancelledRequests = await client.cancelled
        XCTAssertEqual(cancelledRequests, 1)
        let again = await engine.cancelAnswer(entrantID: id, problemID: problems[0].id)
        XCTAssertFalse(again)
        let decoded = try JSONDecoder().decode(CompetitionResult.self, from: JSONEncoder().encode(result))
        XCTAssertEqual(decoded.entrants[0].answers[0].status, .userCancelled)

        XCTAssertTrue(result.canRetry(entrantID: id, problemID: problems[0].id))
        let retried = try await engine.retry(result, participant: participant, problemID: problems[0].id) { _ in }
        XCTAssertEqual(retried.entrants[0].answers[0].status, .solved)
        XCTAssertEqual(retried.entrants[0].answers[0].attempts.map(\.manual), [nil, true])
        XCTAssertEqual(retried.entrants[0].answers[0].attempts[0], answer.attempts[0])
    }

    func testCancelWhilePublishingTheNewAttemptSendsNoRequest() async throws {
        let (problems, participant, configuration) = try fixture()
        let client = StallingAI(stalling: [])
        let engine = BattlefieldEngine(client: client)
        let recorder = CancelRecorder()
        let result = try await engine.run(
            configuration: configuration, problems: problems, participants: [participant]
        ) { snapshot in
            if snapshot.entrants[0].answers[0].status == .requesting, await recorder.claim() {
                let cancelled = await engine.cancelAnswer(
                    entrantID: participant.entrant.id, problemID: problems[0].id)
                await recorder.record(cancelled)
            }
        }
        let accepted = await recorder.accepted
        XCTAssertEqual(accepted, true)
        XCTAssertEqual(result.entrants[0].answers.map(\.status), [.userCancelled, .solved])
        XCTAssertEqual(result.entrants[0].answers[0].attempts.count, 1)
        XCTAssertNotNil(result.entrants[0].answers[0].attempts[0].finishedAt)
        let requests = await client.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].messages[1].content.contains("(ID \(problems[1].id))"))
    }

    func testCancelledPuzzleCanBeRetriedWhileTheMatchRuns() async throws {
        let (problems, participant, configuration) = try fixture()
        let id = participant.entrant.id
        let client = StallingAI(stalling: [problems[0].id])
        let engine = BattlefieldEngine(client: client)
        let run = Task {
            try await engine.run(configuration: configuration, problems: problems, participants: [participant]) { _ in }
        }
        try await waitUntil { await client.streaming.contains(problems[0].id) }
        await engine.cancelAnswer(entrantID: id, problemID: problems[0].id)
        try await engine.enqueueRetry(entrantID: id, problemID: problems[0].id)
        let result = try await run.value

        XCTAssertEqual(result.entrants[0].answers.map(\.status), [.solved, .solved])
        let attempts = result.entrants[0].answers[0].attempts
        XCTAssertEqual(attempts.map(\.manual), [nil, true])
        XCTAssertEqual(attempts[0].response, "partial")
        // The cancelled output was never judged, so the retry starts from the original prompt.
        let requests = await client.requests.filter { $0.messages[1].content.contains("(ID \(problems[0].id))") }
        XCTAssertEqual(requests.map(\.messages.count), [2, 2])
    }

    func testStoppingTheMatchKeepsACancelledPuzzleApartFromStoppedOnes() async throws {
        let (problems, participant, configuration) = try fixture()
        let client = StallingAI(stalling: Set(problems.map(\.id)))
        let engine = BattlefieldEngine(client: client)
        let run = Task {
            try await engine.run(configuration: configuration, problems: problems, participants: [participant]) { _ in }
        }
        try await waitUntil { await client.streaming.contains(problems[0].id) }
        await engine.cancelAnswer(entrantID: participant.entrant.id, problemID: problems[0].id)
        try await waitUntil { await client.streaming.contains(problems[1].id) }
        await engine.stop()
        let result = try await run.value

        XCTAssertEqual(result.status, .userStopped)
        XCTAssertEqual(result.entrants[0].answers.map(\.status), [.userCancelled, .cancelled])
        XCTAssertTrue(result.entrants[0].answers.allSatisfy { $0.attempts.allSatisfy(\.usage.partial) })
        let cancelled = await client.cancelled
        XCTAssertEqual(cancelled, 2)
    }

    func testCancellingAManualRetryOfASavedMatchAllowsAnotherRetry() async throws {
        let (problems, participant, configuration) = try fixture()
        let id = participant.entrant.id
        var saved = CompetitionResult(configuration: configuration, problems: problems, entrants: [participant.entrant])
        saved.entrants[0].answers[0].status = .failed
        saved.finish(.completed)
        let client = StallingAI(stalling: [problems[0].id])
        let engine = BattlefieldEngine(client: client)
        let retry = Task {
            try await engine.retry(saved, participant: participant, problemID: problems[0].id) { _ in }
        }
        try await waitUntil { await client.streaming.contains(problems[0].id) }
        let cancelled = await engine.cancelAnswer(entrantID: id, problemID: problems[0].id)
        XCTAssertTrue(cancelled)
        let result = try await retry.value

        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.entrants[0].answers[0].status, .userCancelled)
        XCTAssertEqual(result.entrants[0].answers[0].attempts.map(\.manual), [true])
        XCTAssertNotNil(result.entrants[0].answers[0].attempts[0].finishedAt)
        XCTAssertTrue(result.canRetry(entrantID: id, problemID: problems[0].id))
    }
}

private actor CancelRecorder {
    private var claimed = false
    var accepted: Bool?
    func claim() -> Bool {
        defer { claimed = true }
        return !claimed
    }
    func record(_ accepted: Bool) { self.accepted = accepted }
}

/// Streams partial output for the first request of each stalled puzzle and then waits until it is cancelled.
/// Every other request is answered at once with a program that solves the first bundled board.
private actor StallingAI: AIClient {
    private var stalled: Set<Int>
    var requests: [AICompletionRequest] = []
    var streaming: [Int] = []
    var cancelled = 0
    init(stalling problemIDs: Set<Int>) { stalled = problemIDs }

    func models(provider: ProviderConfiguration, apiKey: String) async throws -> [AIModel] { [] }
    func complete(_ request: AICompletionRequest, progress: @escaping @Sendable (AIProgress) async -> Void) async throws
        -> AIReply
    {
        requests.append(request)
        let puzzle = request.messages.first { $0.role == "user" }?.content ?? ""
        if let id = stalled.first(where: { puzzle.contains("(ID \($0))") }) {
            stalled.remove(id)
            await progress(AIProgress(text: "partial", usage: TokenUsage(input: 10, output: 5)))
            streaming.append(id)
            do { try await Task.sleep(for: .seconds(30)) } catch {
                cancelled += 1
                throw error
            }
        }
        let text = "```h\ns\n```"
        let usage = TokenUsage(input: 10, output: 20, estimated: false)
        await progress(AIProgress(text: text, usage: usage, isFinal: true))
        return AIReply(text: text, usage: usage)
    }
}
