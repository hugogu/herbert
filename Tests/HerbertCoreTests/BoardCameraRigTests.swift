import XCTest

@testable import HerbertCore

final class BoardCameraRigTests: XCTestCase {
    private let size = CGSize(width: 400, height: 300)

    func testANewRigIsTheDefaultView() {
        let rig = BoardCameraRig()
        XCTAssertTrue(rig.isDefault)
        XCTAssertEqual(rig.turn, 0)
        XCTAssertEqual(rig.pitch, BoardCamera.defaultPitch)
        XCTAssertEqual(rig.zoom, 1)
        XCTAssertFalse(rig.follow)
    }

    func testDraggingRightPullsTheNearSideRightAndDownTiltsTowardTopDown() {
        var rig = BoardCameraRig()
        rig.orbit(dx: 100, dy: 0, allowsTilt: true)
        XCTAssertLessThan(rig.turn, 0, "Dragging right turns the board counter-clockwise")
        XCTAssertEqual(rig.turn, -100 * BoardCameraRig.radiansPerPoint, accuracy: 1e-12)
        rig = BoardCameraRig()
        rig.orbit(dx: 0, dy: 40, allowsTilt: true)
        XCTAssertGreaterThan(rig.pitch, BoardCamera.defaultPitch)
        rig.orbit(dx: 0, dy: -4_000, allowsTilt: true)
        XCTAssertEqual(rig.pitch, BoardCamera.pitchRange.lowerBound, "Tilt stops at the lowest supported angle")
        rig.orbit(dx: 0, dy: 40_000, allowsTilt: true)
        XCTAssertEqual(rig.pitch, BoardCamera.pitchRange.upperBound)
    }

    func testVerticalDragsLeaveTheTiltAloneWhenTheyAreReservedForScrolling() {
        var rig = BoardCameraRig()
        rig.orbit(dx: 10, dy: 300, allowsTilt: false)
        XCTAssertEqual(rig.pitch, BoardCamera.defaultPitch)
        XCTAssertNotEqual(rig.turn, 0)
    }

    func testQuarterTurnsAccumulateWithoutWrapping() {
        var rig = BoardCameraRig()
        for _ in 0..<5 { rig.rotate(quarterTurns: 1) }
        XCTAssertEqual(rig.turn, 5 * .pi / 2, accuracy: 1e-12)
        rig.rotate(quarterTurns: -6)
        XCTAssertEqual(rig.turn, -.pi / 2, accuracy: 1e-12)
    }

    func testTiltSwitchesBetweenTheAngledAndSteepViews() {
        var rig = BoardCameraRig()
        rig.toggleTilt()
        XCTAssertEqual(rig.pitch, BoardCameraRig.steepPitch)
        rig.toggleTilt()
        XCTAssertEqual(rig.pitch, BoardCamera.defaultPitch)
        rig.pitch = 1.3
        rig.toggleTilt()
        XCTAssertEqual(rig.pitch, BoardCamera.defaultPitch, "Nearly steep already counts as steep")
        XCTAssertTrue(BoardCamera.pitchRange.contains(BoardCameraRig.steepPitch))
    }

    func testZoomStaysInsideItsRange() {
        var rig = BoardCameraRig()
        rig.zoom(by: 100, about: CGPoint(x: 200, y: 150), in: size)
        XCTAssertEqual(rig.zoom, BoardCameraRig.zoomRange.upperBound)
        rig.zoom(by: 0.0001, about: CGPoint(x: 200, y: 150), in: size)
        XCTAssertEqual(rig.zoom, 1)
        XCTAssertEqual(rig.pan, .zero, "Fully zoomed out always recenters")
    }

    func testZoomingAboutTheCenterNeverPans() {
        var rig = BoardCameraRig()
        rig.zoom(by: 3, about: CGPoint(x: 200, y: 150), in: size)
        XCTAssertEqual(rig.zoom, 3)
        XCTAssertEqual(rig.pan, .zero)
    }

    func testZoomingTowardAPointKeepsThatPointUnderTheFingers() {
        var rig = BoardCameraRig()
        let anchor = CGPoint(x: 330, y: 80)
        // A view point maps to center + (p - center) * zoom + pan; the anchor must not move.
        func screen(_ p: CGPoint, _ rig: BoardCameraRig) -> CGPoint {
            CGPoint(
                x: 200 + (p.x - 200) * rig.zoom + rig.pan.width, y: 150 + (p.y - 150) * rig.zoom + rig.pan.height)
        }
        rig.zoom(by: 2, about: anchor, in: size)
        let content = CGPoint(
            x: (anchor.x - 200 - rig.pan.width) / rig.zoom + 200, y: (anchor.y - 150 - rig.pan.height) / rig.zoom + 150)
        XCTAssertEqual(screen(content, rig).x, anchor.x, accuracy: 1e-9)
        XCTAssertEqual(screen(content, rig).y, anchor.y, accuracy: 1e-9)
        let before = rig
        rig.zoom(by: 1.5, about: CGPoint(x: 120, y: 200), in: size)
        XCTAssertNotEqual(rig.pan, before.pan)
        XCTAssertEqual(rig.zoom, 3, accuracy: 1e-12)
    }

    func testPanNeverRevealsMoreThanTheMagnifiedEdge() {
        var rig = BoardCameraRig()
        rig.pan(by: CGSize(width: 500, height: 500), in: size)
        XCTAssertEqual(rig.pan, .zero, "Nothing to pan at the framed size")
        rig.zoom(by: 2, about: CGPoint(x: 200, y: 150), in: size)
        rig.pan(by: CGSize(width: 900, height: -900), in: size)
        XCTAssertEqual(rig.pan, CGSize(width: 200, height: -150))
        rig.pan(by: CGSize(width: -50, height: 20), in: size)
        XCTAssertEqual(rig.pan, CGSize(width: 150, height: -130))
    }

    func testResetTakesTheShortWayBackToTheOpeningAngle() {
        var rig = BoardCameraRig()
        rig.rotate(quarterTurns: 5)
        rig.toggleTilt()
        rig.zoom(by: 2, about: CGPoint(x: 10, y: 10), in: size)
        rig.follow = true
        XCTAssertFalse(rig.isDefault)
        let spun = rig.turn
        rig.reset()
        XCTAssertTrue(rig.isDefault)
        XCTAssertEqual(rig.turn, 2 * .pi, accuracy: 1e-9, "5 quarter turns is closest to 1 turn")
        XCTAssertLessThan(abs(rig.turn - spun), .pi)
    }

    func testResettingTheFramingKeepsTheAngle() {
        var rig = BoardCameraRig()
        rig.rotate(quarterTurns: 1)
        rig.toggleTilt()
        rig.zoom(by: 4, about: CGPoint(x: 10, y: 10), in: size)
        rig.follow = true
        rig.resetFraming()
        XCTAssertEqual(rig.zoom, 1)
        XCTAssertEqual(rig.pan, .zero)
        XCTAssertFalse(rig.follow)
        XCTAssertEqual(rig.pitch, BoardCameraRig.steepPitch)
        XCTAssertEqual(rig.turn, .pi / 2, accuracy: 1e-12)
    }
}
