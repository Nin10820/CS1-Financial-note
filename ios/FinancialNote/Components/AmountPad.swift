import SwiftUI

/// The number pad for amounts (Template, Check payment): 1–9, 000, 0, delete, on a Liquid Glass
/// tray with white rounded keys, like the system keyboard, in light and dark.
/// Typing appends digits; "000" adds three zeros; delete drops the last digit.
struct AmountPad: View {
    @Binding var value: Int?
    /// Shows a "hide" key above the pad (Template); Check payment keeps it up.
    var onDone: (() -> Void)? = nil

    private static let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "000", "0", "⌫"]
    private static let limit = 100_000_000_000

    var body: some View {
        VStack(spacing: Space.s6) {
            if let onDone {
                HStack {
                    Spacer()
                    Button("Done", action: onDone)
                        .font(AppFont.body(.semibold))
                        .foregroundStyle(Tokens.brand700)
                        .frame(minWidth: 44, minHeight: 36)
                        .accessibilityLabel("Hide number pad")
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.s6), count: 3), spacing: Space.s6) {
                ForEach(Self.keys, id: \.self) { k in key(k) }
            }
        }
        .padding(.horizontal, Space.s8)
        .padding(.top, onDone == nil ? Space.s12 : Space.s6)
        .padding(.bottom, Space.s4)
        // Liquid Glass tray tinted the keyboard's grey: rounded on top, following the phone's
        // corners at the bottom, reaching under the home indicator. The system draws the glass
        // (and makes it solid with Reduce Transparency).
        .background {
            Color.clear
                .glassEffect(.regular.tint(Tokens.keypadTray.opacity(0.9)), in: UnevenRoundedRectangle(
                    topLeadingRadius: 28, bottomLeadingRadius: 48, bottomTrailingRadius: 48, topTrailingRadius: 28,
                    style: .continuous))
                .ignoresSafeArea(edges: .bottom)
        }
        .padding(.horizontal, Space.s4)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private func key(_ k: String) -> some View {
        let isDelete = k == "⌫"
        return Button { press(k) } label: {
            Group {
                if isDelete {
                    Image(systemName: "delete.left").font(.system(size: 20, weight: .regular))
                } else {
                    Text(k).font(AppFont.heading(24, .regular, relativeTo: .title2))
                }
            }
            .foregroundStyle(Tokens.text900)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(isDelete ? Color.clear : Tokens.keypadKey, in: .rect(cornerRadius: Corner.c8))
            .shadow(color: isDelete ? .clear : .black.opacity(0.18), radius: 0, y: 1)
            .contentShape(.rect)
        }
        .buttonStyle(KeyPress())
        .accessibilityLabel(isDelete ? "Delete" : k == "000" ? "Three zeros" : k)
    }

    private func press(_ k: String) {
        var v = value ?? 0
        switch k {
        case "⌫": v /= 10
        case "000": v *= 1000
        default: v = v * 10 + (Int(k) ?? 0)
        }
        guard v < Self.limit else { return }
        value = v == 0 && k == "⌫" ? nil : v
    }
}

/// Keys dim a little while pressed, like the system keyboard.
private struct KeyPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.55 : 1)
    }
}
