import HerbertCore
import SwiftUI

/// Draws the board as a lit diorama with the painter's algorithm: floor details first, then every wall block and
/// Herbert from far to near. All geometry goes through ``BoardCamera`` so it can be tested without a view.
struct Board3DPainter {
    static let wallHeight = 0.62
    static let curbHeight = 0.26
    static let slabDepth = 0.45

    let board: Board
    let visited: Set<GridPoint>
    let trail: Set<TrailSegment>
    let showTrail: Bool
    let showGridDots: Bool
    let pose: Board3DPose
    let size: CGSize
    let camera: BoardCamera
    let frame: BoardFrame

    /// Points per cell where the camera looks.
    var cellSize: Double { frame.scale }

    private let viewport: CGRect

    init(
        board: Board, visited: Set<GridPoint>, trail: Set<TrailSegment>, showTrail: Bool, showGridDots: Bool,
        pose: Board3DPose, size: CGSize
    ) {
        self.board = board
        self.visited = visited
        self.trail = trail
        self.showTrail = showTrail
        self.showGridDots = showGridDots
        self.pose = pose
        self.size = size
        viewport = CGRect(origin: .zero, size: size).insetBy(dx: -48, dy: -48)
        let floor = pose.floor
        camera = BoardCamera(yaw: pose.yaw, pitch: pose.pitch, focusX: floor.centerX, focusY: floor.centerY)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        var frame = camera.frame(
            fitting: floor, heights: -Self.slabDepth...Self.wallHeight, in: size, padding: min(18, size.width / 12)
        )
        .zoomed(by: pose.zoom, about: center)
        if pose.follow > 0 {
            let robot = camera.project(x: pose.robotX + 0.5, y: pose.robotY + 0.5, height: 0.4)
            let following = frame.centering(robot, at: center)
            frame = BoardFrame(
                scale: frame.scale, originX: frame.originX + (following.originX - frame.originX) * pose.follow,
                originY: frame.originY + (following.originY - frame.originY) * pose.follow)
        }
        self.frame = frame.panned(by: pose.pan)
    }

    // MARK: Projection helpers

    func screen(_ x: Double, _ y: Double, _ height: Double = 0) -> CGPoint {
        frame.point(camera.project(x: x, y: y, height: height))
    }

    /// A circle lying in the plane spanned by two board-space axes, as the ellipse it appears to be.
    func ellipse(
        at center: (x: Double, y: Double, z: Double), u: (x: Double, y: Double, z: Double),
        v: (x: Double, y: Double, z: Double), radiusU: Double, radiusV: Double
    ) -> Path {
        let origin = screen(center.x, center.y, center.z)
        let step = 0.05
        let toU = screen(center.x + u.x * step, center.y + u.y * step, center.z + u.z * step)
        let toV = screen(center.x + v.x * step, center.y + v.y * step, center.z + v.z * step)
        let transform = CGAffineTransform(
            a: (toU.x - origin.x) / step, b: (toU.y - origin.y) / step, c: (toV.x - origin.x) / step,
            d: (toV.y - origin.y) / step, tx: origin.x, ty: origin.y)
        return Path(ellipseIn: CGRect(x: -radiusU, y: -radiusV, width: radiusU * 2, height: radiusV * 2))
            .applying(transform)
    }

    func floorCircle(x: Double, y: Double, height: Double = 0, radius: Double) -> Path {
        ellipse(at: (x, y, height), u: (1, 0, 0), v: (0, 1, 0), radiusU: radius, radiusV: radius)
    }

    private func polygon(_ points: [CGPoint]) -> Path {
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        return path
    }

    // MARK: Cells

    private func inSlab(_ cell: GridPoint) -> Bool {
        (-1...board.width).contains(cell.x) && (-1...board.height).contains(cell.y)
    }

    private func isCurb(_ cell: GridPoint) -> Bool {
        inSlab(cell) && !((0..<board.width).contains(cell.x) && (0..<board.height).contains(cell.y))
    }

    func blockHeight(at cell: GridPoint) -> Double? {
        if board.walls.contains(cell) { return Self.wallHeight }
        return isCurb(cell) ? Self.curbHeight : nil
    }

    private var curbCells: [GridPoint] {
        let range = -1...board.width
        return range.flatMap { [GridPoint(x: $0, y: -1), GridPoint(x: $0, y: board.height)] }
            + (0..<board.height).flatMap { [GridPoint(x: -1, y: $0), GridPoint(x: board.width, y: $0)] }
    }

