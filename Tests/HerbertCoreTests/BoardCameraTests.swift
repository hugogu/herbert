import XCTest

@testable import HerbertCore

final class BoardCameraTests: XCTestCase {
    private let flat = BoardCamera(yaw: 0, pitch: .pi / 2, distance: 1_000_000, focusX: 5, focusY: 5)

    func testLookingStraightDownKeepsNorthAtTheTop() {
        let point = flat.project(x: 8, y: 3)
        XCTAssertEqual(point.x, 3, accuracy: 1e-3)
        XCTAssertEqual(point.y, -2, accuracy: 1e-3)
        XCTAssertEqual(point.scale, 1, accuracy: 1e-3)
    }

    func testTheFocusProjectsToTheOriginAtUnitScale() {
        let camera = BoardCamera(yaw: 1.1, pitch: 0.8, focusX: 7, focusY: 9)
        let point = camera.project(x: 7, y: 9)
        XCTAssertEqual(point.x, 0, accuracy: 1e-9)
        XCTAssertEqual(point.y, 0, accuracy: 1e-9)
        XCTAssertEqual(point.scale, 1, accuracy: 1e-9)
    }

    func testHeightLiftsAPointUpTheScreen() {
        let camera = BoardCamera(yaw: 0, pitch: 0.8, focusX: 5, focusY: 5)
        let floor = camera.project(x: 5, y: 5)
        let top = camera.project(x: 5, y: 5, height: 1)
        XCTAssertLessThan(top.y, floor.y)
        XCTAssertEqual(floor.y - top.y, cos(0.8) * top.scale, accuracy: 1e-9)
    }

    func testNearerPointsAreLargerAndLowerOnScreen() {
        let camera = BoardCamera(yaw: 0, pitch: 1, focusX: 5, focusY: 5)
        let far = camera.project(x: 5, y: 0)
        let near = camera.project(x: 5, y: 10)
        XCTAssertGreaterThan(near.scale, 1)
        XCTAssertLessThan(far.scale, 1)
        XCTAssertGreaterThan(near.y, far.y)
        XCTAssertLessThan(near.depth, far.depth)
    }

    func testPositiveYawTurnsTheBoardClockwise() {
        let camera = BoardCamera(yaw: .pi / 2, pitch: .pi / 4, distance: 1_000_000, focusX: 5, focusY: 5)
        let north = camera.project(x: 5, y: 4)
        XCTAssertEqual(north.x, 1, accuracy: 1e-3, "North swings to the right")
        XCTAssertEqual(north.y, 0, accuracy: 1e-3)
        let east = camera.project(x: 6, y: 5)
        XCTAssertEqual(east.x, 0, accuracy: 1e-3)
        XCTAssertGreaterThan(east.y, 0, "East swings toward the viewer")
    }

    func testFramingFitsEveryCornerInsideThePaddingAndCentersIt() {
        let size = CGSize(width: 390, height: 420)
        let padding = 12.0
        for yaw in stride(from: -3.0, through: 3.0, by: 0.75) {
            for pitch in [0.62, 0.98, 1.5] {
                for rect in [
                    FloorRect(minX: 0, minY: 0, maxX: 25, maxY: 25), FloorRect(minX: 6, minY: 4, maxX: 15, maxY: 19),
                ] {
                    let camera = BoardCamera(yaw: yaw, pitch: pitch, focusX: rect.centerX, focusY: rect.centerY)
                    let frame = camera.frame(fitting: rect, heights: -0.4...0.7, in: size, padding: padding)
                    var xs: [Double] = []
                    var ys: [Double] = []
                    for (x, y) in [
                        (rect.minX, rect.minY), (rect.maxX, rect.minY), (rect.maxX, rect.maxY), (rect.minX, rect.maxY),
                    ] {
                        for height in [-0.4, 0.7] {
                            let point = frame.point(camera.project(x: x, y: y, height: height))
                            xs.append(point.x)
                            ys.append(point.y)
                        }
                    }
                    let label = "yaw \(yaw) pitch \(pitch)"
                    XCTAssertGreaterThanOrEqual(xs.min()!, padding - 1e-6, label)
                    XCTAssertLessThanOrEqual(xs.max()!, size.width - padding + 1e-6, label)
                    XCTAssertGreaterThanOrEqual(ys.min()!, padding - 1e-6, label)
                    XCTAssertLessThanOrEqual(ys.max()!, size.height - padding + 1e-6, label)
                    XCTAssertEqual((xs.min()! + xs.max()!) / 2, size.width / 2, accuracy: 1e-6, label)
                    XCTAssertEqual((ys.min()! + ys.max()!) / 2, size.height / 2, accuracy: 1e-6, label)
                    let touchesWidth = abs(xs.max()! - xs.min()! - (size.width - 2 * padding)) < 1e-6
                    let touchesHeight = abs(ys.max()! - ys.min()! - (size.height - 2 * padding)) < 1e-6
                    XCTAssertTrue(touchesWidth || touchesHeight, "The framing should be as large as the view allows")
                }
            }
        }
    }

