import Foundation
import HerbertCore

/// One sequential question stream per entrant, concurrently scheduled across entrants.
/// The actor owns all scores, per-problem budgets and cancellation decisions.
public actor BattlefieldEngine {
    private let client: any AIClient
    private var result: CompetitionResult?
    private var workers: [UUID: Task<Void, Never>] = [:]
    private var timer: Task<Void, Never>?
    private var deadline: ContinuousClock.Instant?
    private var requests: [UUID: Task<AIReply, any Error>] = [:]
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
        requests = [:]
        deadline = configuration.timeLimitEnabled ? .now.advanced(by: .seconds(configuration.timeLimitSeconds)) : nil
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
            result?.finish(.completed)
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
        for request in requests.values { request.cancel() }
        requests = [:]
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

    private func remainingBudget(entrant: Int, problem: Int) -> Int? {
        guard let result, result.configuration.problemTokenLimitEnabled else { return nil }
        let used = result.entrants[entrant].answers[problem].attempts.reduce(0) { $0 + $1.usage.total }
        return max(0, result.configuration.problemTokenLimit - used)
    }

    private func allowance(model: AIModel, messages: [AIMessage], remaining: Int?) -> Int? {
        var cap = model.maximumOutputTokens.flatMap { $0 > 0 ? $0 : nil }
        let input = TokenUsage.estimate(messages: messages).input
        if let context = model.contextLength, let maximum = cap {
            cap = min(maximum, max(1, context - input - max(256, input / 10)))
        }
        if let remaining { cap = min(cap ?? Int.max, max(1, remaining - input)) }
        return cap
    }

    private func burnOut(entrant: Int, problem: Int) {
        result!.entrants[entrant].answers[problem].status = .burnout
        if let a = result!.entrants[entrant].answers[problem].attempts.indices.last,
            result!.entrants[entrant].answers[problem].attempts[a].finishedAt == nil
        {
            result!.entrants[entrant].answers[problem].attempts[a].finishedAt = .now
            result!.entrants[entrant].answers[problem].attempts[a].usage.partial = true
        }
    }

    private func record(_ progress: AIProgress, entrant: Int, problem: Int, attempt: Int) async {
        guard await active(), result!.entrants[entrant].answers[problem].status != .burnout,
            result!.entrants[entrant].answers[problem].attempts.indices.contains(attempt)
        else {
            return
        }
        result!.entrants[entrant].answers[problem].attempts[attempt].usage = progress.usage
        result!.entrants[entrant].answers[problem].attempts[attempt].response = progress.text
        result!.entrants[entrant].answers[problem].attempts[attempt].reasoning = progress.reasoning
        if !progress.isFinal, remainingBudget(entrant: entrant, problem: problem) == 0 {
            burnOut(entrant: entrant, problem: problem)
            requests[result!.entrants[entrant].id]?.cancel()
        }
        await publish()
    }

    private func solve(_ participant: CompetitionParticipant) async {
        guard let e = result?.entrants.firstIndex(where: { $0.id == participant.entrant.id }) else { return }
        let problems = result!.problems
        let maxAttempts = result!.configuration.attemptsPerProblem
        for (p, problem) in problems.enumerated() {
            guard await active() else { break }
            var messages = [
                AIMessage(role: "system", content: result!.systemPrompt),
                AIMessage(role: "user", content: BattlefieldPrompt.problem(problem)),
            ]
            for a in 0..<maxAttempts {
                guard await active() else { break }
                let remaining = remainingBudget(entrant: e, problem: p)
                if let remaining, remaining <= TokenUsage.estimate(messages: messages).input {
                    burnOut(entrant: e, problem: p)
                    await publish()
                    break
                }
                let cap = allowance(model: participant.entrant.preset.model, messages: messages, remaining: remaining)
                var attempt = AnswerAttempt(number: a + 1)
                attempt.requestedMaxOutputTokens = cap
                attempt.usage = .estimate(messages: messages)
                result!.entrants[e].answers[p].attempts.append(attempt)
                result!.entrants[e].answers[p].status = .requesting
                await publish()
                do {
                    try Task.checkCancellation()
                    let completion = AICompletionRequest(
                        participant: participant, messages: messages, maxOutputTokens: cap)
                    let request = Task {
                        try await client.complete(
                            completion
                        ) { progress in await self.record(progress, entrant: e, problem: p, attempt: a) }
                    }
                    requests[participant.entrant.id] = request
                    let reply = try await withTaskCancellationHandler {
                        try await request.value
                    } onCancel: {
                        request.cancel()
                    }
                    requests[participant.entrant.id] = nil
                    guard await active() else { break }
                    if result!.entrants[e].answers[p].status == .burnout { break }
                    result!.entrants[e].answers[p].attempts[a].usage = reply.usage
                    result!.entrants[e].answers[p].attempts[a].finishReason = reply.finishReason
                    result!.entrants[e].answers[p].attempts[a].response = reply.text
                    result!.entrants[e].answers[p].attempts[a].reasoning = reply.reasoning
                    result!.entrants[e].answers[p].attempts[a].finishedAt = .now
                    if reply.finishReason == "length"
                        || (remainingBudget(entrant: e, problem: p) == 0
                            && result!.entrants[e].answers[p].attempts.reduce(0, { $0 + $1.usage.total })
                                > result!.configuration.problemTokenLimit)
                    {
                        burnOut(entrant: e, problem: p)
                        await publish()
                        break
                    }
                    if reply.providerFailed {
                        throw AIHTTPError(
                            status: 200,
                            providerResponse:
                                "Provider ended generation with finish_reason: \(reply.finishReason ?? "error").",
                            partialReply: reply)
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
                                ? "No final H program was returned. The output allowance (\(cap.map(String.init) ?? "provider maximum") tokens) includes reasoning. Finish reason: \(reply.finishReason ?? "unknown"). Return a concise complete fenced H program."
                                : "Invalid response format. Return exactly one fenced H program, no prose, at most 16 KiB."
                        )
                    }
                    guard await active() else { break }
                    result!.entrants[e].answers[p].attempts[a].evaluation = evaluation
                    result!.entrants[e].answers[p].attempts[a].finishedAt = .now
                    result!.entrants[e].answers[p].status =
                        evaluation.accepted ? .solved : (a + 1 == maxAttempts ? .failed : .requesting)
                    await publish()
                    if !evaluation.accepted && remainingBudget(entrant: e, problem: p) == 0 {
                        burnOut(entrant: e, problem: p)
                        await publish()
                        break
                    }
                    if evaluation.accepted { break }
                    messages = BattlefieldPrompt.retryMessages(
                        messages, reply: reply,
                        feedback: evaluation.feedback
                            + " Battlefield points: \(BattlefieldScoring.coverageAndLengthV1.score(evaluation, byteLimit: problem.byteLimit)). Attempts remaining: \(maxAttempts - a - 1)."
                    )
                } catch {
                    requests[participant.entrant.id] = nil
                    guard result?.status == .running else { return }
                    if result!.entrants[e].answers[p].status == .burnout { break }
                    if let partial = (error as? AIHTTPError)?.partialReply {
                        result!.entrants[e].answers[p].attempts[a].response = partial.text
                        result!.entrants[e].answers[p].attempts[a].reasoning = partial.reasoning
                        result!.entrants[e].answers[p].attempts[a].finishReason = partial.finishReason
                        result!.entrants[e].answers[p].attempts[a].usage = partial.usage
                    }
                    result!.entrants[e].answers[p].attempts[a].finishedAt = .now
                    result!.entrants[e].answers[p].attempts[a].usage.partial = true
                    if Task.isCancelled || error is CancellationError {
                        result!.entrants[e].answers[p].status = .cancelled
                        break
                    }
                    let failure = ProviderDiagnostics.failure(error, apiKey: participant.apiKey)
                    let message = failure.message
                    let diagnostic = failure.detail
                    result!.entrants[e].answers[p].attempts[a].error = message
                    result!.entrants[e].answers[p].attempts[a].providerResponse = diagnostic

                    let classification = ProviderDiagnostics.classify(
                        error, detail: diagnostic)
                    result!.entrants[e].answers[p].status = classification.status

                    if classification.shouldStopEntrant {
                        result!.entrants[e].error = message + (diagnostic.map { "\n" + String($0.prefix(512)) } ?? "")
                        result!.entrants[e].finishedAt = .now
                        for remaining in result!.entrants[e].answers.indices where remaining != p {
                            if result!.entrants[e].answers[remaining].status == .queued {
                                result!.entrants[e].answers[remaining].status = .cancelled
                            }
                        }
                        await publish()
                        return
                    }

                    if classification.isRetriable && a + 1 < maxAttempts {
                        await publish()
                        continue
                    } else {
                        await publish()
                        break
                    }
                }
            }
        }
        requests[participant.entrant.id] = nil
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
