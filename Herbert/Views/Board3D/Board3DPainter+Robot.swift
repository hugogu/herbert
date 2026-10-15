import HerbertCore
import SwiftUI

extension Board3DPainter {
    /// Where Herbert stands and which way he faces, shared by the parts he is drawn from. Sizes are in cells.
    private struct Stance {
        let x: Double
        let y: Double
        let forward: (x: Double, y: Double)
        let side: (x: Double, y: Double)
        /// Points per cell at his middle, for line widths.
        let reach: Double
    }

    /// Screen points per cell at a board position, which shrinks with distance.
    func pixelsPerCell(x: Double, y: Double, height: Double) -> Double {
        frame.scale * camera.project(x: x, y: y, height: height).scale
    }

    private func sphere(x: Double, y: Double, height: Double, radius: Double) -> Path {
        let center = screen(x, y, height)
        let reach = pixelsPerCell(x: x, y: y, height: height) * radius
        return Path(ellipseIn: CGRect(x: center.x - reach, y: center.y - reach, width: reach * 2, height: reach * 2))
    }

    /// Herbert: a glossy white robot with a visor, glowing eyes and an antenna. Every part is placed in the board,
    /// so his face turns with him and with the camera.
    func paintRobot(_ context: inout GraphicsContext) {
        let x = pose.robotX + 0.5
        let y = pose.robotY + 0.5
        let forward = (x: sin(pose.heading), y: -cos(pose.heading))
        let stance = Stance(
            x: x, y: y, forward: forward, side: (x: -forward.y, y: forward.x),
            reach: pixelsPerCell(x: x, y: y, height: 0.4))
        paintShadow(&context, stance)
        // The wheel on the far side goes behind the body and the near one in front of it.
        let nearer = camera.eyeDistanceSquared(
            x: x + stance.side.x * 0.3, y: y + stance.side.y * 0.3, height: 0.15)
        let farther = camera.eyeDistanceSquared(
            x: x - stance.side.x * 0.3, y: y - stance.side.y * 0.3, height: 0.15)
        let nearSide: Double = nearer < farther ? 1 : -1
        paintWheel(&context, stance, direction: -nearSide)
        paintAxle(&context, stance)
        let body = paintBody(&context, stance)
        paintWheel(&context, stance, direction: nearSide)
        let head = paintHead(&context, stance, shadingOn: body)
        if camera.isFacingEye(direction: forward, atX: x, y: y) { paintFace(&context, stance, on: head) }
        paintAntenna(&context, stance)
    }

    private func paintShadow(_ context: inout GraphicsContext, _ stance: Stance) {
        for (radius, opacity) in [(0.40, 0.07), (0.33, 0.10), (0.26, 0.16)] {
            context.fill(
                floorCircle(x: stance.x, y: stance.y, height: 0.01, radius: radius),
                with: .color(Color(red: 0.12, green: 0.08, blue: 0.04).opacity(opacity)))
        }
    }

    /// A wheel is two discs a hair apart, so it has thickness; `direction` picks the side.
    private func paintWheel(_ context: inout GraphicsContext, _ stance: Stance, direction: Double) {
        let center = (
            x: stance.x + stance.side.x * 0.26 * direction, y: stance.y + stance.side.y * 0.26 * direction, z: 0.15
        )
        let outward = (x: stance.side.x * 0.035 * direction, y: stance.side.y * 0.035 * direction)
        func disc(_ shift: Double, radius: Double) -> Path {
            ellipse(
                at: (center.x + outward.x * shift, center.y + outward.y * shift, center.z),
                u: (stance.forward.x, stance.forward.y, 0), v: (0, 0, 1), radiusU: radius, radiusV: radius)
        }
        context.fill(disc(-1, radius: 0.145), with: .color(Board3DPalette.rubber.lit(0.8).color()))
        context.fill(disc(1, radius: 0.145), with: .color(Board3DPalette.rubber.color()))
        context.fill(disc(1, radius: 0.07), with: .color(Tone(0x8D979F).color()))
    }

    private func paintAxle(_ context: inout GraphicsContext, _ stance: Stance) {
        var axle = Path()
        axle.move(to: screen(stance.x + stance.side.x * 0.26, stance.y + stance.side.y * 0.26, 0.15))
        axle.addLine(to: screen(stance.x - stance.side.x * 0.26, stance.y - stance.side.y * 0.26, 0.15))
        context.stroke(axle, with: .color(Board3DPalette.rubber.color()), lineWidth: max(1, stance.reach * 0.06))
    }

