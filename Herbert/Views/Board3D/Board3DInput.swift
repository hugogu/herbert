import HerbertCore
import SwiftUI

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Turns touches, mouse drags and trackpad gestures into camera moves: drag to orbit, pinch to zoom toward the
/// fingers, twist to turn, double-tap to reset. Shift-drag pans with a mouse; two fingers pan on a touch screen.
struct Board3DInput: ViewModifier {
    @Binding var rig: BoardCameraRig
    let size: CGSize
    /// Inside a scrolling page, vertical drags belong to the page and only horizontal drags orbit.
    let yieldsVerticalDrags: Bool
    let onReset: () -> Void

    #if os(macOS)
        @State private var dragged = CGSize.zero
        @State private var dragPans = false
        @State private var gesturing = false
        @State private var magnified = 1.0
        @State private var twisted = 0.0
    #endif

    func body(content: Content) -> some View {
        #if os(iOS)
            content.overlay {
                Board3DTouchSurface(
                    yieldsVerticalDrags: yieldsVerticalDrags,
                    onOrbit: { rig.orbit(dx: $0.width, dy: $0.height, allowsTilt: !yieldsVerticalDrags) },
                    onPan: {
                        rig.pan(by: $0, in: size)
                        rig.follow = false
                    },
                    onZoom: { rig.zoom(by: $0, about: $1, in: size) },
                    onTwist: { rig.yaw += $0 },
                    onReset: onReset
                ).accessibilityHidden(true)
            }
        #else
            content.contentShape(Rectangle()).gesture(macGestures).onTapGesture(count: 2, perform: onReset)
        #endif
    }

    #if os(macOS)
        private var macGestures: some Gesture {
            let drag = DragGesture(minimumDistance: 3)
                .onChanged { value in
                    let delta = CGSize(
                        width: value.translation.width - dragged.width,
                        height: value.translation.height - dragged.height)
                    if dragged == .zero { dragPans = NSEvent.modifierFlags.contains(.shift) }
                    dragged = value.translation
                    guard !gesturing else { return }
                    if dragPans {
                        rig.pan(by: delta, in: size)
                        rig.follow = false
                    } else {
                        rig.orbit(dx: delta.width, dy: delta.height, allowsTilt: true)
                    }
                }
                .onEnded { _ in
                    dragged = .zero
                    dragPans = false
                }
            let pinch = MagnifyGesture()
                .onChanged { value in
                    gesturing = true
                    rig.zoom(by: value.magnification / magnified, about: value.startLocation, in: size)
                    magnified = value.magnification
                }
                .onEnded { _ in
                    gesturing = false
                    magnified = 1
                }
            let twist = RotateGesture()
                .onChanged { value in
                    gesturing = true
                    rig.yaw += value.rotation.radians - twisted
                    twisted = value.rotation.radians
                }
                .onEnded { _ in
                    gesturing = false
                    twisted = 0
                }
            return drag.simultaneously(with: pinch.simultaneously(with: twist))
        }
    #endif
}

#if os(iOS)
    /// UIKit gestures can refuse to begin, which SwiftUI's cannot: vertical drags fail here so the page's scroll
    /// view takes them, while horizontal drags orbit the board.
    private struct Board3DTouchSurface: UIViewRepresentable {
        let yieldsVerticalDrags: Bool
        let onOrbit: (CGSize) -> Void
        let onPan: (CGSize) -> Void
        let onZoom: (Double, CGPoint) -> Void
        let onTwist: (Double) -> Void
        let onReset: () -> Void

        func makeCoordinator() -> Coordinator { Coordinator() }

        func makeUIView(context: Context) -> UIView {
            let view = UIView()
            view.backgroundColor = .clear
            view.isAccessibilityElement = false
            let coordinator = context.coordinator
            let orbit = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.orbit(_:)))
            orbit.maximumNumberOfTouches = 1
            let pan = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.pan(_:)))
            pan.minimumNumberOfTouches = 2
            pan.maximumNumberOfTouches = 2
            let pinch = UIPinchGestureRecognizer(target: coordinator, action: #selector(Coordinator.pinch(_:)))
            let twist = UIRotationGestureRecognizer(target: coordinator, action: #selector(Coordinator.twist(_:)))
            let doubleTap = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.reset))
            doubleTap.numberOfTapsRequired = 2
            for recognizer in [orbit, pan, pinch, twist, doubleTap] as [UIGestureRecognizer] {
                recognizer.delegate = coordinator
                view.addGestureRecognizer(recognizer)
            }
            coordinator.orbitRecognizer = orbit
            return view
        }

        func updateUIView(_ view: UIView, context: Context) { context.coordinator.surface = self }

        @MainActor
        final class Coordinator: NSObject, UIGestureRecognizerDelegate {
            var surface: Board3DTouchSurface?
            weak var orbitRecognizer: UIPanGestureRecognizer?

            @objc func orbit(_ recognizer: UIPanGestureRecognizer) {
                let delta = recognizer.translation(in: recognizer.view)
                recognizer.setTranslation(.zero, in: recognizer.view)
                surface?.onOrbit(CGSize(width: delta.x, height: delta.y))
            }

            @objc func pan(_ recognizer: UIPanGestureRecognizer) {
                let delta = recognizer.translation(in: recognizer.view)
                recognizer.setTranslation(.zero, in: recognizer.view)
                surface?.onPan(CGSize(width: delta.x, height: delta.y))
            }

            @objc func pinch(_ recognizer: UIPinchGestureRecognizer) {
                guard recognizer.state == .changed else { return }
                surface?.onZoom(Double(recognizer.scale), recognizer.location(in: recognizer.view))
                recognizer.scale = 1
            }

            @objc func twist(_ recognizer: UIRotationGestureRecognizer) {
                guard recognizer.state == .changed else { return }
                surface?.onTwist(Double(recognizer.rotation))
                recognizer.rotation = 0
            }

            @objc func reset() { surface?.onReset() }

            func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
                guard recognizer === orbitRecognizer, surface?.yieldsVerticalDrags == true,
                    let pan = recognizer as? UIPanGestureRecognizer
                else { return true }
                let velocity = pan.velocity(in: pan.view)
                return abs(velocity.x) > abs(velocity.y)
            }

            func gestureRecognizer(
                _ recognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
            ) -> Bool {
                recognizer.view === other.view && recognizer !== orbitRecognizer && other !== orbitRecognizer
            }
        }
    }
#endif
