import Foundation

/// An inclusive rectangle of board cells.
public struct CellRegion: Equatable, Sendable {
    public var minX: Int
    public var minY: Int
    public var maxX: Int
    public var maxY: Int

    public init(minX: Int, minY: Int, maxX: Int, maxY: Int) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }

    public var width: Int { maxX - minX + 1 }
    public var height: Int { maxY - minY + 1 }
}

extension Board {
    public var fullRegion: CellRegion { CellRegion(minX: 0, minY: 0, maxX: width - 1, maxY: height - 1) }

    /// The cells worth looking at: every target, trap, wall and the start, plus Herbert's position and trail,
    /// padded by `margin` cells and kept inside the board.
    public func focusRegion(position: GridPoint, trail: Set<TrailSegment>, margin: Int = 2) -> CellRegion {
        let points = targets.union(traps).union(walls).union([start, position])
            .union(trail.flatMap { [$0.from, $0.to] })
        return CellRegion(
            minX: max(0, (points.map(\.x).min() ?? 0) - margin),
            minY: max(0, (points.map(\.y).min() ?? 0) - margin),
            maxX: min(width - 1, (points.map(\.x).max() ?? width - 1) + margin),
            maxY: min(height - 1, (points.map(\.y).max() ?? height - 1) + margin))
    }
}
