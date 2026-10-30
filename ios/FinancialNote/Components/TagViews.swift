import SwiftData
import SwiftUI

/// Lays chips out in rows, wrapping to the next line when a row is full.
nonisolated struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > width {
                y += row + spacing
                x = 0
                row = 0
            }
            x += s.width + spacing
            row = max(row, s.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, width), height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX {
                y += row + spacing
                x = bounds.minX
                row = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            row = max(row, s.height)
        }
    }
}

/// One tag as a capsule chip (Figma __tag 1059:6327): outlined when off, filled when on.
struct TagChip: View {
    var name: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        let info = Tags.info(name)
        let fill = info.map { Color(light: $0.fill, dark: $0.fillDark) } ?? Tokens.brand100
        let ink: Color = selected ? (info?.whiteText == true ? .white : Tokens.text900) : Tokens.text700
        Button(action: action) {
            HStack(spacing: Space.s6) {
                Image(systemName: info?.symbol ?? "tag.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selected ? ink : Tokens.secondary500)
                Text(name)
                    .font(AppFont.main(13, .medium))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(ink)
            .padding(.horizontal, Space.s12)
            .padding(.vertical, Space.s8)
            .background(selected ? fill : Tokens.bgWhite, in: .capsule)
            .overlay(Capsule().strokeBorder(selected ? .clear : Tokens.bd1))
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(selected ? "Removes the tag" : "Adds the tag")
    }
}

/// "Select tag" (Figma 1052:6578): default tags, the user's own, and New Tag.
struct TagPickerSheet: View {
    @Binding var selected: [String]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [Profile]
    @State private var naming = false
    @State private var newName = ""

    var body: some View {
        let custom = profiles.first?.customTags ?? []
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s16) {
                    section("Default") {
                        FlowLayout {
                            ForEach(Tags.defaults, id: \.name) { t in
                                TagChip(name: t.name, selected: selected.contains(t.name)) { toggle(t.name) }
                            }
                        }
                    }
                    Divider().overlay(Tokens.bd1)
                    section("Custom") {
                        if custom.isEmpty {
                            Text("Tags you make show up here.")
                                .font(AppFont.main(13))
                                .foregroundStyle(Tokens.grey400)
                        }
                        FlowLayout {
                            ForEach(custom, id: \.self) { name in
                                TagChip(name: name, selected: selected.contains(name)) { toggle(name) }
                            }
                        }
                    }
                    Button {
                        newName = ""
                        naming = true
                    } label: {
                        Label("New Tag", systemImage: "plus")
                            .font(AppFont.main(14, .medium))
                            .foregroundStyle(Tokens.text900)
                            .padding(.horizontal, Space.s16)
                            .padding(.vertical, Space.s8)
                            .background(Tokens.bg4, in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
                .padding(Space.s20)
            }
            .background(Tokens.bg1)
            .navigationTitle("Select tag")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(AppFont.main(15, .semibold))
                        .foregroundStyle(Tokens.brand700)
                }
            }
            .alert("New tag", isPresented: $naming) {
                TextField("Name", text: $newName)
                Button("Add") { addTag() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("It stays on this phone.")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            Text(title.uppercased())
                .font(AppFont.main(12, .semibold, relativeTo: .caption))
                .tracking(0.4)
                .foregroundStyle(Tokens.grey400)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func toggle(_ name: String) {
        if let i = selected.firstIndex(of: name) { selected.remove(at: i) } else { selected.append(name) }
    }

    private func addTag() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let p = profiles.first else { return }
        if !p.customTags.contains(name) && Tags.info(name) == nil {
            p.customTags.append(name)
            try? context.save()
        }
        if !selected.contains(name) { selected.append(name) }
    }
}
