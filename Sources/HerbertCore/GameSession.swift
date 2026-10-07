import Foundation

public enum GameStatus: Equatable, Sendable {
    case ready, paused, running, completed, ended
    case failed(String)
}

public enum StepEvent: Equatable, Sendable {
    case moved, turned, blocked, target, trap, completed, waiting, ended
}

public struct GameSession {
    public let problem: Problem
    public let board: Board
    public private(set) var position: GridPoint
    public private(set) var heading: Heading = .north
    public private(set) var visitedTargets: Set<GridPoint> = []
    public private(set) var steps = 0
    public private(set) var status: GameStatus = .ready
    public private(set) var lastCommand: HCommand?
    public private(set) var programBytes = 0
    private var machine: HMachine?
    private let stepLimit: Int

    public init(problem: Problem, stepLimit: Int = 1_000_000) throws {
        self.problem = problem
        board = try Board(problem: problem)
        position = board.start
        self.stepLimit = stepLimit
    }

    public mutating func prepare(source: String) throws {
        let program = try HProgram.compile(source)
        guard program.byteCount <= problem.byteLimit else {
            throw HError("代码用了 \(program.byteCount) byte，本关最多 \(problem.byteLimit) byte。")
        }
        position = board.start
        heading = .north
        visitedTargets = []
        steps = 0
        lastCommand = nil
        programBytes = program.byteCount
        machine = HMachine(program: program)
        status = .paused
    }

    public mutating func setRunning(_ running: Bool) {
        if status == .paused || status == .running { status = running ? .running : .paused }
    }

    @discardableResult
    public mutating func step() -> StepEvent {
        guard status == .paused || status == .running else { return .ended }
        do {
            guard let command = try machine?.nextCommand() else {
                if machine?.finished == true {
                    status = .ended
                    return .ended
                }
                return .waiting
            }
            guard steps < stepLimit else { throw HError("已达到 100 万步上限。") }
            steps += 1
            lastCommand = command
            var event = StepEvent.turned
            switch command {
            case .left: heading = heading.turned(-1)
            case .right: heading = heading.turned(1)
            case .straight:
                let vector = heading.vector
                let next = GridPoint(x: position.x + vector.x, y: position.y + vector.y)
                if board.canEnter(next) {
                    position = next
                    event = .moved
                    if board.traps.contains(next) {
                        visitedTargets.removeAll()
                        event = .trap
                    }
                    if board.targets.contains(next) {
                        visitedTargets.insert(next)
                        event = .target
                    }
                } else {
                    event = .blocked
                }
            }
            if visitedTargets == board.targets {
                status = .completed
                return .completed
            }
            return event
        } catch {
            status = .failed(error.localizedDescription)
            return .ended
        }
    }
}
