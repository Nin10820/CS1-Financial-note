import SwiftUI

/// A row you can slide sideways (Figma Today › Recent): slide right for a green Edit button,
/// left for a red Delete button. Tapping the row opens it, or closes the buttons if they show.
/// VoiceOver gets Edit and Delete as actions instead of the slide.
struct SwipeRow<Content: View>: View {
    var onTap: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void
    @ViewBuilder var content: Content

    @State private var offset: CGFloat = 0
    @State private var start: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let reveal: CGFloat = 60

    var body: some View {
        ZStack {
            HStack {
                if offset > 0 { circle(.pencil, Tokens.brand600, label: "Edit") { close(); onEdit() } }
                Spacer()
                if offset < 0 { circle(.trash, Tokens.todayRed, label: "Delete") { close(); onDelete() } }
            }
            content
                .padding(.horizontal, offset == 0 ? 0 : Space.s8)
                .background(offset == 0 ? .clear : Tokens.bg4, in: .rect(cornerRadius: Corner.c12))
                .offset(x: offset)
                .contentShape(.rect)
                .onTapGesture { offset == 0 ? onTap() : close() }
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { g in
                            guard abs(g.translation.width) > abs(g.translation.height) else { return }
                            offset = max(-reveal * 1.3, min(reveal * 1.3, start + g.translation.width))
                        }
                        .onEnded { g in
                            let to: CGFloat = offset > reveal / 2 ? reveal : offset < -reveal / 2 ? -reveal : 0
                            withAnimation(reduceMotion ? nil : .snappy) { offset = to }
                            start = to
                        }
                )
        }
        .noPageSwipe()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onTap() }
        .accessibilityAction(named: "Edit", onEdit)
        .accessibilityAction(named: "Delete", onDelete)
    }

    private func close() {
        withAnimation(reduceMotion ? nil : .snappy) { offset = 0 }
        start = 0
    }

    private func circle(_ icon: Icon, _ color: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            AppIcon(icon, size: 20)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(color, in: .circle)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
