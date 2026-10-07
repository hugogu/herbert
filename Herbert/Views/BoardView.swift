import HerbertCore
import SwiftUI

struct BoardDrawing: View, Animatable {
    let board: Board
    let position: GridPoint
    let heading: Heading
    let visited: Set<GridPoint>
    var focused: Bool = true
    var miniature = false
    private var robotLocation: CGPoint

    init(
        board: Board, position: GridPoint, heading: Heading, visited: Set<GridPoint>, focused: Bool = true,
        miniature: Bool = false
    ) {
        self.board = board
        self.position = position
        self.heading = heading
        self.visited = visited
        self.focused = focused
        self.miniature = miniature
        robotLocation = CGPoint(x: position.x, y: position.y)
    }

    nonisolated var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(robotLocation.x, robotLocation.y) }
        set { robotLocation = CGPoint(x: newValue.first, y: newValue.second) }
    }

    private var bounds: (x: Int, y: Int, width: Int, height: Int) {
        guard focused else { return (0, 0, 25, 25) }
        let points = board.targets.union(board.traps).union(board.walls).union([board.start, position])
        let minX = max(0, (points.map(\.x).min() ?? 0) - 2)
        let minY = max(0, (points.map(\.y).min() ?? 0) - 2)
        let maxX = min(24, (points.map(\.x).max() ?? 24) + 2)
        let maxY = min(24, (points.map(\.y).max() ?? 24) + 2)
        return (minX, minY, maxX - minX + 1, maxY - minY + 1)
    }

    var body: some View {
        Canvas { context, size in
            let region = bounds
            let cell = min(size.width / CGFloat(region.width), size.height / CGFloat(region.height))
            let origin = CGPoint(
                x: (size.width - CGFloat(region.width) * cell) / 2,
                y: (size.height - CGFloat(region.height) * cell) / 2)
            func center(_ p: GridPoint) -> CGPoint {
                CGPoint(
                    x: origin.x + (CGFloat(p.x - region.x) + 0.5) * cell,
                    y: origin.y + (CGFloat(p.y - region.y) + 0.5) * cell)
            }
            for y in region.y..<(region.y + region.height) {
                for x in region.x..<(region.x + region.width) {
                    let point = GridPoint(x: x, y: y)
                    let c = center(point)
                    let dot = miniature ? 0.65 : max(0.8, cell * 0.027)
                    context.fill(
                        Path(ellipseIn: CGRect(x: c.x - dot, y: c.y - dot, width: dot * 2, height: dot * 2)),
                        with: .color(Palette.line))
                }
            }
            for point in board.walls {
                let c = center(point)
                let rect = CGRect(x: c.x - cell * 0.46, y: c.y - cell * 0.46, width: cell * 0.92, height: cell * 0.92)
                context.fill(
                    Path(roundedRect: rect, cornerRadius: cell * 0.15), with: .color(Palette.ink.opacity(0.85)))
            }
            for point in board.traps {
                let c = center(point)
                let radius = cell * 0.23
                let ring = Path(
                    ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2))
                context.fill(ring, with: .color(Palette.muted.opacity(0.14)))
                context.stroke(ring, with: .color(Palette.muted.opacity(0.45)), lineWidth: max(1, cell * 0.035))
                if !miniature {
                    var cross = Path()
                    cross.move(to: CGPoint(x: c.x - radius * 0.35, y: c.y - radius * 0.35))
                    cross.addLine(to: CGPoint(x: c.x + radius * 0.35, y: c.y + radius * 0.35))
                    cross.move(to: CGPoint(x: c.x + radius * 0.35, y: c.y - radius * 0.35))
                    cross.addLine(to: CGPoint(x: c.x - radius * 0.35, y: c.y + radius * 0.35))
                    context.stroke(cross, with: .color(Palette.muted), lineWidth: max(1, cell * 0.04))
                }
            }
            for point in board.targets {
                let c = center(point)
                let radius = cell * 0.25
                let ring = Path(
                    ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2))
                let color = visited.contains(point) ? Palette.mint : Palette.amber
                context.fill(ring, with: .color(color.opacity(0.18)))
                context.stroke(ring, with: .color(color), lineWidth: max(1.5, cell * 0.065))
                if visited.contains(point) {
                    context.fill(
                        Path(
                            ellipseIn: CGRect(
                                x: c.x - radius * 0.42, y: c.y - radius * 0.42,
                                width: radius * 0.84, height: radius * 0.84)), with: .color(color))
                }
            }
            let c = CGPoint(
                x: origin.x + (robotLocation.x - CGFloat(region.x) + 0.5) * cell,
                y: origin.y + (robotLocation.y - CGFloat(region.y) + 0.5) * cell)
            let radius = cell * 0.34
            var robot = context
            robot.translateBy(x: c.x, y: c.y)
            robot.rotate(by: .degrees(Double(heading.rawValue) * 90))
            let body = Path(
                roundedRect: CGRect(x: -radius, y: -radius * 0.8, width: radius * 2, height: radius * 1.8),
                cornerRadius: radius * 0.5)
            robot.addFilter(.shadow(color: Palette.mint.opacity(0.22), radius: cell * 0.12, y: cell * 0.06))
            robot.fill(body, with: .color(Palette.mint))
            var arrow = Path()
            arrow.move(to: CGPoint(x: -radius * 0.40, y: -radius * 0.08))
            arrow.addLine(to: CGPoint(x: 0, y: -radius * 0.48))
            arrow.addLine(to: CGPoint(x: radius * 0.40, y: -radius * 0.08))
            robot.stroke(
                arrow, with: .color(.white),
                style: StrokeStyle(lineWidth: max(1, cell * 0.065), lineCap: .round, lineJoin: .round))
            for x in [-0.35, 0.35] {
                robot.fill(
                    Path(
                        ellipseIn: CGRect(
                            x: radius * x - radius * 0.10, y: radius * 0.40,
                            width: radius * 0.20, height: radius * 0.20)), with: .color(.white.opacity(0.8)))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "棋盘，Herbert 位于第 \(position.y + 1) 行、第 \(position.x + 1) 列，朝\(headingName)。已点亮 \(visited.count) / \(board.targets.count) 个目标。"
        )
        .accessibilityIdentifier("game-board")
    }

    private var headingName: String { ["上", "右", "下", "左"][heading.rawValue] }
}