    func testFramingTreatsATinyViewAsNonEmpty() {
        let frame = BoardCamera().frame(
            fitting: FloorRect(minX: 0, minY: 0, maxX: 25, maxY: 25), heights: 0...0.6, in: .zero, padding: 20)
        XCTAssertGreaterThan(frame.scale, 0)
        XCTAssertTrue(frame.scale.isFinite)
    }

    func testZoomKeepsItsCenterPointAndPanMovesEverything() {
        let frame = BoardFrame(scale: 20, originX: 100, originY: 80)
        let probe = ProjectedPoint(x: 1.5, y: -2, scale: 1, depth: 50)
        let center = CGPoint(x: 130, y: 70)
        let before = frame.point(probe)
        let anchor = ProjectedPoint(x: 1.5, y: -0.5, scale: 1, depth: 50)
        XCTAssertEqual(frame.point(anchor), center)
        let zoomed = frame.zoomed(by: 2, about: center)
        XCTAssertEqual(zoomed.point(anchor).x, center.x, accuracy: 1e-9)
        XCTAssertEqual(zoomed.point(anchor).y, center.y, accuracy: 1e-9)
        XCTAssertEqual(zoomed.scale, 40)
        XCTAssertEqual(zoomed.point(probe).x - center.x, (before.x - center.x) * 2, accuracy: 1e-9)
        let panned = frame.panned(by: CGSize(width: 7, height: -3))
        XCTAssertEqual(panned.point(probe), CGPoint(x: before.x + 7, y: before.y - 3))
        let centered = frame.centering(probe, at: CGPoint(x: 50, y: 60))
        XCTAssertEqual(centered.point(probe).x, 50, accuracy: 1e-9)
        XCTAssertEqual(centered.point(probe).y, 60, accuracy: 1e-9)
    }

    func testNearerBlocksPaintLastAndTiesAreStable() {
        let camera = BoardCamera(yaw: 0, pitch: 1, focusX: 12.5, focusY: 12.5)
        let cells = [GridPoint(x: 12, y: 20), GridPoint(x: 12, y: 3), GridPoint(x: 12, y: 11)]
        XCTAssertEqual(
            camera.drawOrder(of: cells, height: 0.6),
            [GridPoint(x: 12, y: 3), GridPoint(x: 12, y: 11), GridPoint(x: 12, y: 20)])
        let mirrored = [GridPoint(x: 15, y: 9), GridPoint(x: 9, y: 9)]
        XCTAssertEqual(
            camera.drawOrder(of: mirrored, height: 0.6), camera.drawOrder(of: mirrored.reversed(), height: 0.6))
        let turned = BoardCamera(yaw: .pi, pitch: 1, focusX: 12.5, focusY: 12.5)
        XCTAssertEqual(turned.drawOrder(of: cells, height: 0.6).first, GridPoint(x: 12, y: 20))
    }

    func testOnlyFacesTurnedTowardTheEyeAreVisible() {
        let camera = BoardCamera(yaw: 0, pitch: 1, focusX: 12.5, focusY: 12.5)
        let left = GridPoint(x: 4, y: 12)
        let right = GridPoint(x: 20, y: 12)
        XCTAssertTrue(camera.isVisible(.south, ofBlockAt: left))
        XCTAssertFalse(camera.isVisible(.north, ofBlockAt: left))
        XCTAssertTrue(camera.isVisible(.east, ofBlockAt: left), "A block left of the eye shows the side facing it")
        XCTAssertFalse(camera.isVisible(.west, ofBlockAt: left))
        XCTAssertTrue(camera.isVisible(.west, ofBlockAt: right))
        XCTAssertFalse(camera.isVisible(.east, ofBlockAt: right))
        let behind = BoardCamera(yaw: .pi, pitch: 1, focusX: 12.5, focusY: 12.5)
        XCTAssertTrue(behind.isVisible(.north, ofBlockAt: left))
        XCTAssertFalse(behind.isVisible(.south, ofBlockAt: left))
    }

