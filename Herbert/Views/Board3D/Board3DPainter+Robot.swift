import HerbertCore
import SwiftUI

extension Board3DPainter {
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
        let side = (x: -forward.y, y: forward.x)
        let shell = Board3DPalette.shell
        let reach = pixelsPerCell(x: x, y: y, height: 0.4)

        for (radius, opacity) in [(0.40, 0.07), (0.33, 0.10), (0.26, 0.16)] {
            context.fill(
                floorCircle(x: x, y: y, height: 0.01, radius: radius),
                with: .color(Color(red: 0.12, green: 0.08, blue: 0.04).opacity(opacity)))
        }

        func wheel(_ direction: Double) {
            let center = (x: x + side.x * 0.26 * direction, y: y + side.y * 0.26 * direction, z: 0.15)
            let outward = (x: side.x * 0.035 * direction, y: side.y * 0.035 * direction)
            func disc(_ shift: Double, radius: Double) -> Path {
                ellipse(
                    at: (center.x + outward.x * shift, center.y + outward.y * shift, center.z),
                    u: (forward.x, forward.y, 0),
                    v: (0, 0, 1), radiusU: radius, radiusV: radius)
            }
            context.fill(disc(-1, radius: 0.145), with: .color(Board3DPalette.rubber.lit(0.8).color()))
            context.fill(disc(1, radius: 0.145), with: .color(Board3DPalette.rubber.color()))
            context.fill(disc(1, radius: 0.07), with: .color(Tone(0x8D979F).color()))
        }
        let nearSide: Double =
            camera.eyeDistanceSquared(x: x + side.x * 0.3, y: y + side.y * 0.3, height: 0.15)
                < camera.eyeDistanceSquared(x: x - side.x * 0.3, y: y - side.y * 0.3, height: 0.15) ? 1 : -1
        wheel(-nearSide)
        var axle = Path()
        axle.move(to: screen(x + side.x * 0.26, y + side.y * 0.26, 0.15))
        axle.addLine(to: screen(x - side.x * 0.26, y - side.y * 0.26, 0.15))
        context.stroke(axle, with: .color(Board3DPalette.rubber.color()), lineWidth: max(1, reach * 0.06))

        let body = sphere(x: x, y: y, height: 0.34, radius: 0.24)
        let bodyBox = body.boundingRect
        context.fill(
            body,
            with: .radialGradient(
                Gradient(colors: [shell.color(), shell.color(), Board3DPalette.shellShade.color()]),
                center: CGPoint(x: bodyBox.midX - bodyBox.width * 0.16, y: bodyBox.midY - bodyBox.height * 0.2),
                startRadius: 0, endRadius: bodyBox.width * 0.75))
        context.stroke(body, with: .color(Board3DPalette.shellShade.lit(0.8).color(0.55)), lineWidth: 1)
        wheel(nearSide)

        var occlusion = context
        occlusion.clip(to: body)
        occlusion.fill(sphere(x: x, y: y, height: 0.64, radius: 0.28), with: .color(.black.opacity(0.13)))

        let head = sphere(x: x, y: y, height: 0.74, radius: 0.27)
        let headBox = head.boundingRect
        context.fill(
            head,
            with: .radialGradient(
                Gradient(colors: [.white, shell.color(), Board3DPalette.shellShade.color()]),
                center: CGPoint(x: headBox.midX - headBox.width * 0.18, y: headBox.midY - headBox.height * 0.22),
                startRadius: 0, endRadius: headBox.width * 0.8))
        context.stroke(head, with: .color(Board3DPalette.shellShade.lit(0.8).color(0.6)), lineWidth: 1)

        if camera.isFacingEye(direction: forward, atX: x, y: y) {
            var face = context
            face.clip(to: head)
            let center = (x: x + forward.x * 0.22, y: y + forward.y * 0.22, z: 0.77)
            let across = (x: side.x, y: side.y, z: 0.0)
            let visor = ellipse(at: center, u: across, v: (0, 0, 1), radiusU: 0.165, radiusV: 0.095)
            let visorBox = visor.boundingRect
            face.fill(
                visor,
                with: .linearGradient(
                    Gradient(colors: [Tone(0x34464F).color(), Board3DPalette.visor.color()]),
                    startPoint: CGPoint(x: visorBox.midX, y: visorBox.minY),
                    endPoint: CGPoint(x: visorBox.midX, y: visorBox.maxY)))
            face.stroke(visor, with: .color(Board3DPalette.shellShade.color(0.7)), lineWidth: max(1, reach * 0.03))
            face.fill(
                ellipse(at: center, u: across, v: (0, 0, 1), radiusU: 0.13, radiusV: 0.07),
                with: .color(Board3DPalette.eye.color(0.16)))
            for direction in [-1.0, 1.0] {
                let eye = (
                    x: center.x + side.x * 0.06 * direction, y: center.y + side.y * 0.06 * direction, z: center.z
                )
                face.fill(
                    ellipse(at: eye, u: across, v: (0, 0, 1), radiusU: 0.038, radiusV: 0.052),
                    with: .color(Board3DPalette.eye.color()))
            }
        }

        var antenna = Path()
        antenna.move(to: screen(x, y, 1.0))
        antenna.addLine(to: screen(x, y, 1.11))
        context.stroke(
            antenna, with: .color(Board3DPalette.shellShade.lit(0.85).color()), lineWidth: max(1, reach * 0.03))
        context.fill(sphere(x: x, y: y, height: 1.13, radius: 0.085), with: .color(Board3DPalette.eye.color(0.25)))
        context.fill(sphere(x: x, y: y, height: 1.13, radius: 0.045), with: .color(Board3DPalette.eye.color()))
    }
}
