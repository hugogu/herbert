import XCTest

@testable import HerbertBattlefield

final class ResponseTextLayoutTests: XCTestCase {
    func testSmallResponseRemainsOneSelectableText() {
        let source = "```h\na:ssr\naaa\n```"
        XCTAssertEqual(ResponseTextLayout.blocks(in: source), [source])
        XCTAssertEqual(ResponseTextLayout.blocks(in: ""), [])
    }

    func testMiniMaxShapedResponsePreservesEveryLineWithoutOneHugeLayout() {
        let source = "<think>" + String(repeating: "Let me trace (6,12) → (7,12).\n\n", count: 6091)
        let blocks = ResponseTextLayout.blocks(in: source)
        XCTAssertGreaterThan(blocks.count, 30)
        XCTAssertEqual(blocks.joined(), source)
        XCTAssertTrue(blocks.allSatisfy { $0.count <= 4096 })
        XCTAssertTrue(blocks.dropLast().allSatisfy { $0.hasSuffix("\n") })
    }

    func testUnbrokenLinesAndUnicodeAreBoundedWithoutLosingContent() {
        for source in [String(repeating: "s", count: 20000), String(repeating: "中文👨‍👩‍👧‍👦e\u{301}", count: 3000)] {
            let blocks = ResponseTextLayout.blocks(in: source)
            XCTAssertEqual(blocks.joined(), source)
            XCTAssertTrue(blocks.allSatisfy { $0.count <= 4096 })
        }
    }
}
