import SwiftUI

/// The top of every sheet, from Figma "Modal top" (240:2698): a grab bar, the title in the
/// middle, one round 44pt button on each side.
///
/// The right button says what the sheet is for:
/// - `.close`: a sheet you only read (detail, history). ✕ on the right.
/// - `.save`: a sheet you fill in. A green ✓, grey until the form can be saved. Swipe down to leave.
/// - `.done`: a picker (date, tag). The word "Done".
/// - `.check`: the next step of a flow opened from another sheet (with `.back` on the left). A plain ✓.
///
/// The left button is optional: a small extra (history, share), the word "Today", or ← back.
enum SheetLeading {
    case none
    case back
    case icon(String, systemImage: String, action: () -> Void)
    case text(String, action: () -> Void)
}

enum SheetTrailing {
    case none
    case close
    case save(enabled: Bool = true, action: () -> Void)
    case done(String = "Done", action: (() -> Void)? = nil)
    case check(action: () -> Void)
}

extension View {
    /// Sets the sheet's top bar. Use inside the sheet's NavigationStack.
    func sheetHeader(_ title: String, leading: SheetLeading = .none, trailing: SheetTrailing = .close) -> some View {
        modifier(SheetHeaderToolbar(title: title, leading: leading, trailing: trailing))
    }
}

private struct SheetHeaderToolbar: ViewModifier {
    let title: String
    let leading: SheetLeading
    let trailing: SheetTrailing
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { SheetTitle(title) }
                if let left = SheetButtons.leading(leading, glass: false, dismiss: { dismiss() }) {
                    ToolbarItem(placement: .topBarLeading) { left }
                }
                if let right = SheetButtons.trailing(trailing, glass: false, dismiss: { dismiss() }) {
                    ToolbarItem(placement: .topBarTrailing) { right }
                }
            }
            .presentationDragIndicator(.visible)
    }
}

/// The same bar for a small sheet that sizes itself to its content (no NavigationStack),
/// like the date sheets. Put it at the top of the sheet's VStack.
struct SheetHeaderBar: View {
    let title: String
    var leading: SheetLeading = .none
    var trailing: SheetTrailing = .close
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            SheetTitle(title)
            HStack {
                SheetButtons.leading(leading, glass: true, dismiss: { dismiss() })
                Spacer(minLength: Space.s8)
                SheetButtons.trailing(trailing, glass: true, dismiss: { dismiss() })
            }
        }
        .padding(.horizontal, Space.s20)
        .padding(.bottom, Space.s4)
        .frame(minHeight: 44)
        .presentationDragIndicator(.visible)
    }
}

private struct SheetTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(AppFont.main(16, .semibold, relativeTo: .headline))
            .foregroundStyle(Tokens.text900)
            .lineLimit(1)
            .accessibilityAddTraits(.isHeader)
    }
}

private enum SheetButtons {
    static func leading(_ kind: SheetLeading, glass: Bool, dismiss: @escaping () -> Void) -> AnyView? {
        switch kind {
        case .none:
            return nil
        case .back:
            return AnyView(Button("Back", systemImage: "arrow.left", action: dismiss)
                .labelStyle(.iconOnly).tint(Tokens.text900).sheetGlass(glass))
        case let .icon(label, image, action):
            return AnyView(Button(label, systemImage: image, action: action)
                .labelStyle(.iconOnly).tint(Tokens.text900).sheetGlass(glass))
        case let .text(label, action):
            return AnyView(Button(label, action: action)
                .font(AppFont.main(14, .semibold))
                .foregroundStyle(Tokens.brand900)
                .sheetGlass(glass, circle: false))
        }
    }

    static func trailing(_ kind: SheetTrailing, glass: Bool, dismiss: @escaping () -> Void) -> AnyView? {
        switch kind {
        case .none:
            return nil
        case .close:
            return AnyView(Button("Close", systemImage: "xmark", action: dismiss)
                .labelStyle(.iconOnly).tint(Tokens.text900).sheetGlass(glass))
        case let .save(enabled, action):
            return AnyView(Button("Save", systemImage: "checkmark") { action() }
                .labelStyle(.iconOnly)
                .buttonStyle(.glassProminent).buttonBorderShape(.circle)
                .tint(Tokens.brand500)
                .disabled(!enabled))
        case let .done(label, action):
            return AnyView(Button(label) { (action ?? dismiss)() }
                .font(AppFont.main(14, .semibold))
                .foregroundStyle(Tokens.brand600)
                .sheetGlass(glass, circle: false))
        case let .check(action):
            return AnyView(Button("Done", systemImage: "checkmark") { action() }
                .labelStyle(.iconOnly).tint(Tokens.text900).sheetGlass(glass))
        }
    }
}

private extension View {
    /// Toolbar buttons get their glass from the system; the self-drawn bar adds it.
    @ViewBuilder
    func sheetGlass(_ on: Bool, circle: Bool = true) -> some View {
        if on {
            if circle { buttonStyle(.glass).buttonBorderShape(.circle).controlSize(.large) } else { buttonStyle(.glass).controlSize(.large) }
        } else {
            self
        }
    }
}
