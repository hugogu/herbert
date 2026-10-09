import Foundation
import HerbertCore

public struct AIReasoning: Codable, Equatable, Sendable {
    public enum Field: String, Codable, Sendable {
        case content = "reasoning_content"
        case reasoning
    }
    public var content: String
    public let field: Field
    public init(content: String, field: Field = .content) {
        self.content = content
        self.field = field
    }
}

public struct AIMessage: Codable, Equatable, Sendable {
    public let role: String
    public let content: String
    public let reasoning: AIReasoning?
    public let contentBlocks: [AnthropicContentBlock]?
    public init(
        role: String, content: String, reasoning: AIReasoning? = nil, contentBlocks: [AnthropicContentBlock]? = nil
    ) {
        self.role = role
        self.content = content
        self.reasoning = reasoning
        self.contentBlocks = contentBlocks
    }
}

public enum BattlefieldPrompt {
    public static let version = "herbert-h-v4"
    public static let rules =
        baseRules
        + examples.enumerated().map { index, example in
            """

            ## Worked example \(index + 1): \(example.problem.title)

            \(problem(example.problem))

            ```h
            \(example.program)
            ```

            \(example.explanation)
            """
        }.joined(separator: "\n")

    private static let baseRules = """
        # Herbert H programming challenge

        Solve the puzzle using **H**. Return exactly one fenced `h` code block containing
        the complete program, without explanation. Shorter valid programs are better.

        ## Board and movement

        The board is **25 × 25**. Coordinates are zero-based `(x,y)`: x rightward, y downward.
        `u` is the robot, initially facing north; `o` is a target; `x` is a wall;
        `*` is a trap; `.` is empty. `s` moves forward one cell; `l` and `r` rotate
        left/right 90 degrees without moving.

        Walls and board edges leave the robot in place; execution continues. There is
        **no wall sensor or collision branch**. Entering a trap clears **all** lit targets.
        Revisit targets to light them again. Execution succeeds and stops immediately
        when all targets are lit, even if code remains.

        ## Procedures and parameters

        H is case-sensitive. Procedures have single lowercase names other than `s/l/r`.
        Define each on its own line before exactly one final execution line. Parameters
        are distinct single uppercase letters. Procedures can recurse and call one another.
        This example moves forward four cells:

        ```h
        a(X):sa(X-1)
        a(4)
        ```

        For an instruction repeater, `a(N,P):Pa(N-1,P)` followed on the final line by
        `a(3,sr)` runs `srsrsr`. The uppercase P executes the supplied instructions;
        it is not a procedure name. `s4` does NOT mean four steps. Write `ssss` or
        use a counted procedure. Never attach a number to a primitive command.

        Arguments can be numbers **or instruction sequences**, including nested calls and
        empty instruction arguments. Numeric arguments support `+` and `-`; literals and
        evaluated values must stay in `[-255,255]`. If **any numeric argument is ≤ 0**,
        that entire procedure call is skipped BEFORE its body runs, and the caller continues.
        This is the only numeric termination condition; there are no explicit branches. Instruction parameters
        substitute the supplied sequence; they can be concatenated and passed into other calls.

        ## Code length and execution limits

        Every ASCII letter counts as **one byte**; each numeric literal counts as **one byte**
        (`12` is one byte). Punctuation and whitespace are free. Count definitions, parameters
        and the execution line. The entire program must fit the puzzle's byte limit.
        Robot steps do **not** affect score.

        The native judge enforces 1,000,000 robot steps and 1,000,000 VM expansions,
        bounded memory, 4096 non-tail call frames, 16 KiB source, and bounded argument nesting.
        Tail recursion is supported.

        ## Battlefield scoring: coverage-and-length-v1

        **Points = (lit targets / total targets) × (80 + 20 × (1 − bytes / byte limit)).**
        Each evaluated attempt is rounded to two decimal places. Keep the best attempt per
        puzzle; sum these scores across puzzles. Count targets lit at the end of execution,
        after any trap resets. Invalid or over-limit programs earn zero. An incomplete valid
        program can earn partial points. Each puzzle is worth at most 100 points.

        Rank by total score descending, then total input + output tokens ascending, then
        completion time. Include all retries and cached input in token consumption; live or
        cancelled requests may use estimates. This is a Battlefield scoring policy inspired
        by Herbert's shortest-code ranking, not a published HOJ composite score.

        ## Response and retries

        You receive native judge feedback after a failed attempt. Do not use Swift, Python,
        JavaScript, loops, if-statements, prose, or code execution tools: submit only H.
        The output token allowance includes reasoning tokens. Leave room for the final H program.
        The worked examples below are public teaching boards, outside the scored catalog.
        Prompt version: **herbert-h-v4**. All entrants receive the same rules and puzzles.
        """