    private func center(of cell: GridPoint) -> (x: Double, y: Double) { (Double(cell.x) + 0.5, Double(cell.y) + 0.5) }

    // MARK: Painting

    func paint(_ context: inout GraphicsContext) {
        paintBackdrop(&context)
        paintFloor(&context)
        paintShadows(&context)
        if showTrail { paintTrail(&context) }
        paintHoles(&context)
        paintTargets(&context)
        paintRobotMarker(&context)
        paintStandingObjects(&context)
        paintHiddenHints(&context)
    }

    private func paintBackdrop(_ context: inout GraphicsContext) {
        let area = CGRect(origin: .zero, size: size)
        context.fill(
            Path(area),
            with: .linearGradient(
                Gradient(colors: [Board3DPalette.backdropTop.color(), Board3DPalette.backdropBottom.color()]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        let reach = hypot(size.width, size.height) / 2
        context.fill(
            Path(area),
            with: .radialGradient(
                Gradient(colors: [.clear, Color(red: 0.45, green: 0.32, blue: 0.15).opacity(0.10)]),
                center: CGPoint(x: size.width / 2, y: size.height / 2), startRadius: reach * 0.55, endRadius: reach))
        // The whole diorama rests on a soft shadow.
        let outline = [
            (-1.0, -1.0), (Double(board.width + 1), -1), (Double(board.width + 1), Double(board.height + 1)),
            (-1, Double(board.height + 1)),
        ]
        let drop = camera.boardVector(across: 0.5, toward: 0.7)
        let base = polygon(outline.map { screen($0.0 + drop.x, $0.1 + drop.y, -Self.slabDepth) })
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: max(4, cellSize * 0.45)))
            layer.fill(base, with: .color(Color(red: 0.30, green: 0.20, blue: 0.08).opacity(0.28)))
        }
    }

    private func paintFloor(_ context: inout GraphicsContext) {
        let width = Double(board.width)
        let height = Double(board.height)
        let corners = [(0.0, 0.0), (width, 0), (width, height), (0, height)].map { screen($0.0, $0.1) }
        let floor = polygon(corners)
        context.fill(floor, with: .color(Board3DPalette.floor.color()))
        var lighter = Path()
        var darker = Path()
        for y in 0..<board.height {
            for x in 0..<board.width {
                let variation = cellNoise(x, y)
                guard variation < 0.16 || variation > 0.84 else { continue }
                let tile = polygon([
                    screen(Double(x), Double(y)), screen(Double(x + 1), Double(y)),
                    screen(Double(x + 1), Double(y + 1)), screen(Double(x), Double(y + 1)),
                ])
                if variation < 0.16 { lighter.addPath(tile) } else { darker.addPath(tile) }
            }
        }
        context.fill(lighter, with: .color(.white.opacity(0.16)))
        context.fill(darker, with: .color(Board3DPalette.floorSeam.color(0.07)))
        var seams = Path()
        for index in 0...board.width {
            seams.move(to: screen(Double(index), 0))
            seams.addLine(to: screen(Double(index), height))
            seams.move(to: screen(0, Double(index)))
            seams.addLine(to: screen(width, Double(index)))
        }
        context.stroke(seams, with: .color(Board3DPalette.floorSeam.color(0.34)), lineWidth: max(0.6, cellSize * 0.022))
        if showGridDots {
            var dots = Path()
            let radius = max(0.9, cellSize * 0.035)
            for y in 0..<board.height {
                for x in 0..<board.width {
                    let point = screen(Double(x) + 0.5, Double(y) + 0.5)
                    guard viewport.contains(point) else { continue }
                    dots.addEllipse(
                        in: CGRect(
                            x: point.x - radius, y: point.y - radius * camera.pitchFlattening, width: radius * 2,
                            height: radius * 2 * camera.pitchFlattening))
                }
            }
            context.fill(dots, with: .color(Board3DPalette.floorSeam.color(0.55)))
        }
    }

