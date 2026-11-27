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
                .font(size >= 24 ? AppFont.amount(size) : AppFont.main(size, .medium))
                .foregroundStyle(color)
                .monospacedDigit()
            Text("đ")
                .font(size >= 24 ? AppFont.currency(for: size) : AppFont.main(12, .medium))
                .foregroundStyle(currencyColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hidden ? "Hidden amount" : "\(sign == "-" ? "minus " : "")\(value.map(Money.format) ?? "no amount") dong")
    }
}

/// A big amount being typed, in the amount font.
struct BigAmount: View {
    var value: Int?
    var size: CGFloat = 44

    var body: some View {
        Text(value.map(Money.format) ?? "0")
            .font(AppFont.amount(size))
            .monospacedDigit()
            .contentTransition(.numericText())
    }
}

/// A big number you can tap into: tap a digit and the caret goes after it, so the number pad
/// changes that spot (118,000,000 → tap after 8, ⌫, 20 → 120,000,000). `cursor` counts the
/// characters to the right of the caret (0 = at the end); grouping commas don't count for đồng.
struct CaretNumber: View {
    let text: String
    /// True for typed decimals ("5,5"): every character counts, the comma too.
    var commaCounts = false
    @Binding var cursor: Int
    var size: CGFloat = 40

    private func counts(_ c: Character) -> Bool { c.isNumber || (commaCounts && c == ",") }

    var body: some View {
        let chars = Array(text)
        let total = chars.filter(counts).count
        // After which character the caret sits (-1 = before the first).
        let caretAfter: Int = {
            if cursor <= 0 { return chars.count - 1 }
            if cursor >= total { return -1 }
            var after = 0
            for i in chars.indices.reversed() {
                if counts(chars[i]) {
                    if after == cursor { return i }
                    after += 1
                }
            }
            return -1
        }()
        // Biggest size that fits the line (long numbers shrink, like minimumScaleFactor).
        ViewThatFits(in: .horizontal) {
            ForEach([size, size * 0.85, size * 0.7, size * 0.6], id: \.self) { s in
                row(chars, caretAfter: caretAfter, size: s)
            }
        }
    }

    private func row(_ chars: [Character], caretAfter: Int, size s: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if caretAfter == -1 { caret(s) }
            ForEach(chars.indices, id: \.self) { i in
                Text(String(chars[i]))
                    .padding(.vertical, Space.s8)
                    .contentShape(.rect)
                    .onTapGesture {
                        withAnimation(.snappy(duration: 0.15)) {
                            cursor = chars[(i + 1)...].filter(counts).count
                        }
                    }
                if i == caretAfter { caret(s) }
            }
        }
        .font(AppFont.heading(s, .medium))
        .monospacedDigit()
        .fixedSize()
    }

    private func caret(_ size: CGFloat) -> some View {
        Capsule().fill(Tokens.brand500)
            .frame(width: 2.5, height: size * 0.8)
            .padding(.horizontal, 1)
            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - size * 0.08 }
            .phaseAnimator([1.0, 0.1]) { view, o in view.opacity(o) } animation: { _ in .easeInOut(duration: 0.55) }
            .accessibilityHidden(true)
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

/// Round arrow tile for money out / in (Figma __trans-item): ↗ on peach, ↘ on pale green.
struct FlowTile: View {
    var flow: Flow

    var body: some View {
        AppIcon(flow == .out ? .arrowUpRight : .arrowDownRight, size: 18)
            .foregroundStyle(flow == .out ? Tokens.secondary500 : Tokens.brand700)
            .frame(width: 36, height: 36)
            .background(flow == .out ? Tokens.secondary100 : Tokens.brand50, in: .circle)
            .accessibilityHidden(true)
    }
}

/// One saved line in a list (Figma __trans-item): round tile, title, "Category • 21:14:00",
/// and the amount in Bricolage — grey for money out, green for money in.
struct EntryRow: View {
    var entry: Entry
    var hidden: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: Space.s8) {
            FlowTile(flow: entry.flow)
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(AppFont.body(.medium))
                        .foregroundStyle(Tokens.text900)
                        .lineLimit(typeSize.isAccessibilitySize ? 4 : 2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: Space.s8) {
                        CategoryLabel(category: entry.category)
                        Circle().fill(Tokens.grey300).frame(width: 4, height: 4).accessibilityHidden(true)
                        Text(entry.createdAt.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits)))
                            .font(AppFont.capture())
                            .foregroundStyle(Tokens.grey400)
                            .monospacedDigit()
                    }
                    // Very large text: the amount goes under the name instead of squeezing it.
                    if typeSize.isAccessibilitySize { amount }
                }
                Spacer(minLength: Space.s8)
                if !typeSize.isAccessibilitySize { amount.fixedSize() }
            }
            .padding(.horizontal, Space.s4)
            .padding(.vertical, Space.s8)
        }
        .frame(minHeight: 56)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the details")
    }

    private var amount: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(hidden ? "••••••" : Money.format(entry.amount))
                .font(AppFont.heading(14, .medium, relativeTo: .body))
                .foregroundStyle(entry.flow == .in ? Tokens.brand600 : Tokens.text700)
                .monospacedDigit()
            Text("đ")
                .font(AppFont.heading(14, .regular, relativeTo: .body))
                .foregroundStyle(Tokens.grey400)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hidden ? "Hidden amount" : "\(entry.flow == .in ? "in " : "")\(Money.format(entry.amount)) dong")
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
            if let title { Text(title).font(AppFont.main(14, .semibold)) }
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
        // Not `.disabled`: iOS would fade it. It stays in full colour and just does nothing.
        Button { if enabled { action() } } label: {
            Image(systemName: "paperplane")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Tokens.action, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Send")
        .accessibilityHint(enabled ? "" : "Write something first")
    }
}

extension View {
    /// The composer's Liquid Glass panel: clear glass (no white wash, so it reads as glass over
    /// a light page), a thin bright rim and a soft shadow, as in the owner's reference.
    func composerGlass() -> some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        return self
            .glassEffect(.regular.interactive(), in: shape)
            .overlay(
                shape.strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.95), Tokens.text900.opacity(0.10)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 1)
                .allowsHitTesting(false))
            .shadow(color: .black.opacity(0.08), radius: 18, y: 6)
    }
}
