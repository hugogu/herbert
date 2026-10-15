import HerbertCore
import SwiftUI

/// The 3D board: a lit diorama of the same board, trail and Herbert that Classic and Modern draw flat.
struct Board3DDrawing: View, Animatable {
    let board: Board
    let visited: Set<GridPoint>
    let trail: Set<TrailSegment>
    var showTrail: Bool
    var showGridDots: Bool
    var pose: Board3DPose

    nonisolated var animatableData: Board3DPose {
        get { pose }
        set { pose = newValue }
    }

    var body: some View {
        Canvas { context, size in
            Board3DPainter(
                board: board, visited: visited, trail: trail, showTrail: showTrail, showGridDots: showGridDots,
                pose: pose, size: size
            ).paint(&context)
        }
    }
}
