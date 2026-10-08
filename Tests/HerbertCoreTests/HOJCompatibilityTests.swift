import Foundation
import HerbertCommunity
import XCTest

@testable import HerbertCore

final class HOJCompatibilityTests: XCTestCase {
    private struct Fixture: Decodable {
        let name: String
        let source: String
        let commands: String
        let bytes: Int
    }

    func testReferenceLanguageTracesAndByteCounts() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "hoj-compatibility", withExtension: "json"))
        let fixtures = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url))
        for fixture in fixtures {
            let program = try HProgram.compile(fixture.source)
            XCTAssertEqual(program.byteCount, fixture.bytes, fixture.name)
            var machine = HMachine(program: program)
            var commands = ""
            for _ in 0..<10_000 {
                if let command = try machine.nextCommand() { commands.append(command.rawValue) }
                if machine.finished || commands.count >= fixture.commands.count { break }
            }
            XCTAssertEqual(commands, fixture.commands, fixture.name)
        }
    }

    func testCommunityCorridorWallsBlockButContinueTheProgram() throws {
        let problem = try XCTUnwrap(CommunityProblemCatalog.bundled().first { $0.id == 1 })
        let board = try Board(problem: problem)
        XCTAssertTrue(board.walls.contains(GridPoint(x: 11, y: 12)))
        XCTAssertTrue(board.traps.isEmpty)
        // Turn into the corridor's left wall, then resume north and finish.
        var game = try GameSession(
            problem: Problem(
                id: problem.id, title: problem.title, author: problem.author, byteLimit: 7, rows: problem.rows))
        try game.prepare(source: "lsrssss")
        XCTAssertEqual(game.step(), .turned)
        XCTAssertEqual(game.step(), .blocked)
        XCTAssertEqual(game.position, board.start)
        XCTAssertEqual(game.steps, 2)
        XCTAssertTrue(game.trail.isEmpty)
        for _ in 0..<5 { game.step() }
        XCTAssertEqual(game.status, .completed)
        XCTAssertEqual(game.steps, 7)
    }

    func testStarsResetTargetsAndAllowRecovery() throws {
        var rows = Array(repeating: Array(repeating: Character("."), count: 25), count: 25)
        rows[3][1] = "u"
        rows[2][1] = "o"
        rows[1][1] = "*"
        rows[1][2] = "x"
        rows[2][2] = "o"
        let problem = Problem(id: 99, title: "Trap", author: "Tests", byteLimit: 100, rows: rows.map { String($0) })
        var game = try GameSession(problem: problem)
        try game.prepare(source: "ssrsrrslslss")
        XCTAssertEqual(game.step(), .target)
        XCTAssertEqual(game.step(), .trap)
        XCTAssertTrue(game.visitedTargets.isEmpty)
        game.step()
        XCTAssertEqual(game.step(), .blocked)
        XCTAssertEqual(game.position, GridPoint(x: 1, y: 1))
        XCTAssertTrue(game.visitedTargets.isEmpty)
        for _ in 0..<20 {
            game.step()
            if game.status != .paused { break }
        }
        XCTAssertEqual(game.status, .completed)
        XCTAssertEqual(game.visitedTargets.count, 2)
    }

    func testRevisitingALitTargetDoesNotCompleteTheOtherTarget() throws {
        var rows = Array(repeating: Array(repeating: Character("."), count: 25), count: 25)
        rows[3][1] = "u"
        rows[2][1] = "o"
        rows[2][2] = "o"
        let problem = Problem(id: 99, title: "Revisit", author: "Tests", byteLimit: 9, rows: rows.map { String($0) })
        var game = try GameSession(problem: problem)
        try game.prepare(source: "srrsrrsrs")
        for _ in 0..<7 { game.step() }
        XCTAssertEqual(game.visitedTargets.count, 1)
        XCTAssertEqual(game.status, .paused)
        game.step()
        XCTAssertEqual(game.step(), .completed)
        XCTAssertEqual(game.programBytes, 9)
        XCTAssertEqual(game.steps, 9)
        XCTAssertThrowsError(try game.prepare(source: "srrsrrsrss"))
    }

    func testCompletionStopsBeforeTrailingTrapOrInfiniteRecursion() throws {
        let problem = try XCTUnwrap(ProblemCatalog.bundled().first)
        var game = try GameSession(
            problem: Problem(
                id: problem.id, title: problem.title, author: problem.author, byteLimit: 100, rows: problem.rows))
        try game.prepare(source: "a:a\nsa")
        XCTAssertEqual(game.step(), .completed)
        XCTAssertEqual(game.steps, 1)
        XCTAssertEqual(game.step(), .ended)
        XCTAssertEqual(game.steps, 1)
    }

    func testDocumentedNativeValidationDifferences() throws {
        XCTAssertEqual(try HProgram.compile("a(X):s a(X-1)\r\na(12)").byteCount, 8)
        XCTAssertThrowsError(try HProgram.compile("a(X):sa(X-1)\na(256)"))
        var machine = HMachine(program: try HProgram.compile("a(X):sa(X-1)\na(-1)r"))
        XCTAssertEqual(try machine.nextCommand(), .right)
        var unused = HMachine(program: try HProgram.compile("a(X):s\na(s)"))
        XCTAssertEqual(try unused.nextCommand(), .straight)
    }
}
