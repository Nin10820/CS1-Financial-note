import SwiftUI

/// The field in the tab bar's bottom accessory: tap it to write a quick note. The write menu on
/// the right offers Quick note and Notes of the day (the green write button in Figma Ver 2).
struct QuickNoteAccessory: View {
    @Environment(AppState.self) private var app
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        HStack(spacing: Space.s8) {
            Button {
                app.openQuickNote()
            } label: {
                HStack(spacing: Space.s8) {
                    LogoMark(size: 20)
                    Text(placement == .inline ? "Quick note" : "e.g. coffee 24k, breakfast 35k…")
                        .font(AppFont.main(14))
                        .foregroundStyle(Tokens.text700)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Write a quick note")

            Menu {
                Button("Quick note", systemImage: "square.and.pencil") { app.openQuickNote() }
                Button("Notes of the day", systemImage: "note.text") { app.dayNoteOpen = true }
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Tokens.brand500)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Write")
        }
        .padding(.horizontal, Space.s16)
    }
}
