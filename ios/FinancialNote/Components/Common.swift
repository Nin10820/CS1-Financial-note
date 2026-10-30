import SwiftUI

/// The green sparkle from the logo (vector asset, same artwork as the web app).
struct LogoMark: View {
    var size: CGFloat = 24

    var body: some View {
        Image("LogoMark")
            .resizable()
            .scaledToFit()
            .frame(height: size)
            .accessibilityHidden(true)
    }
}

/// An amount, then a smaller, quieter "đ" — the __amount pattern from Figma.
struct AmountText: View {
    var value: Int?
    var size: CGFloat = 14
    var sign: String = ""
    var hidden = false
    var color: Color = Tokens.text900
    var currencyColor: Color = Tokens.grey400

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(hidden ? "••••••" : sign + (value.map(Money.format) ?? "—"))
                .font(AppFont.main(size, .semibold))
                .foregroundStyle(color)
                .monospacedDigit()
            Text("đ")
                .font(AppFont.main(max(12, size * 0.78), .medium))
                .foregroundStyle(currencyColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hidden ? "Hidden amount" : "\(sign == "-" ? "minus " : "")\(value.map(Money.format) ?? "no amount") dong")
    }
}

/// Category word under an entry title, in the category's colour.
struct CategoryLabel: View {
    var category: Category

    var body: some View {
        Text(category.rawValue)
            .font(AppFont.main(12, .medium, relativeTo: .caption))
            .foregroundStyle(Tokens.category(category))
    }
}

/// Up / down arrow tile for money out / in (Final 765:19666).
struct FlowTile: View {
    var flow: Flow

    var body: some View {
        Image(systemName: flow == .out ? "arrow.up" : "arrow.down")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(flow == .out ? Tokens.secondary500 : Tokens.brand700)
            .frame(width: 36, height: 36)
            .background(flow == .out ? Tokens.secondary100 : Tokens.brand100, in: .rect(cornerRadius: 10))
            .accessibilityHidden(true)
    }
}

/// One saved line in a list: tile, title, category, amount.
struct EntryRow: View {
    var entry: Entry
    var hidden: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: Space.s12) {
            FlowTile(flow: entry.flow)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(AppFont.main(14, .medium))
                    .foregroundStyle(Tokens.text900)
                    .lineLimit(typeSize.isAccessibilitySize ? 4 : 2)
                    .multilineTextAlignment(.leading)
                CategoryLabel(category: entry.category)
                // Very large text: the amount goes under the name instead of squeezing it.
                if typeSize.isAccessibilitySize { AmountText(value: entry.amount, hidden: hidden) }
            }
            Spacer(minLength: Space.s8)
            if !typeSize.isAccessibilitySize { AmountText(value: entry.amount, hidden: hidden).fixedSize() }
        }
        .padding(.vertical, Space.s12)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the details")
    }
}

/// A filter chip: dark when picked, light grey otherwise (Figma List chips).
struct FilterChip: View {
    var label: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(AppFont.main(14, .medium))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, Space.s16)
                .padding(.vertical, Space.s6)
                .foregroundStyle(selected ? Tokens.bgWhite : Tokens.text700)
                .background(selected ? Tokens.text900 : Tokens.bg4, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A soft grey pill or circle inside a glass composer (icon, optional text).
struct ComposerChip: View {
    var systemImage: String
    var title: String?

    var body: some View {
        HStack(spacing: Space.s6) {
            Image(systemName: systemImage).font(.system(size: 16, weight: .semibold))
            if let title { Text(title).font(AppFont.main(15, .semibold)) }
        }
        .foregroundStyle(Tokens.text900)
        .padding(.horizontal, title == nil ? 0 : Space.s16)
        .frame(minWidth: 44, minHeight: 44)
        .background(Tokens.text900.opacity(0.07), in: .capsule)
        .contentShape(.capsule)
    }
}

/// The filled round send button of a composer; always in colour (as in the reference), and does
/// nothing until there is text.
struct SendButton: View {
    var enabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "paperplane")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Tokens.action, in: .circle)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel("Send")
    }
}
