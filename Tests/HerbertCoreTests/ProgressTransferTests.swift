import XCTest

@testable import HerbertCore

final class ProgressTransferTests: XCTestCase {
    private func catalog() -> [Problem] {
        var rows = Array(repeating: String(repeating: ".", count: 25), count: 25)
        rows[10] = "............o............"
        rows[11] = "............u............"
        return [Problem(id: 7, title: "Fixture", author: "Tests", byteLimit: 30, rows: rows)]
    }

    func testNewerDraftCannotOverwriteShorterExistingSolution() throws {
        let oldDate = Date(timeIntervalSince1970: 100)
        let newDate = Date(timeIntervalSince1970: 200)
        let old = ProblemProgress(
            problemID: 7, draft: "s", bestSolution: "s", bestBytes: 1, completedAt: oldDate, updatedAt: oldDate)
        let new = ProblemProgress(
            problemID: 7, draft: "ssr", bestSolution: "ss", bestBytes: 2, completedAt: newDate, isFavorite: true,
            updatedAt: newDate)
        let merged = try ProgressTransfer.merge(
            current: ProgressSnapshot(records: [old]), incoming: ProgressSnapshot(records: [new]), catalog: catalog())
        XCTAssertEqual(merged.records[0].draft, "ssr")
        XCTAssertEqual(merged.records[0].bestSolution, "s")
        XCTAssertEqual(merged.records[0].completedAt, oldDate)
        XCTAssertTrue(merged.records[0].isFavorite)
    }

    func testImportsValidSolutionAndRejectsFakeCompletionAndUnknownProblem() throws {
        let valid = ProblemProgress(problemID: 7, bestSolution: "s", bestBytes: 1, completedAt: .now)
        XCTAssertEqual(
            try ProgressTransfer.merge(
                current: ProgressSnapshot(), incoming: ProgressSnapshot(records: [valid]), catalog: catalog()
            ).records.count, 1)
        let fake = ProblemProgress(problemID: 7, bestSolution: "r", bestBytes: 1, completedAt: .now)
        XCTAssertThrowsError(
            try ProgressTransfer.merge(
                current: ProgressSnapshot(), incoming: ProgressSnapshot(records: [fake]), catalog: catalog()))
        let unknown = ProblemProgress(problemID: 8)
        XCTAssertThrowsError(
            try ProgressTransfer.merge(
                current: ProgressSnapshot(), incoming: ProgressSnapshot(records: [unknown]), catalog: catalog()))
    }

    func testIncomingShorterSolutionWinsEvenWithAnOlderTimestamp() throws {
        let old = ProblemProgress(
            problemID: 7, draft: "lr", bestSolution: "ss", bestBytes: 2, completedAt: .now,
            updatedAt: Date(timeIntervalSince1970: 200))
        let new = ProblemProgress(
            problemID: 7, draft: "s", bestSolution: "s", bestBytes: 1, completedAt: .now,
            updatedAt: Date(timeIntervalSince1970: 100))
        let merged = try ProgressTransfer.merge(
            current: ProgressSnapshot(records: [old]), incoming: ProgressSnapshot(records: [new]), catalog: catalog())
        XCTAssertEqual(merged.records[0].draft, "lr")
        XCTAssertEqual(merged.records[0].bestBytes, 1)
    }

    func testEditsMadeDuringBackupValidationArePreserved() throws {
        let incoming = ProgressSnapshot(records: [
            ProblemProgress(problemID: 7, draft: "old", updatedAt: Date(timeIntervalSince1970: 100))
        ])
        let validated = try ProgressTransfer.validate(incoming, catalog: catalog())
        let latest = ProgressSnapshot(records: [
            ProblemProgress(problemID: 7, draft: "new", updatedAt: Date(timeIntervalSince1970: 200))
        ])
        XCTAssertEqual(try ProgressTransfer.merge(current: latest, validated: validated).records[0].draft, "new")
    }
}
