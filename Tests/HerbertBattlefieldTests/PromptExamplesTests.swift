import HerbertCore
import XCTest

@testable import HerbertBattlefield

final class PromptExamplesTests: XCTestCase {
    func testWorkedBoardsAndAnswersPassNativeJudgeAndStayOutsideBenchmark() throws {
        let catalog = try ProblemCatalog.bundled()
        XCTAssertEqual(BattlefieldPrompt.examples.count, 2)
        for example in BattlefieldPrompt.examples {
            XCTAssertFalse(catalog.contains { $0.id == example.problem.id || $0.rows == example.problem.rows })
            let result = try BattlefieldJudge.evaluate(example.program, problem: example.problem)
            XCTAssertTrue(result.accepted, result.feedback)
            XCTAssertEqual(result.bytes, example.problem.byteLimit)
            XCTAssertTrue(BattlefieldPrompt.rules.contains(example.program))
            for row in example.problem.rows { XCTAssertTrue(BattlefieldPrompt.rules.contains(row)) }
        }
        let advanced = try XCTUnwrap(BattlefieldPrompt.examples.last)
        XCTAssertGreaterThan(try Board(problem: advanced.problem).walls.count, 50)
        XCTAssertGreaterThan(try Board(problem: advanced.problem).targets.count, 80)
        XCTAssertTrue(advanced.program.contains("a(N-1,D-2,rrT)Tb(D)rr"))
    }

    func testPromptIncludesUnambiguousCoordinatesAndTerminationRules() throws {
        let example = try XCTUnwrap(BattlefieldPrompt.examples.first)
        let prompt = BattlefieldPrompt.problem(example.problem)
        XCTAssertTrue(prompt.contains("Start: (10,16), facing north"))
        XCTAssertTrue(prompt.contains("Targets (x,y): (10,13), (12,13)"))
        XCTAssertTrue(prompt.contains("Walls: 1; traps: 1"))
        XCTAssertTrue(prompt.contains("00: ........................."))
        XCTAssertTrue(prompt.contains("24: ........................."))
        XCTAssertTrue(prompt.contains("0123456789012345678901234"))
        XCTAssertTrue(BattlefieldPrompt.rules.contains("BEFORE its body runs"))
        XCTAssertTrue(BattlefieldPrompt.rules.contains("s4` does NOT mean four steps"))
        XCTAssertEqual(BattlefieldPrompt.version, "herbert-h-v3")
    }
}
