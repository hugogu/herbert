import HerbertCore
import SwiftUI

/// The interactive 3D board: the diorama plus the gestures and buttons that turn, tilt and zoom it.
struct Board3DView: View {
    enum Presentation {
        /// Inside the playground panel, which scrolls on touch devices.
        case inline
        /// Filling the window, with room for every camera control.
        case stage
    }

    @ObservedObject var model: GameModel
    @Binding var rig: BoardCameraRig
    let focused: Bool
    let showTrail: Bool
    let showGridDots: Bool
    var presentation = Presentation.inline

    @State private var headingAngle: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        model: GameModel, rig: Binding<BoardCameraRig>, focused: Bool, showTrail: Bool, showGridDots: Bool,
        presentation: Presentation = .inline
    ) {
        self.model = model
        _rig = rig
        self.focused = focused
        self.showTrail = showTrail
        self.showGridDots = showGridDots
        self.presentation = presentation
        _headingAngle = State(initialValue: model.session.heading.angle)
    }

    private struct Step: Equatable {
        var position: GridPoint
        var heading: Heading
    }

    private var stepAnimation: Animation? {
        reduceMotion || model.speed >= 16 || model.session.status == .ready ? nil : .easeInOut(duration: 0.12)
    }

    private var cameraAnimation: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.35) }

    private var floor: FloorRect {
        let session = model.session
        if focused { return FloorRect(session.board.focusRegion(position: session.position, trail: session.trail)) }
        return FloorRect(
            minX: -1, minY: -1, maxX: Double(session.board.width + 1), maxY: Double(session.board.height + 1))
    }

    private var pose: Board3DPose {
        Board3DPose(
            robot: model.session.position, headingAngle: headingAngle, yaw: rig.yaw, pitch: rig.pitch, floor: floor,
            zoom: rig.zoom, pan: rig.pan, follow: rig.follow ? 1 : 0)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                drawing.modifier(
                    Board3DInput(
                        rig: $rig, size: geometry.size, yieldsVerticalDrags: presentation == .inline, onReset: reset))
                controls(in: geometry.size)
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onChange(of: model.session.heading) { _, heading in
            withAnimation(stepAnimation) { headingAngle = heading.angle(nearest: headingAngle) }
        }
    }

    private var drawing: some View {
        let session = model.session
        return Board3DDrawing(
            board: session.board, visited: session.visitedTargets, trail: session.trail, showTrail: showTrail,
            showGridDots: showGridDots, pose: pose
        )
        .animation(stepAnimation, value: Step(position: session.position, heading: session.heading))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(
            L10n.text("视角 %ld°，俯角 %ld°", Int(degrees(rig.yaw - BoardCamera.defaultYaw)), Int(degrees(rig.pitch)))
        )
        .accessibilityIdentifier("game-board")
    }

    private func degrees(_ radians: Double) -> Double {
        let turned = (radians * 180 / .pi).truncatingRemainder(dividingBy: 360)
        return (turned + 360).truncatingRemainder(dividingBy: 360).rounded()
    }

    private var accessibilityLabel: String {
        let session = model.session
        let heading = L10n.text(["上", "右", "下", "左"][session.heading.rawValue])
        return L10n.text(
            "棋盘，Herbert 位于第 %ld 行、第 %ld 列，朝%@。已点亮 %ld / %ld 个目标。", session.position.y + 1,
            session.position.x + 1, heading, session.visitedTargets.count, session.board.targets.count)
            + " "
            + L10n.text(
                "%@；网格点%@；轨迹%@；%ld 段路径", L10n.text("3D 风格"), L10n.text(showGridDots ? "开启" : "关闭"),
                L10n.text(showTrail ? "开启" : "关闭"), showTrail ? session.trail.count : 0)
    }

    // MARK: Camera buttons

    private func reset() {
        withAnimation(cameraAnimation) { rig.reset() }
    }

    private func controls(in size: CGSize) -> some View {
        let isStage = presentation == .stage
        let steep = rig.pitch >= BoardCameraRig.steepPitch - 0.12
        let buttons = Group {
            CameraButton(symbol: "rotate.left", label: "向左旋转视角", identifier: "camera-rotate-left") {
                withAnimation(cameraAnimation) { rig.rotate(quarterTurns: -1) }
            }
            CameraButton(symbol: "rotate.right", label: "向右旋转视角", identifier: "camera-rotate-right") {
                withAnimation(cameraAnimation) { rig.rotate(quarterTurns: 1) }
            }
            CameraButton(symbol: steep ? "view.3d" : "view.2d", label: "切换俯视角度", identifier: "camera-tilt") {
                withAnimation(cameraAnimation) { rig.toggleTilt() }
            }
            if isStage {
                CameraButton(symbol: "plus.magnifyingglass", label: "拉近视角", identifier: "camera-zoom-in") {
                    withAnimation(cameraAnimation) {
                        rig.zoom(by: 1.4, about: CGPoint(x: size.width / 2, y: size.height / 2), in: size)
                    }
                }
                CameraButton(symbol: "minus.magnifyingglass", label: "拉远视角", identifier: "camera-zoom-out") {
                    withAnimation(cameraAnimation) {
                        rig.zoom(by: 1 / 1.4, about: CGPoint(x: size.width / 2, y: size.height / 2), in: size)
                    }
                }
                CameraButton(
                    symbol: "scope", label: "跟随 Herbert", identifier: "camera-follow", isOn: rig.follow
                ) {
                    withAnimation(cameraAnimation) { rig.follow.toggle() }
                }
            }
        }
        return ViewThatFits(in: .vertical) {
            VStack(spacing: 8) { buttons }
            HStack(spacing: 8) { buttons }
        }
        .padding(10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("视角控制")
    }
}

private struct CameraButton: View {
    let symbol: String
    let label: String
    let identifier: String
    var isOn = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).frame(width: 40, height: 40)
                .foregroundStyle(isOn ? Color.white : Palette.ink)
                .background(isOn ? AnyShapeStyle(Palette.mint) : AnyShapeStyle(.regularMaterial), in: Circle())
                .overlay(Circle().stroke(Palette.line, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain).accessibilityLabel(LocalizedStringKey(label))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}
