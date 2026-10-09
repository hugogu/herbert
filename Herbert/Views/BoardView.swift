import HerbertCore
import SwiftUI

struct BoardDrawing: View, Animatable {
    let board: Board
    let position: GridPoint
    let heading: Heading
    let visited: Set<GridPoint>
    var focused: Bool = true
    var miniature = false
    var style: BoardStyle
    var showGridDots: Bool
    var trail: Set<TrailSegment>
    var showTrail: Bool
    private var robotLocation: CGPoint

    init(
        board: Board, position: GridPoint, heading: Heading, visited: Set<GridPoint>, focused: Bool = true,
        miniature: Bool = false, style: BoardStyle = .modern, showGridDots: Bool = true,
        trail: Set<TrailSegment> = [], showTrail: Bool = true
    ) {
        self.board = board
        self.position = position
        self.heading = heading
        self.visited = visited
        self.focused = focused
        self.miniature = miniature
        self.style = style
        self.showGridDots = showGridDots
        self.trail = trail
        self.showTrail = showTrail
        robotLocation = CGPoint(x: position.x, y: position.y)
    }

    nonisolated var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(robotLocation.x, robotLocation.y) }
        set { robotLocation = CGPoint(x: newValue.first, y: newValue.second) }
    }

    private var bounds: (x: Int, y: Int, width: Int, height: Int) {
        guard focused else { return (0, 0, 25, 25) }
        let points = board.targets.union(board.traps).union(board.walls).union([board.start, position])
            .union(trail.flatMap { [$0.from, $0.to] })
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
            if showGridDots {
                for y in region.y..<(region.y + region.height) {
                    for x in region.x..<(region.x + region.width) {
                        let point = GridPoint(x: x, y: y)
                        let c = center(point)
                        let dot = miniature ? 0.65 : max(0.8, cell * 0.027)
                        context.fill(
                            Path(ellipseIn: CGRect(x: c.x - dot, y: c.y - dot, width: dot * 2, height: dot * 2)),
                            with: .color(style == .classic ? Color(white: 0.60) : Palette.muted.opacity(0.42)))
                    }
                }
            }
            if showTrail {
                var path = Path()
                for segment in trail {
                    path.move(to: center(segment.from))
                    path.addLine(to: center(segment.to))
                }
                context.stroke(
                    path, with: .color(style == .classic ? .blue.opacity(0.50) : Palette.mint.opacity(0.40)),
                    style: StrokeStyle(lineWidth: max(1.5, cell * 0.09), lineCap: .round, lineJoin: .round))
            }
            var walls = Path()
            for contour in board.wallContours {
                let corners = contour.map { p in
                    CGPoint(
                        x: origin.x + CGFloat(p.x - region.x) * cell,
                        y: origin.y + CGFloat(p.y - region.y) * cell)
                }
                guard let first = corners.first else { continue }
                if style == .classic {
                    walls.move(to: first)
                    for corner in corners.dropFirst() { walls.addLine(to: corner) }
                } else {
                    for index in corners.indices {
                        let previous = corners[(index + corners.count - 1) % corners.count]
                        let corner = corners[index]
                        let next = corners[(index + 1) % corners.count]
                        let entry = CGPoint(
                            x: corner.x + (previous.x - corner.x) * 0.15,
                            y: corner.y + (previous.y - corner.y) * 0.15)
                        let exit = CGPoint(
                            x: corner.x + (next.x - corner.x) * 0.15,
                            y: corner.y + (next.y - corner.y) * 0.15)
                        if index == 0 { walls.move(to: entry) } else { walls.addLine(to: entry) }
                        if previous.x == next.x || previous.y == next.y {
                            walls.addLine(to: exit)
                        } else {
                            walls.addQuadCurve(to: exit, control: corner)
                        }
                    }
                }
                walls.closeSubpath()
            }
            context.fill(walls, with: .color(style == .classic ? .black : Palette.ink.opacity(0.85)))
            for point in board.traps {
                let c = center(point)
                let radius = cell * 0.23
                let ring = Path(
                    ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2))
                context.fill(ring, with: .color(style == .classic ? Color(white: 0.48) : Palette.muted.opacity(0.14)))
                context.stroke(
                    ring, with: .color(style == .classic ? Color(white: 0.35) : Palette.muted.opacity(0.45)),
                    lineWidth: max(1, cell * 0.035))
                if !miniature && style != .classic {
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
                let color: Color = style == .classic ? .black : (visited.contains(point) ? Palette.mint : Palette.amber)
                context.fill(
                    ring,
                    with: .color(
                        style == .classic
                            ? (visited.contains(point) ? Color(white: 0.25) : .white) : color.opacity(0.18)))
                context.stroke(ring, with: .color(color), lineWidth: max(1.5, cell * 0.065))
                if visited.contains(point) && style != .classic {
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
            if style == .classic {
                var silhouette = Path()
                silhouette.addRect(
                    CGRect(x: -radius * 0.76, y: -radius * 0.15, width: radius * 1.52, height: radius * 1.05))
                silhouette.addRect(
                    CGRect(x: -radius * 0.30, y: -radius * 0.85, width: radius * 0.60, height: radius * 0.85))
                robot.fill(silhouette, with: .color(Color(red: 0.82, green: 0.04, blue: 0.06)))
            } else {
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
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            L10n.text(
                "棋盘，Herbert 位于第 %ld 行、第 %ld 列，朝%@。已点亮 %ld / %ld 个目标。",
                position.y + 1, position.x + 1, headingName, visited.count, board.targets.count)
                + " "
                + L10n.text(
                    "%@；网格点%@；轨迹%@；%ld 段路径", L10n.text(style == .classic ? "经典风格" : "现代风格"),
                    L10n.text(showGridDots ? "开启" : "关闭"), L10n.text(showTrail ? "开启" : "关闭"),
                    showTrail ? trail.count : 0)
        )
        .accessibilityIdentifier("game-board")
    }

    private var headingName: String { L10n.text(["上", "右", "下", "左"][heading.rawValue]) }
}

struct BoardView: View {
    @ObservedObject var model: GameModel
    @AppStorage("board.style") private var style = BoardStyle.modern
    @AppStorage("board.showTrail") private var showTrail = true
    @AppStorage("board.showGridDots") private var showGridDots = true
    @State private var showOptions = false
    @State private var showLegend = false
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
                    Label(LocalizedStringKey(focused ? "全棋盘" : "聚焦"), systemImage: "viewfinder")
                        .font(.system(size: 11, weight: .medium)).frame(minHeight: 32)
                }.buttonStyle(.plain).foregroundStyle(Palette.mint)
                Button {
                    zoom = 1
                    pan = .zero
                } label: {
                    Image(systemName: "arrow.counterclockwise").frame(width: 32, height: 32)
                }
                .buttonStyle(.plain).accessibilityLabel("复原棋盘缩放")
                Button {
                    showOptions = true
                } label: {
                    Image(systemName: "slider.horizontal.3").frame(width: 32, height: 32)
                }
                .buttonStyle(.plain).accessibilityLabel("棋盘设置").accessibilityIdentifier("board-options")
                .popover(isPresented: $showOptions, arrowEdge: .top) { BoardOptionsView() }
            }
            GeometryReader { geometry in
                BoardDrawing(
                    board: model.session.board, position: model.session.position, heading: model.session.heading,
                    visited: model.session.visitedTargets, focused: focused, style: style, showGridDots: showGridDots,
                    trail: model.session.trail, showTrail: showTrail
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
            .background(style.background, in: RoundedRectangle(cornerRadius: style == .classic ? 0 : 16))
            .overlay {
                if style == .classic { Rectangle().stroke(Color(white: 0.35), lineWidth: 1).allowsHitTesting(false) }
            }
            .clipShape(RoundedRectangle(cornerRadius: style == .classic ? 0 : 16))
            HStack(spacing: 16) {
                Button {
                    model.pause()
                    showLegend = true
                } label: {
                    HStack(spacing: 12) {
                        legend("目标", symbol: "circle", color: style == .classic ? .black : Palette.amber)
                        legend("陷阱", symbol: style == .classic ? "circle.fill" : "xmark.circle", color: Palette.muted)
                        legend("墙", symbol: "square.fill", color: Palette.ink)
                        Image(systemName: "questionmark.circle").font(.system(size: 12)).foregroundStyle(Palette.muted)
                    }.frame(minHeight: 32).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel("认识棋盘：目标、墙与陷阱")
                .accessibilityIdentifier("board-legend")
                .popover(isPresented: $showLegend, arrowEdge: .bottom) { BoardLegendGuide(style: style) }
                Spacer(minLength: 0)
                Text("25 × 25").font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
            }
        }.panel(padding: 18)
    }

    private func legend(_ text: String, symbol: String, color: Color) -> some View {
        Label(LocalizedStringKey(text), systemImage: symbol).font(.system(size: 10)).foregroundStyle(color)
    }
}

