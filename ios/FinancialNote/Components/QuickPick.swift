import SwiftUI

/// "Adding new [kind of] — tell us what you know:" (Figma Due 943:25329), shared by New bill
/// and New asset: Montserrat SemiBold 26, the chosen kind in a pill (grey until picked, then green).
struct AddingLead: View {
    var label: String
    var chosen: Bool

    var body: some View {
        FlowLayout(spacing: 6) {
            Text("Adding new").font(AppFont.main(26, .semibold, relativeTo: .title)).foregroundStyle(Tokens.text700)
            Text(label)
                .font(AppFont.main(24, .semibold, relativeTo: .title))
                .foregroundStyle(chosen ? Tokens.brand600 : Tokens.grey400)
                .padding(.horizontal, 10)
                .frame(minHeight: 36)
                .background(chosen ? Color(hex: 0x0D121C).opacity(0.04) : Tokens.bg4, in: .capsule)
            Text("— tell us what you know:").font(AppFont.main(26, .semibold, relativeTo: .title)).foregroundStyle(Tokens.text700)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One choice in the quick-pick card: title, one line under it, and an optional colour mark.
struct QuickPickOption<ID: Hashable>: Identifiable {
    var id: ID
    var title: String
    var hint: String
    var mark: Color? = nil
}

/// Step 1 card (Figma Due 943:25329): "Step 1 of 2 / What kind is this?", the choices, and
/// "Not quite? Say it your way" — one sentence instead of the form. The app's content card style:
/// solid white, radius 20 (Liquid Glass stays on controls).
struct QuickPickCard<ID: Hashable>: View {
    var step: String = "Step 1 of 2"
    var title: String
    var options: [QuickPickOption<ID>]
    var sayPlaceholder: String
    var onPick: (ID) -> Void
    var onSay: (String) -> Void

    @State private var saying = false
    @State private var sentence = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(step).font(AppFont.body(.medium)).foregroundStyle(Tokens.grey300)
                Text(title).font(AppFont.h6(.semibold)).foregroundStyle(Tokens.text700)
            }
            .padding(.horizontal, Space.s16)
            .padding(.top, Space.s16)
            .padding(.bottom, Space.s8)
            .frame(maxWidth: .infinity, alignment: .leading)
            Divider().overlay(Tokens.bd0)
            VStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.element.id) { i, o in
                    Button {
                        animate { onPick(o.id) }
                    } label: {
                        HStack(spacing: Space.s12) {
                            if let mark = o.mark {
                                RoundedRectangle(cornerRadius: 3).fill(mark).frame(width: 12, height: 12)
                                    .accessibilityHidden(true)
                            }
                            VStack(alignment: .leading, spacing: 0) {
                                Text(o.title).font(AppFont.bodyLarge(.semibold)).foregroundStyle(Tokens.text700)
                                Text(o.hint).font(AppFont.body()).foregroundStyle(Tokens.grey400)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, Space.s8)
                        .padding(.top, Space.s6)
                        .padding(.bottom, Space.s8)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    if i < options.count - 1 { Divider().overlay(Tokens.bd0) }
                }
            }
            .padding(.horizontal, Space.s12)
            .padding(.vertical, Space.s6)
            sayItYourWay
        }
        .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c20))
        .clipShape(.rect(cornerRadius: Corner.c20))
    }

    private var sayItYourWay: some View {
        HStack(spacing: Space.s8) {
            AppIcon(.pencil, size: 20)
                .foregroundStyle(Tokens.brand700)
                .frame(width: 40, height: 40)
                .background(Tokens.brand50, in: .circle)
            if saying {
                TextField(sayPlaceholder, text: $sentence, axis: .vertical)
                    .font(AppFont.body())
                    .lineLimit(1...3)
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .accessibilityLabel("Say it your way")
                SendButton(enabled: !sentence.trimmingCharacters(in: .whitespaces).isEmpty, action: send)
                    .accessibilityLabel("Fill it in")
            } else {
                Button {
                    animate { saying = true }
                    focused = true
                } label: {
                    Text("Not quite? Say it your way")
                        .font(AppFont.body(.medium))
                        .foregroundStyle(Tokens.grey400)
                        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                        .padding(.horizontal, Space.s8)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Space.s12)
        .padding(.top, Space.s8)
        .padding(.bottom, Space.s12)
        .overlay(alignment: .top) { Divider().overlay(Tokens.bd0) }
    }

    private func send() {
        let text = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        focused = false
        animate { onSay(text) }
    }
}
