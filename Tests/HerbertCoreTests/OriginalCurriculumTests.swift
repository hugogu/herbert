import Foundation
import HerbertCommunity
import XCTest

@testable import HerbertCore

final class OriginalCurriculumTests: XCTestCase {
    private struct Reference: Decodable {
        let id: Int
        let source: String
    }

    func testCurriculumIsOrderedDistinctAndLocalized() throws {
        let originals = try ProblemCatalog.bundled()
        let community = try CommunityProblemCatalog.bundled()
        XCTAssertEqual(originals.count, 30)
        XCTAssertEqual(community.count, 1769)
        XCTAssertEqual(originals.map(\.id), Array(10001...10030))
        XCTAssertTrue(Set(originals.map(\.id)).isDisjoint(with: community.map(\.id)))
        XCTAssertEqual(Set(originals.map(\.rows)).count, 30)
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
            for _ in 0..<10_000 {
                let event = session.step()
                if event == .trap { traps += 1 }
                XCTAssertNotEqual(event, .blocked, problem.title)
                if session.status != .paused { break }
            }
            XCTAssertEqual(session.status, .completed, "\(problem.number): \(session.status)")
            XCTAssertEqual(traps, problem.id == 10009 ? 1 : 0, problem.title)
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
