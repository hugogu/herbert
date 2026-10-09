import Foundation

public enum GameStatus: Equatable, Sendable {
    case ready, paused, running, completed, ended
    case failed(String)
}

public enum StepEvent: Equatable, Sendable {
    case moved, turned, blocked, target, trap, completed, waiting, ended
}

/// Undirected edges keep repeated walks visible without growing with execution time.
public struct TrailSegment: Hashable, Sendable {
    public let from: GridPoint
    public let to: GridPoint

    init(from: GridPoint, to: GridPoint) {
        let forward = from.y < to.y || (from.y == to.y && from.x < to.x)
        self.from = forward ? from : to
        self.to = forward ? to : from
    }
}

public struct GameSession {
    public let problem: Problem
    public let board: Board
    public private(set) var position: GridPoint
    public private(set) var heading: Heading = .north
    public private(set) var visitedTargets: Set<GridPoint> = []
    public private(set) var trail: Set<TrailSegment> = []
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

    public var isAccepted: Bool { status == .completed && programBytes <= problem.byteLimit }

    public mutating func prepare(source: String, enforceByteLimit: Bool = true) throws {
        let program = try HProgram.compile(source)
        guard !enforceByteLimit || program.byteCount <= problem.byteLimit else {
            throw HError(HerbertStrings.text("代码用了 %ld byte，本关最多 %ld byte。", program.byteCount, problem.byteLimit))
        }
        position = board.start
        heading = .north
        visitedTargets = []
        trail = []
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
            guard steps < stepLimit else { throw HError(HerbertStrings.text("已达到 100 万步上限。")) }
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
                    trail.insert(TrailSegment(from: position, to: next))
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
