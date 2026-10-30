import SwiftUI

/// The dark green "Spent today" card (Final 765:19666): total, eye to hide amounts,
/// "n notes · updated 21:14", Out / In with dotted leaders, and Summary.
struct SpendCard: View {
    var label: String
    var out: Int
    var incoming: Int
    var meta: String
    @Binding var hidden: Bool
    var onSummary: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            Text(label)
                .font(AppFont.capture())
                .foregroundStyle(Tokens.onDark)
            HStack(alignment: .center, spacing: Space.s12) {
                HStack(alignment: .firstTextBaseline, spacing: Space.s4) {
                    Text(hidden ? "••••••" : Money.format(out))
                        .font(AppFont.amount(40))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text("đ")
                        .font(AppFont.currency(for: 40))
                        .foregroundStyle(Tokens.onDark)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(hidden ? "\(label), hidden" : "\(label), \(Money.format(out)) dong")
                Button {
                    hidden.toggle()
                } label: {
                    Image(systemName: hidden ? "eye" : "eye.slash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Tokens.onDark)
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.1), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hidden ? "Show amounts" : "Hide amounts")
            }
            Text(meta)
                .font(AppFont.capture(.medium))
                .foregroundStyle(Tokens.onDarkMuted)
            VStack(alignment: .leading, spacing: Space.s8) {
                HeroLeader(filled: true, label: "Out", value: out, hidden: hidden)
                HeroLeader(filled: false, label: "In", value: incoming, hidden: hidden)
            }
            .padding(.top, Space.s8)
            if let onSummary {
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
        }
        .padding(Space.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { CardGradient().clipShape(.rect(cornerRadius: Corner.c20)) }
        .shadow(color: .black.opacity(0.16), radius: 9, y: 6)
    }
}
