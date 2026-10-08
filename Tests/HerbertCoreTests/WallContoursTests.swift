import XCTest

@testable import HerbertCore

final class WallContoursTests: XCTestCase {
    private func area(_ contour: [GridPoint]) -> Int {
        zip(contour, contour.dropFirst() + contour.prefix(1)).reduce(0) {
            $0 + $1.0.x * $1.1.y - $1.1.x * $1.0.y
        } / 2
    }

    func testEmptyAndSingleWall() {
        XCTAssertTrue(WallContours.trace([]).isEmpty)
        let contour = WallContours.trace([GridPoint(x: 24, y: 24)])
        XCTAssertEqual(contour.count, 1)
        XCTAssertEqual(contour[0].count, 4)
        XCTAssertEqual(area(contour[0]), 1)
        XCTAssertTrue(contour[0].contains(GridPoint(x: 25, y: 25)))
    }

    func testAdjacentCellsMakeOneContinuousRectangleWithoutInternalEdges() {
        let walls = Set((0..<3).flatMap { y in (0..<2).map { GridPoint(x: $0, y: y) } })
        let contours = WallContours.trace(walls)
        XCTAssertEqual(contours.count, 1)
        XCTAssertEqual(contours[0].count, 10)
        XCTAssertEqual(area(contours[0]), 6)
    }

    func testDiagonalCellsKeepSeparateOutlines() {
        let contours = WallContours.trace([GridPoint(x: 0, y: 0), GridPoint(x: 1, y: 1)])
        XCTAssertEqual(contours.count, 2)
        XCTAssertEqual(contours.map(\.count), [4, 4])
        XCTAssertEqual(contours.map(area), [1, 1])
    }

    func testRingKeepsAnOppositeWindingHoleAndConcaveShapePreservesArea() {
        var ring = Set((0..<3).flatMap { y in (0..<3).map { GridPoint(x: $0, y: y) } })
        ring.remove(GridPoint(x: 1, y: 1))
        let contours = WallContours.trace(ring)
        XCTAssertEqual(contours.count, 2)
        XCTAssertEqual(contours.map(area), [9, -1])
        let elbow = WallContours.trace([GridPoint(x: 0, y: 0), GridPoint(x: 1, y: 0), GridPoint(x: 0, y: 1)])
        XCTAssertEqual(elbow.count, 1)
        XCTAssertEqual(area(elbow[0]), 3)
    }

    func testEveryThreeByThreeArrangementPreservesAreaAndOnlyExposedEdges() {
        for mask in 0..<512 {
            let walls = Set((0..<9).filter { mask & (1 << $0) != 0 }.map { GridPoint(x: $0 % 3, y: $0 / 3) })
            let contours = WallContours.trace(walls)
            XCTAssertEqual(contours.reduce(0) { $0 + area($1) }, walls.count, "mask \(mask)")
            var edgeCount = 0
            for contour in contours {
                for (from, to) in zip(contour, contour.dropFirst() + contour.prefix(1)) {
                    let dx = to.x - from.x
                    let dy = to.y - from.y
                    XCTAssertEqual(abs(dx) + abs(dy), 1)
                    let right: GridPoint
                    let left: GridPoint
                    switch (dx, dy) {
                    case (1, 0):
                        right = from
                        left = GridPoint(x: from.x, y: from.y - 1)
                    case (0, 1):
                        right = GridPoint(x: from.x - 1, y: from.y)
                        left = from
                    case (-1, 0):
                        right = GridPoint(x: to.x, y: to.y - 1)
                        left = to
                    default:
                        right = to
                        left = GridPoint(x: to.x - 1, y: to.y)
                    }
                    XCTAssertTrue(walls.contains(right))
                    XCTAssertFalse(walls.contains(left))
                    edgeCount += 1
                }
            }
            let exposed = walls.reduce(0) { count, p in
                count
                    + [Heading.north, .east, .south, .west].filter {
                        !walls.contains(GridPoint(x: p.x + $0.vector.x, y: p.y + $0.vector.y))
                    }.count
            }
            XCTAssertEqual(edgeCount, exposed)
        }
    }
}
