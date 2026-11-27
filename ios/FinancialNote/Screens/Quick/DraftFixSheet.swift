import SwiftUI

/// Fixes one line before it is saved: name, amount, type, category, day.
struct DraftFixSheet: View {
    @Binding var draft: Draft
    @State private var edit = EntryDraft()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            EntryForm(draft: $edit)
                .sheetHeader("Fix this line", trailing: .save(enabled: edit.isValid) { edit.apply(to: &draft); dismiss() })
        }
        .onAppear { edit = EntryDraft(draft) }
    }
}
