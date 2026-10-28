import SwiftUI
import UIKit

/// Animates a change, or just makes it when Reduce Motion is on.
func animate(_ animation: Animation = .snappy, _ body: () -> Void) {
    if UIAccessibility.isReduceMotionEnabled {
        body()
    } else {
        withAnimation(animation, body)
    }
}

extension AnyTransition {
    /// Slides up from the bottom, or only fades when Reduce Motion is on.
    static var sheetLike: AnyTransition {
        UIAccessibility.isReduceMotionEnabled ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }
}
