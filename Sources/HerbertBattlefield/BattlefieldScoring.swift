import Foundation
import HerbertCore

/// Versioned independently from H semantics; old matches retain their original standings.
public enum BattlefieldScoring: String, Codable, Sendable {
    case legacyAccepted
    case coverageAndLengthV1

    public func score(_ evaluation: JudgeEvaluation, byteLimit: Int) -> Double {
        guard self == .coverageAndLengthV1 else { return evaluation.accepted ? 100 : 0 }
        guard byteLimit > 0, evaluation.bytes > 0, evaluation.bytes <= byteLimit,
            evaluation.targetCount > 0
        else { return 0 }
        let coverage =
            Double(max(0, min(evaluation.litTargets, evaluation.targetCount)))
            / Double(evaluation.targetCount)
        let compactness = 1 - Double(evaluation.bytes) / Double(byteLimit)
        return (coverage * (80 + 20 * compactness) * 100).rounded() / 100
    }

    public func score(_ answer: ProblemAnswer, problem: Problem) -> Double {
        if self == .legacyAccepted { return answer.status == .solved ? 100 : 0 }
        return answer.attempts.compactMap(\.evaluation).map { score($0, byteLimit: problem.byteLimit) }.max() ?? 0
    }

    public func bestAttempt(_ answer: ProblemAnswer, problem: Problem) -> AnswerAttempt? {
        answer.attempts.filter { $0.evaluation != nil }.max {
            score($0.evaluation!, byteLimit: problem.byteLimit) < score($1.evaluation!, byteLimit: problem.byteLimit)
        } ?? answer.attempts.last
    }
}
