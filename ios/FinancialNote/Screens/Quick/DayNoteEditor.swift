import SwiftData
import SwiftUI

/// Notes of the day: the day's free-form lines, as written. Saving keeps the note and then
/// shows "Here's what I got" for those lines, so they can be saved as entries too.
struct DayNoteEditor: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var notes: [DayNote]

    @State private var text = ""
    @State private var date = Day.today()
    @State private var picking = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Space.s12) {
                Button {
                    picking = true
                } label: {
                    Text(Day.long(date))
                        .font(AppFont.main(14, .medium))
                        .foregroundStyle(Tokens.text900)
                        .padding(.horizontal, Space.s8)
                        .padding(.vertical, Space.s4)
                        .background(Tokens.brand100, in: .rect(cornerRadius: Corner.c4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("For \(Day.long(date)). Change day")

                TextEditor(text: $text)
                    .font(AppFont.main(16))
                    .focused($focused)
                    .scrollContentBackground(.hidden)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("One line per thing:\ncơm tấm 35k\ncafe 40k · cash")
                                .font(AppFont.main(16))
                                .foregroundStyle(Tokens.grey300)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                Text("Saved on this phone only.")
                    .font(AppFont.main(12))
                    .foregroundStyle(Tokens.grey400)
            }
            .padding(Space.s20)
            .background(Tokens.bg1)
            .navigationTitle("Notes of the day")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark", action: save)
                        .disabled(lines.isEmpty)
                }
            }
            .sheet(isPresented: $picking) { DayPickerSheet(day: $date) }
            .onChange(of: date) { _, d in text = existing(d) }
        }
        .onAppear {
            date = app.day
            text = existing(app.day)
            focused = true
        }
    }

    private var lines: [String] {
        text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private func existing(_ d: String) -> String {
        notes.first { $0.date == d }?.lines.joined(separator: "\n") ?? ""
    }

    private func save() {
        LocalStore(context: context).saveDayNote(date: date, lines: lines)
        let joined = lines.joined(separator: "\n")
        dismiss()
        app.day = date
        app.openQuickNote(date: date, text: joined, drafts: NoteParser.parse(joined, day: date))
    }
}
