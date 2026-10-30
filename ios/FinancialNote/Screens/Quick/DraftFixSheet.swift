import SwiftUI

/// Fixes one line before it is saved: name, amount, type, category, day.
struct DraftFixSheet: View {
    @Binding var draft: Draft
    @State private var edit = EntryDraft()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            EntryForm(draft: $edit)
                .navigationTitle("Fix this line")
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", systemImage: "checkmark") {
                            edit.apply(to: &draft)
                            dismiss()
                        }
                        .disabled(!edit.isValid)
                    }
                }
        }
        .onAppear { edit = EntryDraft(draft) }
    }
}
