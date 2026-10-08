import Foundation
import HerbertCommunity
import XCTest

@testable import HerbertCore

final class OriginalCurriculumTests: XCTestCase {
    private struct PeriodicState: Hashable {
        let position: GridPoint
        let heading: Int
        let visited: Set<GridPoint>
        let phase: Int
    }

    private struct Reference: Decodable {
        let id: Int
        let source: String
        let steps: Int
        let blocked: Int
        let traps: Int
        let endPosition: [Int]
        let endHeading: Int
    }

    func testCurriculumIsOrderedDistinctAndLocalized() throws {
        let originals = try ProblemCatalog.bundled()
        let community = try CommunityProblemCatalog.bundled()
        XCTAssertEqual(originals.count, 50)
        XCTAssertEqual(community.count, 1769)
        XCTAssertEqual(originals.map(\.id), Array(10001...10050))
        XCTAssertTrue(Set(originals.map(\.id)).isDisjoint(with: community.map(\.id)))
        XCTAssertEqual(Set(originals.map(\.rows)).count, 50)
        let archivedBoards = Set(community.map(\.rows))
        for (index, problem) in originals.enumerated() {
            XCTAssertFalse(archivedBoards.contains(problem.rows), problem.title)
            let lesson = try XCTUnwrap(problem.lesson)
            XCTAssertEqual(lesson.order, index + 1)
            XCTAssertEqual(lesson.chapter, index / 5 + 1)
            XCTAssertEqual(lesson.hints.count, 2)
            XCTAssertEqual(problem.number, String(format: "L%02d", index + 1))
            XCTAssertTrue(problem.sourceURL.isEmpty)
            for key in [problem.title, lesson.chapterTitle, lesson.objective] + lesson.hints {
                for language in ["zh-Hans", "ja"] {
                    XCTAssertNotEqual(HerbertStrings.text(key, language: language), key, "\(language): \(key)")
                }
            }
        }
    }

    func testEveryLessonSolvesWithinItsByteLimitWithTheRealEngine() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-solutions", withExtension: "json"))
        let references = try JSONDecoder().decode([Reference].self, from: Data(contentsOf: url))
        let problems = try ProblemCatalog.bundled()
        XCTAssertEqual(references.map(\.id), problems.map(\.id))
        for (problem, reference) in zip(problems, references) {
            var session = try GameSession(problem: problem)
            try session.prepare(source: reference.source)
            XCTAssertLessThanOrEqual(session.programBytes, problem.byteLimit, problem.title)
            var traps = 0
            var blocked = 0
            for _ in 0..<10_000 {
                let event = session.step()
                if event == .trap { traps += 1 }
                if event == .blocked { blocked += 1 }
                if session.status != .paused { break }
            }
            XCTAssertEqual(session.status, .completed, "\(problem.number): \(session.status)")
            XCTAssertEqual(traps, reference.traps, problem.title)
            XCTAssertEqual(blocked, reference.blocked, problem.title)
            XCTAssertEqual(session.steps, reference.steps, problem.title)
            XCTAssertEqual([session.position.x, session.position.y], reference.endPosition, problem.title)
            XCTAssertEqual(session.heading.rawValue, reference.endHeading, problem.title)
        }
    }

    func testAdvancedCourseWallsConstrainEveryRouteAndStopOverruns() throws {
        let problems = try ProblemCatalog.bundled().filter { $0.id > 10030 }
        XCTAssertEqual(problems.count, 20)
        for problem in problems {
            let board = try Board(problem: problem)
            XCTAssertGreaterThan(board.walls.count, 15, problem.title)
            XCTAssertTrue(board.targets.isDisjoint(with: board.walls), problem.title)
            XCTAssertGreaterThan(board.wallContours.count, 0, problem.title)
        }
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-solutions", withExtension: "json"))
        let references = try JSONDecoder().decode([Reference].self, from: Data(contentsOf: url))
        for id in [10031, 10032] {
            let problem = try XCTUnwrap(problems.first { $0.id == id })
            let reference = try XCTUnwrap(references.first { $0.id == id })
            XCTAssertGreaterThan(reference.blocked, 0)
            let unwalled = Problem(
                id: id, title: problem.title, author: problem.author, byteLimit: problem.byteLimit,
                rows: problem.rows.map { $0.replacingOccurrences(of: "x", with: ".") })
            var session = try GameSession(problem: unwalled)
            try session.prepare(source: reference.source)
            for _ in 0..<10_000 {
                session.step()
                if session.status != .paused { break }
            }
            XCTAssertNotEqual(session.status, .completed, "Removing walls must break the stopping strategy")
        }
    }

    func testDiscoveredShortcutsCannotSolveRevisedAdvancedLessons() throws {
        let problems = try ProblemCatalog.bundled()
        for (id, tile) in [(10037, "srsl"), (10044, "ssslslsl")] {
            let problem = try XCTUnwrap(problems.first { $0.id == id })
            var session = try GameSession(problem: problem)
            try session.prepare(source: "a:\(tile)a\na")
            var seen: Set<PeriodicState> = []
            var foundCycle = false
            for _ in 0..<10_000 {
                let event = session.step()
                if event == .waiting { continue }
                XCTAssertNotEqual(session.status, .completed, problem.title)
                let state = PeriodicState(
                    position: session.position, heading: session.heading.rawValue,
                    visited: session.visitedTargets, phase: session.steps % tile.count)
                if !seen.insert(state).inserted {
                    foundCycle = true
                    break
                }
            }
            XCTAssertTrue(foundCycle, "The deterministic shortcut should cycle without solving \(problem.title)")
        }
    }

    func testOriginalProgressAndCommunityProgressKeepTheirIdentities() throws {
        let original = try XCTUnwrap(ProblemCatalog.bundled().first)
        let date = Date(timeIntervalSince1970: 100)
        let snapshot = ProgressSnapshot(
            records: [
                ProblemProgress(
                    problemID: original.id, draft: "s", bestSolution: "s", bestBytes: 1,
                    completedAt: date, updatedAt: date)
            ], lastProblemID: original.id)
        let restored = try LocalProgressRepository.decode(LocalProgressRepository.encode(snapshot))
        let originals = try ProblemCatalog.bundled()
        XCTAssertEqual(
            try ProgressTransfer.merge(current: ProgressSnapshot(), incoming: restored, catalog: originals), snapshot)
        XCTAssertEqual(
            try ProgressTransfer.merge(
                current: ProgressSnapshot(), incoming: restored,
                catalog: originals + CommunityProblemCatalog.bundled()), snapshot)
        let legacy = ProblemProgress(
            problemID: 1, draft: "ssss", bestSolution: "ssss", bestBytes: 4,
            completedAt: date, updatedAt: date)
        let previous = ProgressSnapshot(records: [legacy], lastProblemID: 1)
        let merged = try ProgressTransfer.merge(current: previous, incoming: restored, catalog: originals)
        XCTAssertEqual(merged.records.map(\.problemID), [1, original.id])
        XCTAssertEqual(merged.records.first, legacy)
        XCTAssertEqual(merged.lastProblemID, 1)
        XCTAssertThrowsError(try ProgressTransfer.validate(previous, catalog: originals))
        XCTAssertNoThrow(
            try ProgressTransfer.validate(previous, catalog: originals + CommunityProblemCatalog.bundled()))
    }
}
