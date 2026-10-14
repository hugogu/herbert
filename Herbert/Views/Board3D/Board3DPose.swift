import HerbertCore
import SwiftUI

/// Everything the 3D board animates between frames: Herbert, the orbiting camera and the framing.
/// Stored as one vector so SwiftUI can interpolate all of it with a single animation.
struct Board3DPose: VectorArithmetic, Equatable {
    private var values: [Double]

    private enum Slot: Int, CaseIterable {
        case robotX, robotY, heading, yaw, pitch, minX, minY, maxX, maxY, zoom, panX, panY, follow
    }

    init(
        robot: GridPoint, headingAngle: Double, yaw: Double = BoardCamera.defaultYaw,
        pitch: Double = BoardCamera.defaultPitch, floor: FloorRect, zoom: Double = 1, pan: CGSize = .zero,
        follow: Double = 0
    ) {
        values = [
            Double(robot.x), Double(robot.y), headingAngle, yaw, pitch, floor.minX, floor.minY, floor.maxX,
            floor.maxY, zoom, Double(pan.width), Double(pan.height), follow,
        ]
    }

    private init(values: [Double]) { self.values = values }

    /// Herbert's position in cells; fractional while the move animates.
    var robotX: Double { values[Slot.robotX.rawValue] }
    var robotY: Double { values[Slot.robotY.rawValue] }
    /// Clockwise from north in radians, unwrapped so turns animate the short way.
    var heading: Double { values[Slot.heading.rawValue] }
    var yaw: Double { values[Slot.yaw.rawValue] }
    var pitch: Double { values[Slot.pitch.rawValue] }
    var floor: FloorRect {
        FloorRect(
            minX: values[Slot.minX.rawValue], minY: values[Slot.minY.rawValue], maxX: values[Slot.maxX.rawValue],
            maxY: values[Slot.maxY.rawValue])
    }
    var zoom: Double { values[Slot.zoom.rawValue] }
    var pan: CGSize { CGSize(width: values[Slot.panX.rawValue], height: values[Slot.panY.rawValue]) }
    /// 0 keeps the user's framing, 1 centers the camera on Herbert.
    var follow: Double { values[Slot.follow.rawValue] }

    static var zero: Board3DPose { Board3DPose(values: Array(repeating: 0, count: Slot.allCases.count)) }

    static func + (lhs: Board3DPose, rhs: Board3DPose) -> Board3DPose {
        Board3DPose(values: zip(lhs.values, rhs.values).map(+))
    }

    static func - (lhs: Board3DPose, rhs: Board3DPose) -> Board3DPose {
        Board3DPose(values: zip(lhs.values, rhs.values).map(-))
    }

    mutating func scale(by rhs: Double) { values = values.map { $0 * rhs } }

    var magnitudeSquared: Double { values.reduce(0) { $0 + $1 * $1 } }
}
