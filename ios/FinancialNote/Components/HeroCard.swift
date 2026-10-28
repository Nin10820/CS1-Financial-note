import SwiftUI

/// The dark green card shared by Due (Remaining) and Installments (Statement):
/// label, big amount, optional eye, optional sub line, two leader rows and buttons.
struct HeroCard<Buttons: View>: View {
    var label: String
    var amount: Int
    var sub: String?
    var rows: [(label: String, value: Int)]
    @Binding var hidden: Bool
    var showEye = true
    @ViewBuilder var buttons: Buttons

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            Text(label.uppercased())
                .font(AppFont.main(13, .medium, relativeTo: .caption))
                .tracking(0.4)
                .foregroundStyle(Tokens.onDark)
            HStack(spacing: Space.s12) {
                HStack(alignment: .firstTextBaseline, spacing: Space.s4) {
                    Text(hidden ? "••••••" : Money.format(amount))
                        .font(AppFont.main(32, .bold, relativeTo: .largeTitle))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("đ")
                        .font(AppFont.main(24, .semibold, relativeTo: .title))
                        .foregroundStyle(Tokens.onDark)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(hidden ? "\(label), hidden" : "\(label), \(Money.format(amount)) dong")
                if showEye {
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
            }
            if let sub {
                Text(sub)
                    .font(AppFont.main(14, .medium))
                    .foregroundStyle(Tokens.onDarkMuted)
            }
            VStack(alignment: .leading, spacing: Space.s8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    HeroLeader(filled: i == 0, label: row.label, value: row.value, hidden: hidden)
                }
            }
            .padding(.top, Space.s8)
            Divider().overlay(.white.opacity(0.12)).padding(.top, Space.s4)
            HStack(spacing: Space.s8) { buttons }
                .padding(.top, Space.s4)
        }
        .padding(Space.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.cardGradient, in: .rect(cornerRadius: Corner.c16))
        .shadow(color: .black.opacity(0.16), radius: 9, y: 6)
    }
}

/// A capsule button on the dark card ("History", "Coming up", "Summary").
struct HeroButton: View {
    var title: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(AppFont.main(14, .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, Space.s12)
                .padding(.vertical, Space.s8)
                .background(.white.opacity(0.1), in: .capsule)
                .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}

struct HeroLeader: View {
    var filled: Bool
    var label: String
    var value: Int
    var hidden: Bool

    var body: some View {
        // One line with a dotted leader; at large text sizes the amount goes under the label.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.s8) {
                dot
                name
                DottedLine()
                    .stroke(.white.opacity(0.32), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .frame(minWidth: 16, maxHeight: 1)
                amount
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Space.s8) { dot; name }
                amount.padding(.leading, 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hidden ? "\(label), hidden" : "\(label), \(Money.format(value)) dong")
    }

    private var dot: some View {
        Circle()
            .fill(filled ? Color(hex: 0x83C853) : .clear)
            .strokeBorder(Color(hex: 0x83C853), lineWidth: 1.5)
            .frame(width: 8, height: 8)
    }

    private var name: some View {
        Text(label).font(AppFont.main(14, .medium)).foregroundStyle(.white).lineLimit(1).fixedSize()
    }

    private var amount: some View {
        AmountText(value: value, hidden: hidden, color: .white, currencyColor: .white).fixedSize()
    }
}

nonisolated struct DottedLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

/// A bill's icon tile: solid (Due list) or soft (statement and history lists).
struct BillTile: View {
    var icon: BillIcon
    var size: CGFloat = 36
    var soft = false

    var body: some View {
        let colors = Tokens.billTileSoft(icon)
        Image(systemName: icon.symbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(soft ? colors.ink : .white)
            .frame(width: size, height: size)
            .background(soft ? colors.bg : Tokens.billTile(icon), in: .rect(cornerRadius: size >= 36 ? 12 : 10))
            .accessibilityHidden(true)
    }
}
