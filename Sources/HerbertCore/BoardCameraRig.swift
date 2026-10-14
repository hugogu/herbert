import CoreGraphics
import Foundation

/// What a player has done to the 3D camera: orbit, tilt, zoom and pan. The pure rules live here so they can be
/// tested without a view; gestures and buttons only feed values in.
public struct BoardCameraRig: Equatable, Sendable {
    /// How far the player has turned the board from its opening angle, clockwise, in radians. The opening angle
    /// itself depends on the shape of the view (see ``BoardCamera/homeYaw(forAspect:)``).
    public var turn = 0.0
    public var pitch = BoardCamera.defaultPitch
    public var zoom = 1.0
    public var pan = CGSize.zero
    /// Keeps Herbert in the middle of the view while the program runs.
    public var follow = false

    public static let zoomRange: ClosedRange<Double> = 1...6
    /// Following Herbert only means something when zoomed in, so turning it on zooms at least this far.
    public static let followZoom = 2.2
    /// Nearly top-down: easiest for reading a route, at the cost of depth.
    public static let steepPitch = 1.32
    /// Radians of orbit per point of drag.
    public static let radiansPerPoint = 0.0085

    public init() {}

    public var isDefault: Bool {
        zoom == 1 && pan == .zero && !follow && pitch == BoardCamera.defaultPitch
            && abs(BoardCamera.equivalentAngle(0, nearestTo: turn) - turn) < 1e-9
    }

    /// Dragging pulls the near side of the board along with the finger. `dy` only tilts when `allowsTilt` is set.
    public mutating func orbit(dx: Double, dy: Double, allowsTilt: Bool) {
        turn -= dx * Self.radiansPerPoint
        if allowsTilt { pitch = BoardCamera.clampedPitch(pitch + dy * Self.radiansPerPoint * 0.65) }
    }

    /// Positive turns rotate the board clockwise, as seen from above.
    public mutating func rotate(quarterTurns: Int) {
        turn += Double(quarterTurns) * .pi / 2
    }

    public mutating func toggleTilt() {
        pitch = pitch >= Self.steepPitch - 0.12 ? BoardCamera.defaultPitch : Self.steepPitch
    }

    /// Magnifies toward `anchor` (a point in the view) so the spot under the fingers stays put.
    public mutating func zoom(by factor: Double, about anchor: CGPoint, in size: CGSize) {
        let target = min(Self.zoomRange.upperBound, max(Self.zoomRange.lowerBound, zoom * factor))
        let ratio = target / zoom
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        pan = CGSize(
            width: pan.width * ratio + (anchor.x - center.x) * (1 - ratio),
            height: pan.height * ratio + (anchor.y - center.y) * (1 - ratio))
        zoom = target
        clampPan(in: size)
    }

    public mutating func toggleFollow(in size: CGSize) {
        follow.toggle()
        if follow && zoom < Self.followZoom {
            zoom(by: Self.followZoom / zoom, about: CGPoint(x: size.width / 2, y: size.height / 2), in: size)
        }
    }

    public mutating func pan(by delta: CGSize, in size: CGSize) {
        pan = CGSize(width: pan.width + delta.width, height: pan.height + delta.height)
        clampPan(in: size)
    }

    /// Keeps the zoomed picture covering the view: panning can never reveal more than the magnified edge.
    public mutating func clampPan(in size: CGSize) {
        let reachX = (zoom - 1) * size.width / 2
        let reachY = (zoom - 1) * size.height / 2
        pan = CGSize(
            width: min(reachX, max(-reachX, pan.width)), height: min(reachY, max(-reachY, pan.height)))
    }

    /// Back to the opening view, turning the short way round.
    public mutating func reset() {
        turn = BoardCamera.equivalentAngle(0, nearestTo: turn)
        pitch = BoardCamera.defaultPitch
        zoom = 1
        pan = .zero
        follow = false
    }

    /// Frames the whole region again but keeps the chosen angle.
    public mutating func resetFraming() {
        zoom = 1
        pan = .zero
        follow = false
    }
}