    /// Soft contact shadows plus a longer one cast away from the light.
    private func paintShadows(_ context: inout GraphicsContext) {
        let cells = board.walls.sorted { ($0.y, $0.x) < ($1.y, $1.x) } + curbCells
        let cast = camera.boardVector(across: 0.85, toward: 0.45)
        var occlusion = Path()
        var shadow = Path()
        for cell in cells {
            guard let top = blockHeight(at: cell) else { continue }
            let x = Double(cell.x)
            let y = Double(cell.y)
            let probe = screen(x + 0.5, y + 0.5)
            guard viewport.insetBy(dx: -cellSize * 2, dy: -cellSize * 2).contains(probe) else { continue }
            let inflate = 0.12
            occlusion.addPath(
                polygon([
                    screen(x - inflate, y - inflate), screen(x + 1 + inflate, y - inflate),
                    screen(x + 1 + inflate, y + 1 + inflate), screen(x - inflate, y + 1 + inflate),
                ]))
            let corners = [(x, y), (x + 1, y), (x + 1, y + 1), (x, y + 1)]
            let moved = corners.map { ($0.0 + cast.x * top, $0.1 + cast.y * top) }
            shadow.addPath(polygon(convexHull(corners + moved).map { screen($0.0, $0.1) }))
        }
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: max(2, cellSize * 0.10)))
            layer.fill(occlusion, with: .color(Color(red: 0.12, green: 0.08, blue: 0.04).opacity(0.30)))
        }
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: max(3, cellSize * 0.16)))
            layer.fill(shadow, with: .color(Color(red: 0.16, green: 0.10, blue: 0.05).opacity(0.30)))
        }
    }

    private func paintTrail(_ context: inout GraphicsContext) {
        guard !trail.isEmpty else { return }
        var path = Path()
        for segment in trail {
            path.move(to: screen(Double(segment.from.x) + 0.5, Double(segment.from.y) + 0.5, 0.03))
            path.addLine(to: screen(Double(segment.to.x) + 0.5, Double(segment.to.y) + 0.5, 0.03))
        }
        let round = { (width: Double) in StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round) }
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: max(2, cellSize * 0.16)))
            layer.stroke(path, with: .color(Board3DPalette.trail.color(0.55)), style: round(cellSize * 0.44))
        }
        context.stroke(path, with: .color(Board3DPalette.trail.color()), style: round(max(2, cellSize * 0.15)))
        context.stroke(path, with: .color(Board3DPalette.trailCore.color(0.95)), style: round(max(1, cellSize * 0.055)))
    }

    private func paintHoles(_ context: inout GraphicsContext) {
        for trap in board.traps {
            let (x, y) = center(of: trap)
            let point = screen(x, y)
            guard viewport.insetBy(dx: -cellSize, dy: -cellSize).contains(point) else { continue }
            let lip = floorCircle(x: x, y: y, radius: 0.38)
            context.fill(lip, with: .color(Board3DPalette.floor.lit(1.07).color()))
            context.stroke(lip, with: .color(Board3DPalette.floorSeam.color(0.55)), lineWidth: max(1, cellSize * 0.025))
            let opening = floorCircle(x: x, y: y, radius: 0.31)
            var inside = context
            inside.clip(to: opening)
            let bounds = opening.boundingRect
            inside.fill(
                opening,
                with: .linearGradient(
                    Gradient(colors: [Tone(0x5A524B).color(), Board3DPalette.hole.color()]),
                    startPoint: CGPoint(x: bounds.midX, y: bounds.minY),
                    endPoint: CGPoint(x: bounds.midX, y: bounds.maxY)))
            let bottom = floorCircle(x: x, y: y, height: -0.42, radius: 0.31)
            inside.fill(bottom, with: .color(Board3DPalette.hole.color()))
        }
    }

    private func paintTargets(_ context: inout GraphicsContext) {
        for target in board.targets {
            let (x, y) = center(of: target)
            let point = screen(x, y)
            guard viewport.insetBy(dx: -cellSize, dy: -cellSize).contains(point) else { continue }
            let isLit = visited.contains(target)
            let rim = isLit ? Board3DPalette.litDeep : Board3DPalette.amberDeep
            let face = isLit ? Board3DPalette.lit : Board3DPalette.amber
            let highlight = isLit ? Board3DPalette.litLight : Board3DPalette.amberLight
            for (radius, opacity) in [(0.80, 0.05), (0.66, 0.07), (0.54, 0.10), (0.44, 0.14)] {
                context.fill(floorCircle(x: x, y: y, radius: radius), with: .color(face.color(opacity)))
            }
            let thickness = 0.07
            for slice in stride(from: 0.0, through: thickness, by: thickness / 3) {
                context.fill(floorCircle(x: x, y: y, height: slice, radius: 0.31), with: .color(rim.color()))
            }
            let top = floorCircle(x: x, y: y, height: thickness, radius: 0.31)
            let bounds = top.boundingRect
            context.fill(
                top,
                with: .radialGradient(
                    Gradient(colors: [highlight.color(), face.color(), face.lit(0.9).color()]),
                    center: CGPoint(x: bounds.midX - bounds.width * 0.12, y: bounds.midY - bounds.height * 0.12),
                    startRadius: 0, endRadius: bounds.width * 0.62))
            context.stroke(
                top, with: .color(highlight.color(0.9)), lineWidth: max(1, cellSize * 0.028))
            context.stroke(
                floorCircle(x: x, y: y, height: thickness, radius: 0.19), with: .color(.white.opacity(0.65)),
                lineWidth: max(1, cellSize * 0.03))
            context.fill(
                floorCircle(x: x, y: y, height: thickness, radius: 0.07), with: .color(.white.opacity(0.92)))
        }
    }

    private func paintRobotMarker(_ context: inout GraphicsContext) {
        let x = pose.robotX + 0.5
        let y = pose.robotY + 0.5
        let ring = floorCircle(x: x, y: y, height: 0.02, radius: 0.43)
        context.fill(ring, with: .color(Board3DPalette.trail.color(0.14)))
        context.stroke(ring, with: .color(Board3DPalette.trail.color(0.75)), lineWidth: max(1.5, cellSize * 0.04))
        let forward = (x: sin(pose.heading), y: -cos(pose.heading))
        let side = (x: -forward.y, y: forward.x)
        let arrow = polygon([
            screen(x + forward.x * 0.86, y + forward.y * 0.86, 0.02),
            screen(x + forward.x * 0.56 + side.x * 0.16, y + forward.y * 0.56 + side.y * 0.16, 0.02),
            screen(x + forward.x * 0.64, y + forward.y * 0.64, 0.02),
            screen(x + forward.x * 0.56 - side.x * 0.16, y + forward.y * 0.56 - side.y * 0.16, 0.02),
        ])
        context.fill(arrow, with: .color(Board3DPalette.trail.color(0.95)))
    }

    // MARK: Standing objects

    private func paintStandingObjects(_ context: inout GraphicsContext) {
        let robotDistance = camera.eyeDistanceSquared(x: pose.robotX + 0.5, y: pose.robotY + 0.5, height: 0.5)
        var robotDrawn = false
        let cells = Array(board.walls) + curbCells
        for cell in camera.drawOrder(of: cells, height: { blockHeight(at: $0) ?? 0 }) {
            let (x, y) = center(of: cell)
            let distance = camera.eyeDistanceSquared(x: x, y: y, height: (blockHeight(at: cell) ?? 0) / 2)
            if !robotDrawn && robotDistance > distance {
                paintRobot(&context)
                robotDrawn = true
            }
            paintBlock(cell, in: &context)
        }
        if !robotDrawn { paintRobot(&context) }
    }

    private func paintBlock(_ cell: GridPoint, in context: inout GraphicsContext) {
        guard let top = blockHeight(at: cell) else { return }
        let x0 = Double(cell.x)
        let y0 = Double(cell.y)
        let x1 = x0 + 1
        let y1 = y0 + 1
        let roof = [screen(x0, y0, top), screen(x1, y0, top), screen(x1, y1, top), screen(x0, y1, top)]
        let floorLevel = [screen(x0, y0, 0), screen(x1, y0, 0), screen(x1, y1, 0), screen(x0, y1, 0)]
        let touched = (roof + floorLevel).reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: .zero)) }
        guard viewport.intersects(touched) else { return }
        let material = board.walls.contains(cell) ? Board3DPalette.wall : Board3DPalette.curb
        let sides: [(Heading, (Double, Double), (Double, Double))] = [
            (.north, (x0, y0), (x1, y0)), (.east, (x1, y0), (x1, y1)), (.south, (x1, y1), (x0, y1)),
            (.west, (x0, y1), (x0, y0)),
        ]
        for (side, from, to) in sides where camera.isVisible(side, ofBlockAt: cell) {
            let neighbor = GridPoint(x: cell.x + side.vector.x, y: cell.y + side.vector.y)
            let neighborTop = blockHeight(at: neighbor)
            if let neighborTop, neighborTop >= top { continue }
            let bottom = inSlab(neighbor) ? (neighborTop ?? 0) : -Self.slabDepth
            let face = polygon([
                screen(from.0, from.1, top), screen(to.0, to.1, top), screen(to.0, to.1, bottom),
                screen(from.0, from.1, bottom),
            ])
            let normal = camera.cameraNormal(of: side)
            let lambert = max(0, normal.across * -0.55 + normal.toward * -0.25) / 0.604
            let shade = 0.40 + 0.60 * lambert
            let lit = material.lit(shade)
            context.fill(
                face,
                with: .linearGradient(
                    Gradient(colors: [lit.color(), lit.lit(0.66).color()]),
                    startPoint: screen(from.0, from.1, top), endPoint: screen(from.0, from.1, bottom)))
            context.stroke(face, with: .color(lit.lit(0.9).color()), lineWidth: 1)
            var seam = Path()
            seam.move(to: screen(from.0, from.1, top))
            seam.addLine(to: screen(from.0, from.1, bottom))
            context.stroke(seam, with: .color(.black.opacity(0.14)), lineWidth: max(0.6, cellSize * 0.016))
        }
        let roofTone = material.lit(0.94 + 0.12 * cellNoise(cell.x, cell.y, salt: 7))
        let roofPath = polygon(roof)
        context.fill(roofPath, with: .color(roofTone.color()))
        context.stroke(roofPath, with: .color(roofTone.color()), lineWidth: 1)
        context.stroke(roofPath, with: .color(.black.opacity(0.07)), lineWidth: max(0.6, cellSize * 0.015))
        let middle = CGPoint(x: roof.map(\.x).reduce(0, +) / 4, y: roof.map(\.y).reduce(0, +) / 4)
        let inset = polygon(
            roof.map { CGPoint(x: middle.x + ($0.x - middle.x) * 0.76, y: middle.y + ($0.y - middle.y) * 0.76) })
        context.fill(inset, with: .color(.white.opacity(0.07)))
        var rim = Path()
        for (side, from, to) in sides where camera.isVisible(side, ofBlockAt: cell) {
            let neighborTop = blockHeight(at: GridPoint(x: cell.x + side.vector.x, y: cell.y + side.vector.y))
            if let neighborTop, neighborTop >= top { continue }
            rim.move(to: screen(from.0, from.1, top))
            rim.addLine(to: screen(to.0, to.1, top))
        }
        context.stroke(rim, with: .color(.white.opacity(0.32)), lineWidth: max(1, cellSize * 0.03))
    }

    // MARK: Hints for what a wall hides

    private func paintHiddenHints(_ context: inout GraphicsContext) {
        for target in board.targets {
            let (x, y) = center(of: target)
            guard camera.isHidden(x: x, y: y, height: 0.05, behind: board.walls, wallHeight: Self.wallHeight) else {
                continue
            }
            let tone = visited.contains(target) ? Board3DPalette.lit : Board3DPalette.amber
            let ring = floorCircle(x: x, y: y, radius: 0.3)
            context.stroke(ring, with: .color(tone.color(0.95)), lineWidth: max(1.5, cellSize * 0.05))
            context.fill(floorCircle(x: x, y: y, radius: 0.1), with: .color(tone.color(0.95)))
        }
        let x = pose.robotX + 0.5
        let y = pose.robotY + 0.5
        if camera.isHidden(x: x, y: y, height: 0.45, behind: board.walls, wallHeight: Self.wallHeight) {
            let ring = floorCircle(x: x, y: y, radius: 0.34)
            context.fill(ring, with: .color(Board3DPalette.trail.color(0.35)))
            context.stroke(ring, with: .color(Board3DPalette.trail.color(0.95)), lineWidth: max(1.5, cellSize * 0.05))
        }
    }
}

