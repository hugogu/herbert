import Foundation

/// A rectangle of floor in cell-edge coordinates: cell (x, y) spans `x..<x + 1` and `y..<y + 1`.
public struct FloorRect: Equatable, Sendable {
    public var minX: Double
    public var minY: Double
    public var maxX: Double
    public var maxY: Double

    public init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }

    public init(_ region: CellRegion) {
        self.init(
            minX: Double(region.minX), minY: Double(region.minY), maxX: Double(region.maxX + 1),
            maxY: Double(region.maxY + 1))
    }

    public var centerX: Double { (minX + maxX) / 2 }
    public var centerY: Double { (minY + maxY) / 2 }
}

/// A board point seen through a ``BoardCamera``. Units are cells at the camera's focus, so `x` grows to the right
/// and `y` grows downward, like a view's coordinate space.
public struct ProjectedPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double
    /// Perspective magnification relative to the focus point: above 1 is closer to the eye.
    public var scale: Double
    /// Distance from the eye plane along the viewing direction.
    public var depth: Double
}

/// Places projected points in a view: where the focus point lands and how many points one cell spans there.
public struct BoardFrame: Equatable, Sendable {
    public var scale: Double
    public var originX: Double
    public var originY: Double

    public init(scale: Double, originX: Double, originY: Double) {
        self.scale = scale
        self.originX = originX
        self.originY = originY
    }

    public func point(_ projected: ProjectedPoint) -> CGPoint {
        CGPoint(x: originX + scale * projected.x, y: originY + scale * projected.y)
    }

    /// Magnifies the picture around a view point, which stays where it is.
    public func zoomed(by factor: Double, about center: CGPoint) -> BoardFrame {
        BoardFrame(
            scale: scale * factor, originX: center.x + (originX - center.x) * factor,
            originY: center.y + (originY - center.y) * factor)
    }

    public func panned(by offset: CGSize) -> BoardFrame {
        BoardFrame(scale: scale, originX: originX + offset.width, originY: originY + offset.height)
    }

    /// Moves the picture so `projected` lands on `center`.
    public func centering(_ projected: ProjectedPoint, at center: CGPoint) -> BoardFrame {
        BoardFrame(scale: scale, originX: center.x - scale * projected.x, originY: center.y - scale * projected.y)
    }
}

/// An orbiting perspective camera for the 3D board. Cells are one unit wide and heights are in cells above the
/// floor. The camera looks at a floor point from `distance` cells away.
public struct BoardCamera: Equatable, Sendable {
    /// Clockwise rotation of the board seen from above, in radians. Zero keeps north at the top of the screen.
    public let yaw: Double
    /// Elevation of the eye above the floor, in radians. π/2 looks straight down.
    public let pitch: Double
    /// Eye distance from the focus in cells. Larger values flatten the perspective.
    public let distance: Double
    public let focusX: Double
    public let focusY: Double
    private let sinYaw: Double
    private let cosYaw: Double
    private let sinPitch: Double
    private let cosPitch: Double
    private let eyeX: Double
    private let eyeY: Double
    private let eyeZ: Double

    public static let defaultYaw = 0.62
    public static let defaultPitch = 0.98
    public static let defaultDistance = 52.0
    /// Low enough to feel three-dimensional, high enough that a wall never hides more than the next cell.
    public static let pitchRange: ClosedRange<Double> = 0.62...1.50

    public init(
        yaw: Double = BoardCamera.defaultYaw, pitch: Double = BoardCamera.defaultPitch,
        distance: Double = BoardCamera.defaultDistance, focusX: Double = 12.5, focusY: Double = 12.5
    ) {
        self.yaw = yaw
        self.pitch = pitch
        self.distance = distance
        self.focusX = focusX
        self.focusY = focusY
        sinYaw = sin(yaw)
        cosYaw = cos(yaw)
        sinPitch = sin(pitch)
        cosPitch = cos(pitch)
        eyeX = focusX + distance * cos(pitch) * sin(yaw)
        eyeY = focusY + distance * cos(pitch) * cos(yaw)
        eyeZ = distance * sin(pitch)
    }

    public static func clampedPitch(_ pitch: Double) -> Double {
        min(pitchRange.upperBound, max(pitchRange.lowerBound, pitch))
    }

    /// The angle equal to `target` (modulo a full turn) that lies closest to `current`, so animating between
    /// them takes the short way round.
    public static func equivalentAngle(_ target: Double, nearestTo current: Double) -> Double {
        let turn = 2 * Double.pi
        return target + turn * ((current - target) / turn).rounded()
    }

    public func project(x: Double, y: Double, height: Double = 0) -> ProjectedPoint {
        let dx = x - focusX
        let dy = y - focusY
        let across = dx * cosYaw - dy * sinYaw
        let toward = dx * sinYaw + dy * cosYaw
        let depth = max(1, distance - (toward * cosPitch + height * sinPitch))
        let scale = distance / depth
        return ProjectedPoint(
            x: across * scale, y: (toward * sinPitch - height * cosPitch) * scale, scale: scale, depth: depth)
    }

