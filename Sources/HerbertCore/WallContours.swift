import Foundation

/// Traces cell boundaries in grid-corner coordinates. Clockwise exterior loops
/// and counterclockwise holes share a nonzero fill; diagonal cells stay separate.
enum WallContours {
    static func trace(_ walls: Set<GridPoint>) -> [[GridPoint]] {
        var outgoing: [GridPoint: Set<GridPoint>] = [:]
        func edge(_ from: GridPoint, _ to: GridPoint) {
            outgoing[from, default: []].insert(to)
        }
        for p in walls {
            let topLeft = p
            let topRight = GridPoint(x: p.x + 1, y: p.y)
            let bottomRight = GridPoint(x: p.x + 1, y: p.y + 1)
            let bottomLeft = GridPoint(x: p.x, y: p.y + 1)
            if !walls.contains(GridPoint(x: p.x, y: p.y - 1)) { edge(topLeft, topRight) }
            if !walls.contains(GridPoint(x: p.x + 1, y: p.y)) { edge(topRight, bottomRight) }
            if !walls.contains(GridPoint(x: p.x, y: p.y + 1)) { edge(bottomRight, bottomLeft) }
            if !walls.contains(GridPoint(x: p.x - 1, y: p.y)) { edge(bottomLeft, topLeft) }
        }
        var contours: [[GridPoint]] = []
        while let start = outgoing.keys.min(by: ordered) {
            var contour = [start]
            var current = start
            var direction = 0
            repeat {
                guard let candidates = outgoing[current],
                    let next = candidates.min(by: { a, b in
                        priority(from: current, to: a, incoming: direction)
                            < priority(from: current, to: b, incoming: direction)
                    })
                else { break }
                outgoing[current]?.remove(next)
                if outgoing[current]?.isEmpty == true { outgoing.removeValue(forKey: current) }
                direction = heading(from: current, to: next)
                current = next
                if current != start { contour.append(current) }
            } while current != start
            contours.append(contour)
        }
        return contours
    }

    private static func ordered(_ a: GridPoint, _ b: GridPoint) -> Bool {
        a.y == b.y ? a.x < b.x : a.y < b.y
    }

    private static func heading(from: GridPoint, to: GridPoint) -> Int {
        if to.x > from.x { return 0 }
        if to.y > from.y { return 1 }
        if to.x < from.x { return 2 }
        return 3
    }

    private static func priority(from: GridPoint, to: GridPoint, incoming: Int) -> Int {
        let turn = (heading(from: from, to: to) - incoming + 4) % 4
        // At a diagonal touch, turn right to follow the same wall component.
        return [1, 0, 3, 2][turn]
    }
}