extension BoardCamera {
    /// How much a circle on the floor is squashed vertically at this tilt.
    var pitchFlattening: Double { sin(pitch) }
}

/// Andrew's monotone chain; the result winds counter-clockwise.
private func convexHull(_ points: [(Double, Double)]) -> [(Double, Double)] {
    let sorted = points.sorted { $0.0 != $1.0 ? $0.0 < $1.0 : $0.1 < $1.1 }
    guard sorted.count > 2 else { return sorted }
    func cross(_ o: (Double, Double), _ a: (Double, Double), _ b: (Double, Double)) -> Double {
        (a.0 - o.0) * (b.1 - o.1) - (a.1 - o.1) * (b.0 - o.0)
    }
    var hull: [(Double, Double)] = []
    for point in sorted {
        while hull.count >= 2 && cross(hull[hull.count - 2], hull[hull.count - 1], point) <= 1e-12 {
            hull.removeLast()
        }
        hull.append(point)
    }
    let lowerCount = hull.count + 1
    for point in sorted.reversed().dropFirst() {
        while hull.count >= lowerCount && cross(hull[hull.count - 2], hull[hull.count - 1], point) <= 1e-12 {
            hull.removeLast()
        }
        hull.append(point)
    }
    hull.removeLast()
    return hull
}
