import Foundation

public struct ValidatedProgress: Sendable {
    fileprivate let snapshot: ProgressSnapshot
}

public enum ProgressTransfer {
    /// Replay imported completions off the UI thread before they can be merged.
    public static func validate(_ incoming: ProgressSnapshot, catalog: [Problem]) throws -> ValidatedProgress {
        _ = try incoming.validated()
        let problems = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
        guard incoming.records.allSatisfy({ problems[$0.problemID] != nil }),
            incoming.lastProblemID == nil || problems[incoming.lastProblemID!] != nil
        else { throw ProgressError.invalidBackup }
        for record in incoming.records {
            try Task.checkCancellation()
            guard let source = record.bestSolution, let problem = problems[record.problemID] else { continue }
            var game = try GameSession(problem: problem)
            try game.prepare(source: source)
            for tick in 0..<1_000_000 {
                if tick % 1024 == 0 { try Task.checkCancellation() }
                game.step()
                if game.status != .paused { break }
            }
            guard game.status == .completed else { throw ProgressError.invalidBackup }
        }
        return ValidatedProgress(snapshot: incoming)
    }

    public static func merge(current: ProgressSnapshot, incoming: ProgressSnapshot, catalog: [Problem]) throws
        -> ProgressSnapshot
    {
        try merge(current: current, validated: validate(incoming, catalog: catalog))
    }

    /// Merge against the latest local snapshot after asynchronous validation.
    /// This preserves edits made on another screen while a backup is replayed.
    public static func merge(current: ProgressSnapshot, validated: ValidatedProgress) throws -> ProgressSnapshot {
        _ = try current.validated()
        let incoming = validated.snapshot
        var merged = Dictionary(uniqueKeysWithValues: current.records.map { ($0.problemID, $0) })
        for record in incoming.records {
            guard let existing = merged[record.problemID] else {
                merged[record.problemID] = record
                continue
            }
            var value = record.updatedAt > existing.updatedAt ? record : existing
            if let existingBest = existing.bestBytes, existingBest <= (record.bestBytes ?? Int.max) {
                value.bestBytes = existing.bestBytes
                value.bestSolution = existing.bestSolution
                value.completedAt = existing.completedAt
            } else if record.bestBytes != nil {
                value.bestBytes = record.bestBytes
                value.bestSolution = record.bestSolution
                value.completedAt = record.completedAt
            }
            merged[record.problemID] = value
        }
        return ProgressSnapshot(
            records: merged.values.sorted { $0.problemID < $1.problemID },
            lastProblemID: current.lastProblemID ?? incoming.lastProblemID)
    }
}
