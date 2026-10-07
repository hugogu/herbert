import Foundation

public struct GridPoint: Codable, Hashable, Sendable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

public enum Heading: Int, Codable, Sendable {
    case north, east, south, west

    public var vector: GridPoint {
        switch self {
        case .north: GridPoint(x: 0, y: -1)
        case .east: GridPoint(x: 1, y: 0)
        case .south: GridPoint(x: 0, y: 1)
        case .west: GridPoint(x: -1, y: 0)
        }
    }

    public func turned(_ amount: Int) -> Heading {
        Heading(rawValue: (rawValue + amount + 4) % 4)!
    }
}

public struct Problem: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let title: String
    public let author: String
    public let byteLimit: Int
    public let originalBest: Int?
    public let sourceURL: String
    public let sourceSHA256: String
    public let rows: [String]

    public init(
        id: Int, title: String, author: String, byteLimit: Int, originalBest: Int? = nil,
        sourceURL: String = "", sourceSHA256: String = "", rows: [String]
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.byteLimit = byteLimit
        self.originalBest = originalBest
        self.sourceURL = sourceURL
        self.sourceSHA256 = sourceSHA256
        self.rows = rows
    }

    public var number: String { String(format: "%04d", id) }
    public var isFoundation: Bool { title.hasPrefix("Problem Set 0 -") }
}

public enum CatalogError: Error, LocalizedError {
    case invalidBoard(Int)
    case missingResource

    public var errorDescription: String? {
        switch self {
        case .invalidBoard(let id): "关卡 \(id) 的棋盘数据无效。"
        case .missingResource: "找不到内置关卡资源。"
        }
    }
}

public struct Board: Sendable {
    public let width: Int
    public let height: Int
    public let start: GridPoint
    public let targets: Set<GridPoint>
    public let traps: Set<GridPoint>
    public let walls: Set<GridPoint>

    public init(problem: Problem) throws {
        guard problem.rows.count == 25, problem.rows.allSatisfy({ $0.count == 25 }) else {
            throw CatalogError.invalidBoard(problem.id)
        }
        var starts: [GridPoint] = []
        var targets: Set<GridPoint> = []
        var traps: Set<GridPoint> = []
        var walls: Set<GridPoint> = []
        for (y, row) in problem.rows.enumerated() {
            for (x, cell) in row.enumerated() {
                let point = GridPoint(x: x, y: y)
                switch cell {
                case "u": starts.append(point)
                case "o": targets.insert(point)
                case "x": traps.insert(point)
                case "*": walls.insert(point)
                case ".": break
                default: throw CatalogError.invalidBoard(problem.id)
                }
            }
        }
        guard starts.count == 1, !targets.isEmpty, problem.byteLimit > 0 else {
            throw CatalogError.invalidBoard(problem.id)
        }
        width = 25
        height = 25
        start = starts[0]
        self.targets = targets
        self.traps = traps
        self.walls = walls
    }

    public func canEnter(_ point: GridPoint) -> Bool {
        (0..<width).contains(point.x) && (0..<height).contains(point.y) && !walls.contains(point)
    }
}

public enum ProblemCatalog {
    public static func bundled() throws -> [Problem] {
        guard let url = Bundle.module.url(forResource: "problems", withExtension: "json") else {
            throw CatalogError.missingResource
        }
        let problems = try JSONDecoder().decode([Problem].self, from: Data(contentsOf: url))
        guard Set(problems.map(\.id)).count == problems.count else { throw CatalogError.missingResource }
        for problem in problems { _ = try Board(problem: problem) }
        return problems.sorted { $0.id < $1.id }
    }
}
