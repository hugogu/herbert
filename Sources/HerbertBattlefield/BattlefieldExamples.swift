// Public teaching examples. These are intentionally separate from scored puzzle answers.
import HerbertCore

public struct BattlefieldWorkedExample: Sendable {
    public let problem: Problem
    public let program: String
    public let explanation: String
}

extension BattlefieldPrompt {
    public static let examples: [BattlefieldWorkedExample] = [
        BattlefieldWorkedExample(
            problem: Problem(
                id: -101, title: "Blocked step, then turn", author: "Herbert", byteLimit: 7,
                rows: [
                    ".........................",
                    ".........................",
                    ".........................",
                    ".........................",
                    ".........................",
                    ".........................",
                    ".........................",
                    ".........................",
                    ".........................",
                    ".........................",
                    ".........................",
                    ".........................",
                    "..........x..............",
                    "..........o.o............",
                    "...........*.............",
                    ".........................",
                    "..........u..............",
                    ".........................",
                    ".........................",
                    ".........................",
                    ".........................",
                    ".........................",
                    ".........................",
                    ".........................",
                    ".........................",
                ]),
            program: """
                ssssrss
                """,
            explanation: """
                The first three s commands reach (10,13) and light the first target. The fourth s
                hits the wall at (10,12), leaving the robot at (10,13), facing north. r turns it
                east without moving. Two s commands reach (12,13), lighting the second target.
                The trap at (11,14) is never entered. The blocked step is intentional for teaching;
                this 7-byte answer is valid, but is not the shortest answer.
                """),
        BattlefieldWorkedExample(
            problem: Problem(
                id: -102, title: "Recursive pinwheel", author: "Herbert", byteLimit: 42,
                rows: [
                    ".........................",
                    ".........................",
                    ".........................",
                    ".........................",
                    "............oooo.........",
                    "............o..o.........",
                    "......xxxxxxoxxooxx......",
                    "......xooooooooooox......",
                    "......ooxxxxoxxxxox......",
                    "....ooooxxxxoxxxxox......",
                    "....o.xoxxxxoxxxxox......",
                    "....o.xoxxxxoxxxxox......",
                    "....oooooooouoooooooo....",
                    "......xoxxxxoxxxxox.o....",
                    "......xoxxxxoxxxxox.o....",
                    "......xoxxxxoxxxxoooo....",
                    "......xoxxxxoxxxxoo......",
                    "......xooooooooooox......",
                    "......xxooxxoxxxxxx......",
                    ".........o..o............",
                    ".........oooo............",
                    ".........................",
                    ".........................",
                    ".........................",
                    ".........................",
                ]),
            program: """
                b(N):sb(N-1)
                q(P):PPPP
                a(N,D,T):q(b(D)T)b(D)Ta(N-1,D-2,rrT)Tb(D)rr
                q(a(3,5,r)r)
                """,
            explanation: """
                b(N) walks exactly N cells: b(1) executes s, then b(0) is skipped.
                q(P) runs its instruction argument four times. q(b(D)T) therefore traces a square.
                a has two numeric parameters N/D and an instruction parameter T. After a square,
                it travels to a smaller square and calls itself with N-1 and D-2. Prefixing rr
                to T reverses its effective quarter-turn direction. When N reaches zero, that
                recursive call is skipped; execution continues with Tb(D)rr, restoring the caller's
                position and heading. This work AFTER recursion is essential. The final q rotates
                the entire motif four ways. Walls fill unused space and reveal the route's shape.
                This is a separate teaching board, not L50 or another scored benchmark puzzle.
                """),
    ]
}