    /// Returns the body outline so the head can shade it.
    private func paintBody(_ context: inout GraphicsContext, _ stance: Stance) -> Path {
        let shell = Board3DPalette.shell
        let body = sphere(x: stance.x, y: stance.y, height: 0.34, radius: 0.24)
        let box = body.boundingRect
        context.fill(
            body,
            with: .radialGradient(
                Gradient(colors: [shell.color(), shell.color(), Board3DPalette.shellShade.color()]),
                center: CGPoint(x: box.midX - box.width * 0.16, y: box.midY - box.height * 0.2), startRadius: 0,
                endRadius: box.width * 0.75))
        context.stroke(body, with: .color(Board3DPalette.shellShade.lit(0.8).color(0.55)), lineWidth: 1)
        return body
    }

    /// Returns the head outline so the face can be clipped to it.
    private func paintHead(_ context: inout GraphicsContext, _ stance: Stance, shadingOn body: Path) -> Path {
        var shadow = context
        shadow.clip(to: body)
        shadow.fill(
            sphere(x: stance.x, y: stance.y, height: 0.64, radius: 0.28), with: .color(.black.opacity(0.13)))
        let shell = Board3DPalette.shell
        let head = sphere(x: stance.x, y: stance.y, height: 0.74, radius: 0.27)
        let box = head.boundingRect
        context.fill(
            head,
            with: .radialGradient(
                Gradient(colors: [.white, shell.color(), Board3DPalette.shellShade.color()]),
                center: CGPoint(x: box.midX - box.width * 0.18, y: box.midY - box.height * 0.22), startRadius: 0,
                endRadius: box.width * 0.8))
        context.stroke(head, with: .color(Board3DPalette.shellShade.lit(0.8).color(0.6)), lineWidth: 1)
        return head
    }

    /// A dark visor with two glowing eyes on the side he faces; it wraps around the head as he turns.
    private func paintFace(_ context: inout GraphicsContext, _ stance: Stance, on head: Path) {
        var face = context
        face.clip(to: head)
        let center = (x: stance.x + stance.forward.x * 0.22, y: stance.y + stance.forward.y * 0.22, z: 0.77)
        let across = (x: stance.side.x, y: stance.side.y, z: 0.0)
        let visor = ellipse(at: center, u: across, v: (0, 0, 1), radiusU: 0.165, radiusV: 0.095)
        let box = visor.boundingRect
        face.fill(
            visor,
            with: .linearGradient(
                Gradient(colors: [Tone(0x34464F).color(), Board3DPalette.visor.color()]),
                startPoint: CGPoint(x: box.midX, y: box.minY), endPoint: CGPoint(x: box.midX, y: box.maxY)))
        face.stroke(
            visor, with: .color(Board3DPalette.shellShade.color(0.7)), lineWidth: max(1, stance.reach * 0.03))
        face.fill(
            ellipse(at: center, u: across, v: (0, 0, 1), radiusU: 0.13, radiusV: 0.07),
            with: .color(Board3DPalette.eye.color(0.16)))
        for direction in [-1.0, 1.0] {
            let eye = (
                x: center.x + stance.side.x * 0.06 * direction, y: center.y + stance.side.y * 0.06 * direction,
                z: center.z
            )
            face.fill(
                ellipse(at: eye, u: across, v: (0, 0, 1), radiusU: 0.038, radiusV: 0.052),
                with: .color(Board3DPalette.eye.color()))
        }
    }

    private func paintAntenna(_ context: inout GraphicsContext, _ stance: Stance) {
        var antenna = Path()
        antenna.move(to: screen(stance.x, stance.y, 1.0))
        antenna.addLine(to: screen(stance.x, stance.y, 1.11))
        context.stroke(
            antenna, with: .color(Board3DPalette.shellShade.lit(0.85).color()),
            lineWidth: max(1, stance.reach * 0.03))
        context.fill(
            sphere(x: stance.x, y: stance.y, height: 1.13, radius: 0.085), with: .color(Board3DPalette.eye.color(0.25)))
        context.fill(
            sphere(x: stance.x, y: stance.y, height: 1.13, radius: 0.045), with: .color(Board3DPalette.eye.color()))
    }
}
