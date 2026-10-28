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
                .font(AppFont.main(size * 0.78, .medium))
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

    var body: some View {
        HStack(spacing: Space.s12) {
            FlowTile(flow: entry.flow)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(AppFont.main(14, .medium))
                    .foregroundStyle(Tokens.text900)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                CategoryLabel(category: entry.category)
            }
            Spacer(minLength: Space.s8)
            AmountText(value: entry.amount, hidden: hidden)
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
                .padding(.horizontal, Space.s16)
                .padding(.vertical, Space.s6)
                .foregroundStyle(selected ? Tokens.bgWhite : Tokens.text700)
                .background(selected ? Tokens.text900 : Tokens.bg4, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Used by tabs that aren't built yet. Says so plainly — never a fake screen.
struct ComingLaterView: View {
    var title: String
    var systemImage: String
    var text: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("\(title) comes later", systemImage: systemImage)
                    .font(AppFont.heading(22))
            } description: {
                Text(text).font(AppFont.main(15))
            }
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inline)
        }
    }
}