    public static func messages(for problem: Problem, rules: String = BattlefieldPrompt.rules) -> [AIMessage] {
        [AIMessage(role: "system", content: rules), AIMessage(role: "user", content: self.problem(problem))]
    }

    /// The same initial turn as Battlefield, combined for chat windows with a single input.
    public static func manual(_ problem: Problem) -> String {
        let messages = messages(for: problem)
        return messages[0].content + "\n\n---\n\n## Puzzle to solve\n\n" + messages[1].content
    }

    public static func retryMessages(_ messages: [AIMessage], reply: AIReply, feedback: String) -> [AIMessage] {
        var messages = messages
        if !reply.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append(
                AIMessage(
                    role: "assistant", content: reply.text, reasoning: reply.reasoning,
                    contentBlocks: reply.contentBlocks))
            messages.append(AIMessage(role: "user", content: feedback))
        } else if let last = messages.last, last.role == "user" {
            // A reasoning-only, length-limited turn has no assistant answer to replay.
            messages[messages.count - 1] = AIMessage(
                role: "user", content: last.content + "\n\nJudge feedback: " + feedback)
        } else {
            messages.append(AIMessage(role: "user", content: feedback))
        }
        return messages
    }

    public static func problem(_ problem: Problem) -> String {
        let board = try? Board(problem: problem)
        let targets =
            board?.targets.sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }
            .map { "(\($0.x),\($0.y))" }.joined(separator: ", ") ?? ""
        let rows = problem.rows.enumerated().map { String(format: "%02d: %@", $0.offset, $0.element) }
            .joined(separator: "\n")
        return """
            Puzzle \(problem.number) (ID \(problem.id)), byte limit: \(problem.byteLimit).
            Start: (\(board?.start.x ?? 0),\(board?.start.y ?? 0)), facing north (up).
            Targets (x,y): \(targets)
            Walls: \(board?.walls.count ?? 0); traps: \(board?.traps.count ?? 0).
            Board: y increases downward; x increases rightward. Rulers and row labels are NOT cells.
            ```text
                0000000000111111111122222
                0123456789012345678901234
            \(rows)
            ```
            Light every o using an H program of at most \(problem.byteLimit) bytes.
            Return one complete fenced h block, with definitions first and an execution line last.
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
        let pieces = text.components(separatedBy: "```")
        if pieces.count == 1 {
            guard !text.isEmpty else { throw BattlefieldError.invalidResponse }
            guard text.utf8.count <= 65_536 else { throw BattlefieldError.responseTooLarge }
            return text
        }
        guard pieces.count == 3, let newline = pieces[1].firstIndex(of: "\n") else {
            throw BattlefieldError.invalidResponse
        }
        let language = pieces[1][..<newline].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard ["", "h", "text", "plaintext"].contains(language) else {
            throw BattlefieldError.invalidResponse
        }
        let program = pieces[1][pieces[1].index(after: newline)...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !program.isEmpty else { throw BattlefieldError.invalidResponse }
        guard program.utf8.count <= 65_536 else { throw BattlefieldError.responseTooLarge }
        return program
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