    func testCameraFrameNormalsInvertBackToBoardDirections() {
        let camera = BoardCamera(yaw: 0.9, pitch: 1, focusX: 12.5, focusY: 12.5)
        for side in [Heading.north, .east, .south, .west] {
            let normal = camera.cameraNormal(of: side)
            let board = camera.boardVector(across: normal.across, toward: normal.toward)
            XCTAssertEqual(board.x, Double(side.vector.x), accuracy: 1e-9)
            XCTAssertEqual(board.y, Double(side.vector.y), accuracy: 1e-9)
        }
        let straight = BoardCamera(yaw: 0, pitch: 1)
        XCTAssertEqual(straight.cameraNormal(of: .south).toward, 1, accuracy: 1e-9)
        XCTAssertEqual(straight.cameraNormal(of: .east).across, 1, accuracy: 1e-9)
    }

    func testAWallBetweenTheEyeAndAPointHidesIt() {
        let low = BoardCamera(yaw: 0, pitch: 0.62, focusX: 10.5, focusY: 10.5)
        let towardEye: Set = [GridPoint(x: 10, y: 11)]
        XCTAssertTrue(low.isHidden(x: 10.5, y: 10.5, height: 0.04, behind: towardEye, wallHeight: 0.62))
        XCTAssertFalse(
            low.isHidden(x: 10.5, y: 10.5, height: 0.04, behind: [GridPoint(x: 10, y: 9)], wallHeight: 0.62),
            "A wall behind the point cannot hide it")
        XCTAssertFalse(
            low.isHidden(x: 10.5, y: 10.5, height: 0.04, behind: [GridPoint(x: 13, y: 11)], wallHeight: 0.62),
            "A wall off to the side cannot hide it")
        XCTAssertFalse(
            low.isHidden(x: 10.5, y: 10.5, height: 0.04, behind: [GridPoint(x: 10, y: 14)], wallHeight: 0.62),
            "A distant wall is not considered")
        let steep = BoardCamera(yaw: 0, pitch: 1.5, focusX: 10.5, focusY: 10.5)
        XCTAssertFalse(steep.isHidden(x: 10.5, y: 10.5, height: 0.04, behind: towardEye, wallHeight: 0.62))
        XCTAssertTrue(
            steep.isHidden(x: 10.5, y: 10.5, height: 0.04, behind: towardEye, wallHeight: 10),
            "A tall enough wall hides a point even from a steep view")
    }

    func testRaisedPointsPeekOverLowWalls() {
        let camera = BoardCamera(yaw: 0, pitch: 0.62, focusX: 10.5, focusY: 10.5)
        let wall: Set = [GridPoint(x: 10, y: 11)]
        XCTAssertTrue(camera.isHidden(x: 10.5, y: 10.5, height: 0.04, behind: wall, wallHeight: 0.62))
        XCTAssertFalse(camera.isHidden(x: 10.5, y: 10.5, height: 1.1, behind: wall, wallHeight: 0.62))
    }

    func testAnglesTakeTheShortWayRound() {
        XCTAssertEqual(BoardCamera.equivalentAngle(0.62, nearestTo: 0.62 + 6 * .pi), 0.62 + 6 * .pi, accuracy: 1e-9)
        XCTAssertEqual(BoardCamera.equivalentAngle(0, nearestTo: 7), 2 * .pi, accuracy: 1e-9)
        XCTAssertEqual(BoardCamera.equivalentAngle(0, nearestTo: -7), -2 * .pi, accuracy: 1e-9)
        XCTAssertEqual(Heading.north.angle(nearest: 0), 0, accuracy: 1e-9)
        XCTAssertEqual(Heading.east.angle(nearest: 0), .pi / 2, accuracy: 1e-9)
        XCTAssertEqual(Heading.west.angle(nearest: 0), -.pi / 2, accuracy: 1e-9, "West is a quarter turn left of north")
        XCTAssertEqual(Heading.north.angle(nearest: .pi / 2), 0, accuracy: 1e-9)
        XCTAssertEqual(Heading.north.angle(nearest: 3 * .pi / 2), 2 * .pi, accuracy: 1e-9, "Keep turning right")
        XCTAssertEqual(Heading.south.angle(nearest: 0.1), .pi, accuracy: 1e-9)
    }

    func testPitchStaysInsideTheSupportedRange() {
        XCTAssertEqual(BoardCamera.clampedPitch(0), BoardCamera.pitchRange.lowerBound)
        XCTAssertEqual(BoardCamera.clampedPitch(3), BoardCamera.pitchRange.upperBound)
        XCTAssertEqual(BoardCamera.clampedPitch(1), 1)
        XCTAssertTrue(BoardCamera.pitchRange.contains(BoardCamera.defaultPitch))
    }
}
