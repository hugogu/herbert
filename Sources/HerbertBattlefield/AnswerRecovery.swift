import Foundation
import HerbertCore

public struct ProgramSubmission: Equatable, Sendable {
    public enum Source: String, Codable, Sendable { case response, reasoning }
    public let program: String
    public let source: Source
}

extension BattlefieldJudge {
    /// Reasoning is considered only when the model explicitly labels a final answer.
    /// Never select an arbitrary intermediate code block or merge competing candidates.
    public static func submission(in reply: AIReply) throws -> ProgramSubmission {
        let response = reply.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let strict = try? extractProgram(response)
        if let strict, response.contains("```") || (try? HProgram.compile(strict)) != nil {
            return ProgramSubmission(program: strict, source: .response)
        }
        if let program = explicitFinal(response) ?? singleUnclosedFence(response) {
            return ProgramSubmission(program: program, source: .response)
        }
        if let reasoning = reply.reasoning?.content, let program = explicitFinal(reasoning) {
            return ProgramSubmission(program: program, source: .reasoning)
        }
        if let strict { return ProgramSubmission(program: strict, source: .response) }
        throw BattlefieldError.invalidResponse
    }

    private static func explicitFinal(_ text: String) -> String? {
        let pattern =
            #"(?im)^\s*(?:#{1,6}\s*)?(?:\*\*)?(?:final answer|final program|最终答案|最终回答|最終回答)(?:\*\*)?\s*[:：]?\s*(?:\*\*)?\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).last,
            let range = Range(match.range, in: text)
        else { return nil }
        let suffix = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if let program = try? extractProgram(suffix),
            suffix.contains("```") || (try? HProgram.compile(program)) != nil
        {
            return program
        }
        return singleUnclosedFence(suffix)
    }

    private static func singleUnclosedFence(_ text: String) -> String? {
        let parts = text.components(separatedBy: "```")
        guard parts.count == 2, let newline = parts[1].firstIndex(of: "\n"),
            ["", "h", "text", "plaintext"].contains(
                parts[1][..<newline].trimmingCharacters(in: .whitespaces).lowercased())
        else { return nil }
        let program = String(parts[1][parts[1].index(after: newline)...]).trimmingCharacters(
            in: .whitespacesAndNewlines)
        guard (try? HProgram.compile(program)) != nil else { return nil }
        return program
    }
}

extension AnswerAttempt {
    /// Also makes previously saved, explicitly marked answers available for manual trials.
    public var trialSubmission: ProgramSubmission? {
        if let program, !program.isEmpty {
            return ProgramSubmission(program: program, source: programSource ?? .response)
        }
        return try? BattlefieldJudge.submission(
            in: AIReply(text: response, usage: usage, reasoning: reasoning))
    }
}
