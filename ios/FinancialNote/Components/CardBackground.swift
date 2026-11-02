import SwiftUI

/// The dark card's colour (Total Amount, Remaining, Statement, Taken care of), from Figma
/// __card-transaction: a linear gradient at 136° from #345824 to brand/900 #14270C.
struct CardGradient: View {
    var body: some View {
        LinearGradient(
            colors: [Color(hex: 0x345824), Color(hex: 0x14270C)],
            // 136°: from the top-left corner down to the bottom-right.
            startPoint: UnitPoint(x: 0.14, y: 0),
            endPoint: UnitPoint(x: 0.86, y: 1))
            .accessibilityHidden(true)
    }
}

extension View {
    /// The whole dark card surface as in Figma: the gradient, a light inner edge (white 90% along
    /// the top, white 48–80% along the bottom) and a 0.5 pt dark outline.
    func cardSurface(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background { CardGradient().clipShape(shape) }
            .overlay {
                shape
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.9), location: 0),
                                .init(color: .white.opacity(0.06), location: 0.25),
                                .init(color: .white.opacity(0.06), location: 0.75),
                                .init(color: .white.opacity(0.48), location: 1),
                            ],
                            startPoint: .top, endPoint: .bottom),
                        lineWidth: 1)
                    .blur(radius: 1)
                    .clipShape(shape)
                    .allowsHitTesting(false)
            }
            .overlay { shape.strokeBorder(Color(hex: 0x0D121C).opacity(0.64), lineWidth: 0.5).allowsHitTesting(false) }
    }

    /// A thin light edge on the inside (brighter at the top), like the Figma chips' inner shadow.
    func innerEdge(cornerRadius: CGFloat, top: Double, bottom: Double) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return overlay {
            shape
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(top), location: 0),
                            .init(color: .white.opacity(0.02), location: 0.45),
                            .init(color: .white.opacity(bottom), location: 1),
                        ],
                        startPoint: .top, endPoint: .bottom),
                    lineWidth: 0.75)
                .allowsHitTesting(false)
        }
    }
}
