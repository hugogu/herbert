import Foundation
import HerbertCore

public struct AIMessage: Codable, Equatable, Sendable {
    public let role: String
    public let content: String
    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public enum BattlefieldPrompt {
    public static let version = "herbert-h-v1"
    public static let rules = """
        Solve a Herbert programming puzzle using the H language. Return exactly one ```h code block,
        containing the complete program, without explanation. Shorter valid programs are better.
        RULES (herbert-h-v1):
        The board is 25x25. Coordinates are zero-based (x,y), x rightward, y downward.
        u is the robot, initially facing north; o is a target; x is a wall; * is a trap; . is empty.
        s moves forward one cell. l and r rotate left/right 90 degrees without moving.
        Walls and board edges leave the robot in place; execution continues. There is no wall sensor
        or collision branch. Entering a trap clears ALL lit targets. Revisit targets to light them again.
        Execution succeeds and stops immediately when all targets are lit, even if code remains.
        H is case-sensitive. Procedures have single lowercase names other than s/l/r. Define each
        on its own line before exactly one final execution line, e.g. a:sss then a on the last line.
        Parameters are distinct single uppercase letters, e.g. a(X):sa(X-1) then a(3).
        Procedures can recurse and call one another. Arguments can be numbers OR instruction sequences,
        including nested calls and empty instruction arguments. Numeric arguments support + and -;
        literals and evaluated values must stay in [-255,255]. If ANY numeric argument is <=0,
        that entire procedure call is skipped and the caller continues. Instruction parameters
        substitute the supplied sequence; they can be concatenated and passed into other calls.
        Every ASCII letter counts as one byte; each numeric literal counts as ONE byte (12 is one byte).
        Punctuation and whitespace are free. Count definitions, parameters and the execution line.
        The entire program must fit the puzzle's byte limit. Robot steps do not affect score.
        The native judge enforces 1,000,000 robot steps and 1,000,000 VM expansions, bounded memory,
        4096 non-tail call frames, 16 KiB source, and bounded argument nesting. Tail recursion is supported.
        Each accepted puzzle earns 100 points; invalid, over-limit or incomplete programs earn zero.
        You receive native judge feedback after a failed attempt. Do not use Swift, Python, JavaScript,
        loops, if-statements, prose, or code execution tools: submit only an H program.
        """

    public static func problem(_ problem: Problem) -> String {
        """
        Puzzle \(problem.number) (ID \(problem.id)), byte limit: \(problem.byteLimit).
        Board rows in increasing y; each row has 25 cells:
        \(problem.rows.joined(separator: "\n"))
        Light every o using an H program of at most \(problem.byteLimit) bytes.
        """
    }
}

public struct JudgeEvaluation: Codable, Equatable, Sendable {
    public var accepted: Bool
    public var bytes: Int
    public var steps: Int
    public var litTargets: Int
    public var targetCount: Int
    public var feedback: String
}

public enum BattlefieldJudge {
    public static func extractProgram(_ response: String) throws -> String {
        let text = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.utf8.count <= 65_536 else { throw BattlefieldError.responseTooLarge }
        let pieces = text.components(separatedBy: "```")
        if pieces.count == 1 { return text }
        guard pieces.count == 3, let newline = pieces[1].firstIndex(of: "\n") else {
            throw BattlefieldError.invalidResponse
        }
        let language = pieces[1][..<newline].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard ["", "h", "text", "plaintext"].contains(language) else {
            throw BattlefieldError.invalidResponse
        }
        return pieces[1][pieces[1].index(after: newline)...].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func evaluate(_ program: String, problem: Problem) throws -> JudgeEvaluation {
        var session = try GameSession(problem: problem)
        let bytes = HProgram.countBytes(program)
        let targetCount = session.board.targets.count
        do {
            try session.prepare(source: program)
        } catch {
            return JudgeEvaluation(
                accepted: false, bytes: bytes, steps: 0, litTargets: 0,
                targetCount: targetCount,
                feedback:
                    "Rejected: \(error.localizedDescription) Bytes=\(bytes), limit=\(problem.byteLimit). Return a corrected complete H program."
            )
        }
        var ticks = 0
        while session.status == .paused {
            if ticks % 256 == 0 { try Task.checkCancellation() }
            session.step()
            ticks += 1
        }
        let accepted = session.status == .completed
        let missing = session.board.targets.subtracting(session.visitedTargets).sorted {
            $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y
        }.map { "(\($0.x),\($0.y))" }.joined(separator: ",")
        let detail: String
        if case .failed(let message) = session.status {
            detail = "Runtime failure: \(message)."
        } else {
            detail = accepted ? "Accepted." : "Program ended before all targets were lit."
        }
        return JudgeEvaluation(
            accepted: accepted, bytes: bytes, steps: session.steps,
            litTargets: session.visitedTargets.count, targetCount: targetCount,
            feedback:
                "\(detail) Bytes=\(bytes)/\(problem.byteLimit); steps=\(session.steps); lit=\(session.visitedTargets.count)/\(targetCount); final position=(\(session.position.x),\(session.position.y)), heading=\(session.heading). Unlit targets: \(missing)."
                + (accepted ? "" : " Return a corrected complete H program."))
    }
}
