import SwiftUI
import UIKit

/// A sideways swipe across a page: left goes forward (next day, next tab), right goes back.
///
/// Built on UIKit's pan recogniser rather than a SwiftUI drag, because a SwiftUI drag doesn't
/// stop the button under the finger from firing when the finger lifts — swipes turned into taps.
/// This one only starts on a clearly sideways move, and the moment it starts it cancels the
/// touch for everything underneath (`cancelsTouchesInView`), so no row, card or button fires.
/// Parts with their own sideways drag (Recent rows, the week and month strips, charts) mark
/// themselves with `.noPageSwipe()` and keep it.
struct PageSwipe: ViewModifier {
    var onBack: () -> Void
    var onForward: () -> Void

    func body(content: Content) -> some View {
        content
            .contentShape(.rect)
            .gesture(PagePan(onBack: onBack, onForward: onForward))
    }
}

extension View {
    func pageSwipe(back: @escaping () -> Void, forward: @escaping () -> Void) -> some View {
        modifier(PageSwipe(onBack: back, onForward: forward))
    }

    /// This area has its own sideways drag: a page swipe doesn't start here.
    func noPageSwipe() -> some View {
        modifier(NoPageSwipeZone())
    }
}

/// Where page swipes must not start, in window coordinates (SwiftUI's global space).
@MainActor
final class SwipeZones {
    static let shared = SwipeZones()
    var frames: [UUID: CGRect] = [:]

    func contains(_ point: CGPoint) -> Bool {
        frames.values.contains { $0.contains(point) }
    }
}

private struct NoPageSwipeZone: ViewModifier {
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { SwipeZones.shared.frames[id] = $0 }
            .onDisappear { SwipeZones.shared.frames[id] = nil }
    }
}

private struct PagePan: UIGestureRecognizerRepresentable {
    var onBack: () -> Void
    var onForward: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.cancelsTouchesInView = true
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(_ pan: UIPanGestureRecognizer, context: Context) {
        guard pan.state == .ended else { return }
        let t = pan.translation(in: nil), v = pan.velocity(in: nil)
        // Far enough, or a quick flick.
        guard abs(t.x) > 60 || abs(v.x) > 500 else { return }
        if t.x < 0 { onForward() } else { onBack() }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        /// Only a clearly sideways move, and not inside an area with its own drag.
        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
            guard let pan = g as? UIPanGestureRecognizer else { return false }
            let v = pan.velocity(in: nil)
            guard abs(v.x) > abs(v.y) * 1.6 else { return false }
            let start = pan.location(in: nil)
            return MainActor.assumeIsolated { !SwipeZones.shared.contains(start) }
        }
    }
}
