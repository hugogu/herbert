import HerbertCommunity
import XCTest

@testable import HerbertCore

final class GameAndPersistenceTests: XCTestCase {
    private func problem(cells: [GridPoint: Character], limit: Int = 100) -> Problem {
        var rows = Array(repeating: Array(repeating: Character("."), count: 25), count: 25)
        for (point, cell) in cells { rows[point.y][point.x] = cell }
        return Problem(id: 99, title: "Fixture", author: "Tests", byteLimit: limit, rows: rows.map { String($0) })
    }

    func testEveryImportedBoardIsValidAndIdentifiable() throws {
        let catalog = try CommunityProblemCatalog.bundled()
        XCTAssertFalse(catalog.isEmpty)
        XCTAssertEqual(Set(catalog.map(\.id)).count, catalog.count)
        for item in catalog {
            let board = try Board(problem: item)
            XCTAssertEqual(board.width, 25)
            XCTAssertFalse(board.targets.isEmpty)
            XCTAssertTrue(item.sourceURL.hasSuffix("id=\(item.id)"))
            XCTAssertEqual(item.sourceSHA256.count, 64)
            if let best = item.originalBest { XCTAssertLessThanOrEqual(best, item.byteLimit) }
        }
    }

    func testOriginalProblemOneSolvesAtFourBytesAndPersists() throws {
        let original = try XCTUnwrap(CommunityProblemCatalog.bundled().first { $0.id == 1 })
        var session = try GameSession(problem: original)
        try session.prepare(source: "ssss")
        for _ in 0..<4 { session.step() }
        XCTAssertEqual(session.status, .completed)
        XCTAssertEqual(session.programBytes, 4)
        XCTAssertEqual(session.steps, 4)
        let record = ProblemProgress(
            problemID: 1, draft: "ssss", bestSolution: "ssss", bestBytes: 4,
            completedAt: Date(timeIntervalSince1970: 100), updatedAt: Date(timeIntervalSince1970: 100))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("progress.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repository = LocalProgressRepository(fileURL: url)
        try repository.save(ProgressSnapshot(records: [record], lastProblemID: 1))
        XCTAssertEqual(try repository.load(), ProgressSnapshot(records: [record], lastProblemID: 1))
    }

    func testCommunityBestReferenceIsSeparateFromLimitAndOptional() throws {
        let catalog = try CommunityProblemCatalog.bundled()
        let problem = try XCTUnwrap(catalog.first { $0.id == 3 })
        XCTAssertEqual(problem.byteLimit, 19)
        XCTAssertEqual(problem.originalBest, 8)
        let decoded = try ProblemCatalog.decode(JSONEncoder().encode([problem]))
        XCTAssertEqual(decoded.first?.originalBest, 8)
        XCTAssertEqual(decoded.first?.byteLimit, 19)
        var session = try GameSession(problem: problem)
        try session.prepare(source: String(repeating: "s", count: 19))
        XCTAssertEqual(session.programBytes, 19, "Best is a reference, not the allowed program length")
        XCTAssertNil(try XCTUnwrap(catalog.first { $0.id == 290 }).originalBest)
        XCTAssertTrue(try ProblemCatalog.bundled().allSatisfy { $0.originalBest == nil })
    }

    func testTrapResetsAllPreviouslyPressedTargets() throws {
        let p = problem(cells: [
            GridPoint(x: 1, y: 3): "u", GridPoint(x: 1, y: 2): "o",
            GridPoint(x: 1, y: 1): "*", GridPoint(x: 2, y: 1): "o",
        ])
        var session = try GameSession(problem: p)
        try session.prepare(source: "ssrs")
        XCTAssertEqual(session.step(), .target)
        XCTAssertEqual(session.visitedTargets.count, 1)
        XCTAssertEqual(session.step(), .trap)
        XCTAssertEqual(session.visitedTargets.count, 0)
        XCTAssertEqual(session.position, GridPoint(x: 1, y: 1), "Traps reset lights, not the robot's position")
        session.step()
        session.step()
        XCTAssertNotEqual(session.status, .completed)
    }

    func testWallAndBoundaryBlockMovementWithoutStoppingProgram() throws {
        let p = problem(cells: [GridPoint(x: 0, y: 0): "u", GridPoint(x: 1, y: 0): "x", GridPoint(x: 0, y: 1): "o"])
        var session = try GameSession(problem: p)
        try session.prepare(source: "srsrs")
        XCTAssertEqual(session.step(), .blocked)
        session.step()
        XCTAssertEqual(session.step(), .blocked)
        session.step()
        XCTAssertEqual(session.step(), .completed)
    }

    func testLengthAndExecutionLimits() throws {
        let original = try XCTUnwrap(CommunityProblemCatalog.bundled().first { $0.id == 1 })
        var session = try GameSession(problem: original, stepLimit: 2)
        XCTAssertThrowsError(try session.prepare(source: "sssss"))
        try session.prepare(source: "ssss")
        session.step()
        session.step()
        session.step()
        guard case .failed = session.status else { return XCTFail("Step limit must stop execution") }
    }

    func testTrailIncludesEveryMoveAndSurvivesTrapAndPause() throws {
        let p = problem(cells: [
            GridPoint(x: 1, y: 3): "u", GridPoint(x: 1, y: 2): "o",
            GridPoint(x: 1, y: 1): "*", GridPoint(x: 2, y: 1): "o",
        ])
        var session = try GameSession(problem: p)
        try session.prepare(source: "ssrs")
        session.setRunning(true)
        session.step()
        session.step()
        XCTAssertEqual(session.trail.count, 2)
        XCTAssertTrue(session.visitedTargets.isEmpty)
        session.setRunning(false)
        XCTAssertEqual(session.trail.count, 2)
        session.step()
        XCTAssertEqual(session.trail.count, 2, "Turning must not add a segment")
        session.step()
        XCTAssertEqual(session.trail.count, 3)
        XCTAssertTrue(session.trail.contains(TrailSegment(from: .init(x: 1, y: 3), to: .init(x: 1, y: 2))))
        try session.prepare(source: "s")
        XCTAssertTrue(session.trail.isEmpty)
        XCTAssertTrue(try GameSession(problem: p).trail.isEmpty)
    }

    func testBlockedMovesAddNoTrailAndBatchRetainsAllMoves() throws {
        let p = problem(cells: [GridPoint(x: 0, y: 0): "u", GridPoint(x: 1, y: 0): "x", GridPoint(x: 0, y: 4): "o"])
        var session = try GameSession(problem: p)
        try session.prepare(source: "srsrssss")
        for _ in 0..<8 { session.step() }
        XCTAssertEqual(session.status, .completed)
        XCTAssertEqual(session.trail.count, 4)
        XCTAssertEqual(session.trail.flatMap { [$0.from, $0.to] }.max(by: { $0.y < $1.y })?.y, 4)
    }

    func testRepeatedWalksKeepTrailBounded() throws {
        let p = problem(cells: [GridPoint(x: 2, y: 2): "u", GridPoint(x: 24, y: 24): "o"])
        var session = try GameSession(problem: p)
        try session.prepare(source: "a:srrsrra\na")
        for _ in 0..<60_000 { session.step() }
        XCTAssertEqual(session.steps, 60_000)
        XCTAssertEqual(session.trail.count, 1)
        XCTAssertEqual(session.position, session.board.start)
    }

    func testBackupValidationAndCorruptFileRemainUnchanged() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("progress.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repository = LocalProgressRepository(fileURL: url)
        XCTAssertEqual(try repository.load().records, [])
        try repository.save(ProgressSnapshot(records: [ProblemProgress(problemID: 1, draft: "s")]))
        var future = ProgressSnapshot()
        future.schemaVersion = 2
        XCTAssertThrowsError(try repository.save(future))
        XCTAssertEqual(try repository.load().records.first?.draft, "s")
        XCTAssertThrowsError(try LocalProgressRepository.decode(Data("{bad json}".utf8)))
        let duplicate = ProgressSnapshot(records: [ProblemProgress(problemID: 1), ProblemProgress(problemID: 1)])
        XCTAssertThrowsError(try repository.save(duplicate))
        let fake = ProgressSnapshot(records: [
            ProblemProgress(problemID: 1, bestSolution: "ss", bestBytes: 1, completedAt: .now)
        ])
        XCTAssertThrowsError(try repository.save(fake))
    }
}