private struct BoardLegendGuide: View {
    let style: BoardStyle
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("认识棋盘").font(.headline)
                Spacer()
                Button("完成") { dismiss() }.accessibilityIdentifier("close-board-legend")
            }
            item(
                "目标", symbol: "circle", color: style == .classic ? .black : Palette.amber,
                detail: "走到圆环上即可点亮。让所有目标同时亮起即可完成。", identifier: "board-target-help")
            item(
                "墙", symbol: "square.fill", color: Palette.ink,
                detail: "挡住去路：撞到墙或棋盘边界时，Herbert 留在原地，接着执行下一条指令。", identifier: "board-wall-help")
            item(
                "陷阱", symbol: style == .classic ? "circle.fill" : "xmark.circle", color: Palette.muted,
                detail: "可以走上去：踩中后，已点亮的所有目标都会熄灭。Herbert 不会回到起点，程序继续执行。", identifier: "board-trap-help")
        }.padding(20).frame(width: 340)
            #if os(iOS)
                .presentationCompactAdaptation(.sheet)
                .presentationDetents([.height(440), .large])
                .presentationDragIndicator(.visible)
            #endif
    }

    private func item(_ title: String, symbol: String, color: Color, detail: String, identifier: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).font(.system(size: 20)).foregroundStyle(color).frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizedStringKey(title)).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(LocalizedStringKey(detail)).font(.system(size: 13)).foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier(identifier)
            }
        }
    }
}
