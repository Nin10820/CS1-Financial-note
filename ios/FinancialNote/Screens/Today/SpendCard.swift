import SwiftUI

/// The dark green "Spent today" card (Final 765:19666): total, eye to hide amounts,
/// "n notes · updated 21:14", Out / In with dotted leaders, and Summary.
struct SpendCard: View {
    var label: String
    var out: Int
    var incoming: Int
    var meta: String
    @Binding var hidden: Bool
    var onSummary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            Text(label)
                .font(AppFont.main(14, .medium))
                .foregroundStyle(.white.opacity(0.8))
            HStack(alignment: .center, spacing: Space.s12) {
                HStack(alignment: .firstTextBaseline, spacing: Space.s4) {
                    Text(hidden ? "••••••" : Money.format(out))
                        .font(AppFont.main(32, .bold, relativeTo: .largeTitle))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text("đ")
                        .font(AppFont.main(24, .semibold, relativeTo: .title))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(hidden ? "\(label), hidden" : "\(label), \(Money.format(out)) dong")
                Button {
                    hidden.toggle()
                } label: {
                    Image(systemName: hidden ? "eye" : "eye.slash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.1), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hidden ? "Show amounts" : "Hide amounts")
            }
            Text(meta)
                .font(AppFont.main(12, .regular, relativeTo: .caption))
                .foregroundStyle(.white.opacity(0.64))
            VStack(spacing: Space.s8) {
                LeaderRow(filled: true, label: "Out", value: out, hidden: hidden)
                LeaderRow(filled: false, label: "In", value: incoming, hidden: hidden)
            }
            .padding(.top, Space.s8)
            Button(action: onSummary) {
                Label("Summary", systemImage: "chart.pie.fill")
                    .font(AppFont.main(14, .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Space.s12)
                    .padding(.vertical, Space.s8)
                    .background(.white.opacity(0.1), in: .capsule)
                    .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .padding(.top, Space.s8)
        }
        .padding(Space.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.cardGradient, in: .rect(cornerRadius: Corner.c16))
        .shadow(color: .black.opacity(0.16), radius: 9, y: 6)
    }
}

private struct LeaderRow: View {
    var filled: Bool
    var label: String
    var value: Int
    var hidden: Bool

    var body: some View {
        HStack(spacing: Space.s8) {
            Circle()
                .fill(filled ? Tokens.brand400 : .clear)
                .strokeBorder(Color(hex: 0x83C853), lineWidth: 1.5)
                .frame(width: 8, height: 8)
            Text(label).font(AppFont.main(14, .medium)).foregroundStyle(.white)
            Line()
                .stroke(.white.opacity(0.32), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                .frame(height: 1)
            AmountText(value: value, hidden: hidden, color: .white, currencyColor: .white.opacity(0.5))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hidden ? "\(label), hidden" : "\(label), \(Money.format(value)) dong")
    }
}

private nonisolated struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}
