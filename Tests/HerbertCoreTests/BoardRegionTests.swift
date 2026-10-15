import XCTest

@testable import HerbertCore

final class BoardRegionTests: XCTestCase {
    private func board(_ cells: [GridPoint: Character]) throws -> Board {
        var rows = Array(repeating: Array(repeating: Character("."), count: 25), count: 25)
        for (point, cell) in cells { rows[point.y][point.x] = cell }
        return try Board(
            problem: Problem(id: 99, title: "Fixture", author: "Tests", byteLimit: 10, rows: rows.map { String($0) }))
    }

    func testFullRegionCoversEveryCell() throws {
        let region = try board([GridPoint(x: 3, y: 3): "u", GridPoint(x: 4, y: 3): "o"]).fullRegion
        XCTAssertEqual(region, CellRegion(minX: 0, minY: 0, maxX: 24, maxY: 24))
        XCTAssertEqual(region.width, 25)
        XCTAssertEqual(region.height, 25)
    }

    func testFocusPadsEveryObjectByTheMargin() throws {
        let board = try board([
            GridPoint(x: 10, y: 12): "u", GridPoint(x: 14, y: 12): "o", GridPoint(x: 12, y: 8): "*",
            GridPoint(x: 12, y: 16): "x",
        ])
        let region = board.focusRegion(position: board.start, trail: [])
        XCTAssertEqual(region, CellRegion(minX: 8, minY: 6, maxX: 16, maxY: 18))
        XCTAssertEqual(region.width, 9)
        XCTAssertEqual(region.height, 13)
        XCTAssertEqual(
            board.focusRegion(position: board.start, trail: [], margin: 0),
            CellRegion(minX: 10, minY: 8, maxX: 14, maxY: 16))
    }

    func testFocusStaysInsideTheBoardAtEveryEdge() throws {
        let corner = try board([GridPoint(x: 0, y: 0): "u", GridPoint(x: 24, y: 24): "o"])
        XCTAssertEqual(corner.focusRegion(position: corner.start, trail: []), corner.fullRegion)
    }

    func testFocusGrowsToIncludeHerbertAndTheTrail() throws {
        let board = try board([GridPoint(x: 10, y: 10): "u", GridPoint(x: 11, y: 10): "o"])
        XCTAssertEqual(
            board.focusRegion(position: board.start, trail: []), CellRegion(minX: 8, minY: 8, maxX: 13, maxY: 12))
        let away = GridPoint(x: 10, y: 18)
        XCTAssertEqual(
            board.focusRegion(position: away, trail: []), CellRegion(minX: 8, minY: 8, maxX: 13, maxY: 20))
        let trail: Set<TrailSegment> = [TrailSegment(from: GridPoint(x: 4, y: 10), to: GridPoint(x: 5, y: 10))]
        XCTAssertEqual(
            board.focusRegion(position: board.start, trail: trail), CellRegion(minX: 2, minY: 8, maxX: 13, maxY: 12))
    }
}
