import Foundation
import HerbertCore

/// One sequential question stream per entrant, concurrently scheduled across entrants.
/// The actor owns all scores, budget reservations and cancellation decisions.
public actor BattlefieldEngine {
    private let client: any AIClient
    private var result: CompetitionResult?
    private var workers: [UUID: Task<Void, Never>] = [:]
    private var timer: Task<Void, Never>?
    private var deadline: ContinuousClock.Instant?
    private var outputReservations: [UUID: Int] = [:]
    private var observer: (@Sendable (CompetitionResult) async -> Void)?
    private var executing = false

    public init(client: any AIClient) { self.client = client }

    public func run(
        configuration: CompetitionConfiguration, problems: [Problem], participants: [CompetitionParticipant],
        update: @escaping @Sendable (CompetitionResult) async -> Void
    ) async throws -> CompetitionResult {
        guard !executing else { throw BattlefieldError.alreadyRunning }
        _ = try configuration.validated()
        guard !problems.isEmpty, problems.count <= 2000, !participants.isEmpty, participants.count <= 32,
            Set(problems.map(\.id)).count == problems.count,
            Set(participants.map { $0.entrant.id }).count == participants.count
        else {
            throw BattlefieldError.invalidConfiguration
        }
        for problem in problems { _ = try Board(problem: problem) }
        for participant in participants {
            _ = try participant.entrant.provider.validated()
            _ = try participant.entrant.preset.parameters.validated()
            guard !participant.apiKey.isEmpty else { throw BattlefieldError.missingKey }
        }
        executing = true
        defer { executing = false }
        result = CompetitionResult(
            configuration: configuration, problems: problems, entrants: participants.map(\.entrant))
        observer = update
        outputReservations = [:]
        deadline = configuration.mode == .timed ? .now.advanced(by: .seconds(configuration.timeLimitSeconds)) : nil
        await publish()
        if let deadline {
            timer = Task { [weak self] in
                do {
                    try await Task.sleep(until: deadline, clock: .continuous)
                    await self?.stop(reason: .timeLimit)
                } catch {}
            }
        }
        for participant in participants {
            workers[participant.entrant.id] = Task { await self.solve(participant) }
        }
        let tasks = Array(workers.values)
        await withTaskCancellationHandler {
            for task in tasks { await task.value }
        } onCancel: {
            Task { await self.stop(reason: .userStopped) }
        }
        timer?.cancel()
        timer = nil
        workers = [:]
        if result?.status == .running {
            let exhausted = result?.entrants.contains(where: \.exhaustedBudget) == true
            result?.finish(exhausted ? .tokenLimit : .completed)
            await publish()
        }
        observer = nil
        return result!
    }

    public func stop(reason: CompetitionStatus = .userStopped) async {
        guard result?.status == .running else { return }
        result?.finish(reason == .running ? .userStopped : reason)
        timer?.cancel()
        for worker in workers.values { worker.cancel() }
        outputReservations = [:]
        await publish()
    }

    private func publish() async {
        guard var snapshot = result else { return }
        snapshot.updatedAt = .now
        result = snapshot
        await observer?(snapshot)
    }

    private func active() async -> Bool {
        guard result?.status == .running, !Task.isCancelled else { return false }
        if let deadline, ContinuousClock.now >= deadline {
            await stop(reason: .timeLimit)
            return false
        }
        return true
    }

    private func remainingBudget(entrantIndex: Int) -> Int {
        guard let result, result.configuration.mode == .tokenLimited else { return Int.max }
        if result.configuration.tokenBudgetScope == .perModel {
            return max(0, result.configuration.tokenLimit - result.entrants[entrantIndex].totalTokens)
        }
        return max(0, result.configuration.tokenLimit - result.totalTokens)
    }

    /// Reservations bound concurrent output requests; prompt token estimates are reconciled
    /// against provider usage. Providers cannot promise exact billing on an aborted stream.
    private func permit(entrantIndex: Int, messages: [AIMessage], configured: Int) async -> Int? {
        while await active() {
            guard let result else { return nil }
            if result.configuration.mode != .tokenLimited { return configured }
            let entrant = result.entrants[entrantIndex]
            let prompt = TokenUsage.estimate(messages: messages).input
            let budget = remainingBudget(entrantIndex: entrantIndex)
            let reserved =
                result.configuration.tokenBudgetScope == .shared
                ? outputReservations.values.reduce(0, +) : (outputReservations[entrant.id] ?? 0)
            let available = budget - reserved - prompt
            if available > 0 {
                let waiting =
                    result.configuration.tokenBudgetScope == .shared
                    ? max(1, result.entrants.filter { $0.finishedAt == nil && outputReservations[$0.id] == nil }.count)
                    : 1
                let allowance = min(configured, max(1, available / waiting))
                outputReservations[entrant.id] = allowance
                return allowance
            }
            if reserved == 0 {
                self.result?.entrants[entrantIndex].exhaustedBudget = true
                if result.configuration.tokenBudgetScope == .shared { await stop(reason: .tokenLimit) }
                return nil
            }
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return nil }
        }
        return nil
    }

    private func record(_ progress: AIProgress, entrant: Int, problem: Int, attempt: Int) async {
        guard await active(), result!.entrants[entrant].answers[problem].attempts.indices.contains(attempt) else {
            return
        }
        let previous = result!.entrants[entrant].answers[problem].attempts[attempt].usage
        result!.entrants[entrant].answers[problem].attempts[attempt].usage = progress.usage
        result!.entrants[entrant].answers[problem].attempts[attempt].response = progress.text
        result!.entrants[entrant].answers[problem].attempts[attempt].reasoning = progress.reasoning
        if let reservation = outputReservations[result!.entrants[entrant].id] {
            outputReservations[result!.entrants[entrant].id] = max(
                0, reservation - max(0, progress.usage.output - previous.output))
        }
        if !progress.isFinal && result!.configuration.mode == .tokenLimited
            && remainingBudget(entrantIndex: entrant) == 0
        {
            if result!.configuration.tokenBudgetScope == .shared {
                await stop(reason: .tokenLimit)
            } else {
                result!.entrants[entrant].exhaustedBudget = true
                workers[result!.entrants[entrant].id]?.cancel()
                await publish()
            }
        } else {
            await publish()
        }
    }

    private func solve(_ participant: CompetitionParticipant) async {
        guard let e = result?.entrants.firstIndex(where: { $0.id == participant.entrant.id }) else { return }
        let problems = result!.problems
        let maxAttempts = result!.configuration.attemptsPerProblem
        for (p, problem) in problems.enumerated() {
            guard await active(), result?.entrants[e].exhaustedBudget == false else { break }
            var messages = [
                AIMessage(role: "system", content: result!.systemPrompt),
                AIMessage(role: "user", content: BattlefieldPrompt.problem(problem)),
            ]
            for a in 0..<maxAttempts {
                let maximum = min(
                    participant.entrant.preset.parameters.maxOutputTokens,
                    participant.entrant.preset.model.maximumOutputTokens ?? 65_536)
                guard let cap = await permit(entrantIndex: e, messages: messages, configured: maximum),
                    await active()
                else { break }
                var attempt = AnswerAttempt(number: a + 1)
                attempt.requestedMaxOutputTokens = cap
                attempt.usage = .estimate(messages: messages)
                result!.entrants[e].answers[p].attempts.append(attempt)
                result!.entrants[e].answers[p].status = .requesting
                await publish()
                do {
                    try Task.checkCancellation()
                    let reply = try await client.complete(
                        AICompletionRequest(participant: participant, messages: messages, maxOutputTokens: cap)
                    ) { progress in await self.record(progress, entrant: e, problem: p, attempt: a) }
                    outputReservations[participant.entrant.id] = nil
                    guard await active(), result?.entrants[e].exhaustedBudget == false else { break }
                    result!.entrants[e].answers[p].attempts[a].usage = reply.usage
                    result!.entrants[e].answers[p].attempts[a].finishReason = reply.finishReason
                    result!.entrants[e].answers[p].attempts[a].response = reply.text
                    result!.entrants[e].answers[p].attempts[a].reasoning = reply.reasoning
                    result!.entrants[e].answers[p].attempts[a].finishedAt = .now
                    let used =
                        result!.configuration.tokenBudgetScope == .shared
                        ? result!.totalTokens : result!.entrants[e].totalTokens
                    if result!.configuration.mode == .tokenLimited && used > result!.configuration.tokenLimit {
                        if result!.configuration.tokenBudgetScope == .shared {
                            await stop(reason: .tokenLimit)
                        } else {
                            result!.entrants[e].exhaustedBudget = true
                        }
                        break
                    }
                    result!.entrants[e].answers[p].status = .judging
                    await publish()
                    let program: String
                    let evaluation: JudgeEvaluation
                    do {
                        program = try BattlefieldJudge.extractProgram(reply.text)
                        let judge = Task.detached(priority: .userInitiated) {
                            try BattlefieldJudge.evaluate(program, problem: problem)
                        }
                        evaluation = try await withTaskCancellationHandler {
                            try await judge.value
                        } onCancel: {
                            judge.cancel()
                        }
                        result!.entrants[e].answers[p].attempts[a].program = program
                    } catch is CancellationError { throw CancellationError() } catch {
                        evaluation = JudgeEvaluation(
                            accepted: false, bytes: 0, steps: 0, litTargets: 0,
                            targetCount: try Board(problem: problem).targets.count,
                            feedback:
                                reply.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "No final H program was returned. The output allowance (\(cap) tokens) includes reasoning. Finish reason: \(reply.finishReason ?? "unknown"). Return a concise complete fenced H program."
                                : "Invalid response format. Return exactly one fenced H program, no prose, at most 16 KiB."
                        )
                    }
                    guard await active() else { break }
                    result!.entrants[e].answers[p].attempts[a].evaluation = evaluation
                    result!.entrants[e].answers[p].attempts[a].finishedAt = .now
                    result!.entrants[e].answers[p].status =
                        evaluation.accepted ? .solved : (a + 1 == maxAttempts ? .failed : .requesting)
                    if result!.configuration.mode == .bestEffort, p == problems.count - 1,
                        [.solved, .failed].contains(result!.entrants[e].answers[p].status)
                    {
                        result!.entrants[e].finishedAt = .now
                        await stop(reason: .completed)
                        return
                    }
                    await publish()
                    if result!.configuration.mode == .tokenLimited && remainingBudget(entrantIndex: e) == 0 {
                        if result!.configuration.tokenBudgetScope == .shared {
                            await stop(reason: .tokenLimit)
                        } else {
                            result!.entrants[e].exhaustedBudget = true
                        }
                        break
                    }
                    if evaluation.accepted { break }
                    messages = BattlefieldPrompt.retryMessages(
                        messages, reply: reply,
                        feedback: evaluation.feedback
                            + " Battlefield points: \(BattlefieldScoring.coverageAndLengthV1.score(evaluation, byteLimit: problem.byteLimit)). Attempts remaining: \(maxAttempts - a - 1)."
                    )
                } catch {
                    outputReservations[participant.entrant.id] = nil
                    guard result?.status == .running else { return }
                    result!.entrants[e].answers[p].attempts[a].finishedAt = .now
                    result!.entrants[e].answers[p].attempts[a].usage.partial = true
                    if Task.isCancelled || error is CancellationError {
                        result!.entrants[e].answers[p].status = .cancelled
                    } else {
                        // Only persist bounded, credential-redacted provider diagnostics.
                        let message =
                            (error as? AIHTTPError)?.localizedDescription
                            ?? (error as? BattlefieldError)?.rawValue ?? "AI request failed"
                        result!.entrants[e].answers[p].attempts[a].error = message
                        result!.entrants[e].answers[p].status = .error
                        let diagnostic = (error as? AIHTTPError)?.providerResponse.map {
                            ProviderDiagnostics.response(Data($0.utf8), apiKey: participant.apiKey)
                        }
                        result!.entrants[e].answers[p].attempts[a].providerResponse = diagnostic
                        result!.entrants[e].error = message + (diagnostic.map { "\n" + String($0.prefix(512)) } ?? "")
                    }
                    result!.entrants[e].finishedAt = .now
                    for remaining in result!.entrants[e].answers.indices where remaining != p {
                        if result!.entrants[e].answers[remaining].status == .queued {
                            result!.entrants[e].answers[remaining].status = .cancelled
                        }
                    }
                    await publish()
                    return
                }
            }
        }
        outputReservations[participant.entrant.id] = nil
        if result?.status == .running {
            result!.entrants[e].finishedAt = .now
            for p in result!.entrants[e].answers.indices {
                if [.queued, .requesting, .judging].contains(result!.entrants[e].answers[p].status) {
                    result!.entrants[e].answers[p].status = .cancelled
                    if let a = result!.entrants[e].answers[p].attempts.indices.last,
                        result!.entrants[e].answers[p].attempts[a].finishedAt == nil
                    {
                        result!.entrants[e].answers[p].attempts[a].finishedAt = .now
                        result!.entrants[e].answers[p].attempts[a].usage.partial = true
                    }
                }
            }
            await publish()
        }
    }
}
