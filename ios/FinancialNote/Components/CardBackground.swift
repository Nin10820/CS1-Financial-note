import SwiftUI

/// The dark card's colour (Spent today, Remaining, Statement, Taken care of): a soft mesh of the
/// brand greens with light coming from the top-left, like the owner's reference card.
/// The greens stay dark enough that white text keeps at least 4.5:1 everywhere text sits.
struct CardGradient: View {
    var body: some View {
        ZStack {
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.55, 0], [1, 0],
                    [0, 0.45], [0.6, 0.55], [1, 0.4],
                    [0, 1], [0.45, 1], [1, 1],
                ],
                colors: [
                    Color(hex: 0x3B6922), Color(hex: 0x30561C), Color(hex: 0x33612A),
                    Color(hex: 0x2E521D), Color(hex: 0x24401A), Color(hex: 0x284D27),
                    Color(hex: 0x24401A), Color(hex: 0x1C3314), Color(hex: 0x14270C),
                ],
                smoothsColors: true)
            // Soft light in the top-left corner, as in the reference.
            RadialGradient(colors: [Color(hex: 0x83C853).opacity(0.22), .clear],
                           center: .topLeading, startRadius: 0, endRadius: 260)
            // A faint cool tint at the bottom-left keeps it from looking flat.
            RadialGradient(colors: [Color(hex: 0x1F6B5E).opacity(0.18), .clear],
                           center: .bottomLeading, startRadius: 0, endRadius: 220)
        }
        .accessibilityHidden(true)
    }
}
