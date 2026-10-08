import Foundation
import HerbertCommunity
import XCTest

@testable import HerbertCore

final class CommunityStudyTests: XCTestCase {
    private struct Reference: Decodable {
        let id: Int
        let source: String
    }

    func testIndependentlyFoundCommunityStudySolutionsMeetOriginalBudgets() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "community-study-solutions", withExtension: "json"))
        let references = try JSONDecoder().decode([Reference].self, from: Data(contentsOf: url))
        let catalog = try CommunityProblemCatalog.bundled()
        XCTAssertEqual(references.map(\.id), [1, 2, 3, 4, 5, 6, 9, 14])
        for reference in references {
            let problem = try XCTUnwrap(catalog.first { $0.id == reference.id })
            var session = try GameSession(problem: problem)
            try session.prepare(source: reference.source)
            XCTAssertLessThanOrEqual(session.programBytes, problem.byteLimit)
            for _ in 0..<10_000 {
                session.step()
                if session.status != .paused { break }
            }
            XCTAssertEqual(session.status, .completed, "Community #\(reference.id)")
        }
    }
}