    /// Frames `rect` and everything standing on it between the heights in `heights`, centered in `size` with
    /// `padding` points to spare on every side.
    public func frame(
        fitting rect: FloorRect, heights: ClosedRange<Double>, in size: CGSize, padding: Double = 0
    ) -> BoardFrame {
        var minX = Double.infinity
        var maxX = -Double.infinity
        var minY = Double.infinity
        var maxY = -Double.infinity
        for (x, y) in [(rect.minX, rect.minY), (rect.maxX, rect.minY), (rect.maxX, rect.maxY), (rect.minX, rect.maxY)] {
            for height in [heights.lowerBound, heights.upperBound] {
                let point = project(x: x, y: y, height: height)
                minX = min(minX, point.x)
                maxX = max(maxX, point.x)
                minY = min(minY, point.y)
                maxY = max(maxY, point.y)
            }
        }
        let scale = min(
            max(1, Double(size.width) - 2 * padding) / max(0.001, maxX - minX),
            max(1, Double(size.height) - 2 * padding) / max(0.001, maxY - minY))
        return BoardFrame(
            scale: scale, originX: Double(size.width) / 2 - scale * (minX + maxX) / 2,
            originY: Double(size.height) / 2 - scale * (minY + maxY) / 2)
    }

    // MARK: Painter's algorithm

    /// Squared distance from the eye, which orders objects for painting.
    public func eyeDistanceSquared(x: Double, y: Double, height: Double) -> Double {
        let dx = x - eyeX
        let dy = y - eyeY
        let dz = height - eyeZ
        return dx * dx + dy * dy + dz * dz
    }

    /// Cells holding blocks of the given heights, farthest from the eye first, so nearer blocks paint over
    /// farther ones.
    public func drawOrder<Cells: Sequence>(of cells: Cells, height: (GridPoint) -> Double) -> [GridPoint]
    where Cells.Element == GridPoint {
        cells.map {
            (
                cell: $0,
                distance: eyeDistanceSquared(x: Double($0.x) + 0.5, y: Double($0.y) + 0.5, height: height($0) / 2)
            )
        }
        .sorted { first, second in
            first.distance != second.distance
                ? first.distance > second.distance : (first.cell.y, first.cell.x) < (second.cell.y, second.cell.x)
        }
        .map(\.cell)
    }

    /// Whether the vertical face of a block on `side` turns toward the eye.
    public func isVisible(_ side: Heading, ofBlockAt cell: GridPoint) -> Bool {
        let vector = side.vector
        let faceX = Double(cell.x) + 0.5 + 0.5 * Double(vector.x)
        let faceY = Double(cell.y) + 0.5 + 0.5 * Double(vector.y)
        return (eyeX - faceX) * Double(vector.x) + (eyeY - faceY) * Double(vector.y) > 0
    }

    /// Whether a horizontal direction at a board position points toward the eye rather than away from it.
    public func isFacingEye(direction: (x: Double, y: Double), atX x: Double, y: Double) -> Bool {
        (eyeX - x) * direction.x + (eyeY - y) * direction.y > 0
    }

    /// A face's outward normal in the camera's frame: `across` points right and `toward` points at the viewer.
    public func cameraNormal(of side: Heading) -> (across: Double, toward: Double) {
        let vector = side.vector
        let x = Double(vector.x)
        let y = Double(vector.y)
        return (x * cosYaw - y * sinYaw, x * sinYaw + y * cosYaw)
    }

    /// Converts a floor direction given in the camera's frame back to board coordinates.
    public func boardVector(across: Double, toward: Double) -> (x: Double, y: Double) {
        (across * cosYaw + toward * sinYaw, -across * sinYaw + toward * cosYaw)
    }

    /// Whether a wall block stands between the eye and the point, hiding it from view. Only walls close to the
    /// point can hide it, because the camera never looks along the floor.
    public func isHidden(
        x: Double, y: Double, height: Double, behind walls: Set<GridPoint>, wallHeight: Double
    ) -> Bool {
        let cellX = Int(x.rounded(.down))
        let cellY = Int(y.rounded(.down))
        let origin = (eyeX, eyeY, eyeZ)
        let direction = (x - eyeX, y - eyeY, height - eyeZ)
        for wallY in (cellY - 2)...(cellY + 2) {
            for wallX in (cellX - 2)...(cellX + 2) where !(wallX == cellX && wallY == cellY) {
                guard walls.contains(GridPoint(x: wallX, y: wallY)) else { continue }
                var entry = 0.0
                var exit = 1.0
                let slabs = [
                    (origin.0, direction.0, Double(wallX), Double(wallX + 1)),
                    (origin.1, direction.1, Double(wallY), Double(wallY + 1)),
                    (origin.2, direction.2, 0, wallHeight),
                ]
                var crosses = true
                for (start, delta, low, high) in slabs {
                    if abs(delta) < 1e-12 {
                        if start < low || start > high { crosses = false }
                        continue
                    }
                    let first = (low - start) / delta
                    let second = (high - start) / delta
                    entry = max(entry, min(first, second))
                    exit = min(exit, max(first, second))
                }
                if crosses && entry < exit - 1e-9 { return true }
            }
        }
        return false
    }
}

extension Heading {
    /// Clockwise angle from north in radians.
    public var angle: Double { Double(rawValue) * .pi / 2 }

    /// The angle for this heading that is closest to `current`, so a turn animates by a quarter or half turn and
    /// never unwinds earlier turns.
    public func angle(nearest current: Double) -> Double {
        BoardCamera.equivalentAngle(angle, nearestTo: current)
    }
}
