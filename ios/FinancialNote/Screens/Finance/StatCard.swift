import SwiftUI

/// A page's headline in a plain card: a label, the amount large, and up to three small figures
/// in a row underneath (Net worth on Total Asset, Still to pay on Debt).
struct StatCard: View {
    var label: String
    var amount: Int
    var hidden: Bool
    var stats: [(label: String, value: String, highlight: Bool)]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            Text(label).font(AppFont.body(.medium)).foregroundStyle(Tokens.text700)
            AmountText(value: abs(amount), size: 36, sign: amount < 0 ? "-" : "", hidden: hidden)
            // Three in a row; four as two by two.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.s12, alignment: .topLeading),
                                     count: stats.count == 4 ? 2 : max(stats.count, 1)),
                      alignment: .leading, spacing: Space.s12) {
                ForEach(stats.indices, id: \.self) { i in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(stats[i].value)
                            .font(AppFont.main(14, .semibold))
                            .foregroundStyle(stats[i].highlight ? Tokens.success : Tokens.text900)
                            .monospacedDigit()
                        Text(stats[i].label).font(AppFont.main(11)).foregroundStyle(Tokens.grey400)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(Space.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Two parts in one card, split by a faint dashed line: the headline figures on top, the chart
/// that breaks them down underneath.
struct JoinedCard<Top: View, Bottom: View>: View {
    @ViewBuilder var top: Top
    @ViewBuilder var bottom: Bottom

    var body: some View {
        VStack(spacing: 0) {
            top
            GeometryReader { g in
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 0.5))
                    p.addLine(to: CGPoint(x: g.size.width, y: 0.5))
                }
                .stroke(Tokens.bd1, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .frame(height: 1)
            .padding(.horizontal, Space.s16)
            .accessibilityHidden(true)
            bottom
        }
        .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c20))
        // A hairline edge, like iOS grouped cards: there, not standing out.
        .overlay(RoundedRectangle(cornerRadius: Corner.c20).strokeBorder(Tokens.bd1, lineWidth: 0.5))
    }
}