struct BoardView: View {
    @ObservedObject var model: GameModel
    @State private var focused = true
    @State private var zoom: CGFloat = 1
    @GestureState private var magnification: CGFloat = 1
    @State private var pan = CGSize.zero
    @GestureState private var drag = CGSize.zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Eyebrow(text: "THE PLAYGROUND")
                Spacer()
                Button {
                    focused.toggle()
                    zoom = 1
                    pan = .zero
                } label: {
                    Label(focused ? "全棋盘" : "聚焦", systemImage: "viewfinder")
                        .font(.system(size: 11, weight: .medium)).frame(minHeight: 32)
                }.buttonStyle(.plain).foregroundStyle(Palette.mint)
                Button {
                    zoom = 1
                    pan = .zero
                } label: {
                    Image(systemName: "arrow.counterclockwise").frame(width: 32, height: 32)
                }
                .buttonStyle(.plain).accessibilityLabel("复原棋盘缩放")
            }
            GeometryReader { geometry in
                BoardDrawing(
                    board: model.session.board, position: model.session.position, heading: model.session.heading,
                    visited: model.session.visitedTargets, focused: focused
                )
                .animation(
                    reduceMotion || model.speed >= 16 || model.session.status == .ready
                        ? nil : .easeInOut(duration: 0.12), value: model.session.position
                )
                .padding(12)
                .scaleEffect(min(4, max(1, zoom * magnification)))
                .offset(x: pan.width + drag.width, y: pan.height + drag.height)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .contentShape(Rectangle())
                .gesture(
                    MagnifyGesture().updating($magnification) { value, state, _ in state = value.magnification }
                        .onEnded { value in
                            zoom = min(4, max(1, zoom * value.magnification))
                            if zoom == 1 { pan = .zero }
                        }
                )
                .simultaneousGesture(
                    DragGesture().updating($drag) { value, state, _ in
                        if zoom > 1 { state = value.translation }
                    }.onEnded { value in
                        if zoom > 1 {
                            let maxX = geometry.size.width * (zoom - 1) / 2
                            let maxY = geometry.size.height * (zoom - 1) / 2
                            pan.width = min(maxX, max(-maxX, pan.width + value.translation.width))
                            pan.height = min(maxY, max(-maxY, pan.height + value.translation.height))
                        }
                    })
            }
            .background(Palette.paper.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            HStack(spacing: 16) {
                legend("目标", symbol: "circle", color: Palette.amber)
                legend("陷阱", symbol: "xmark.circle", color: Palette.muted)
                legend("墙", symbol: "square.fill", color: Palette.ink)
                Spacer(minLength: 0)
                Text("25 × 25").font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
            }
        }.panel(padding: 18)
    }

    private func legend(_ text: String, symbol: String, color: Color) -> some View {
        Label(text, systemImage: symbol).font(.system(size: 10)).foregroundStyle(color)
    }
}
