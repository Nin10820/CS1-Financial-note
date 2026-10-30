import SwiftData
import SwiftUI

/// Chat History (Figma 994:7938): every note written, newest first, grouped by day.
/// Opening one shows what it saved, with a way to remove it or see it on Today.
struct ChatHistoryView: View {
    var onNew: () -> Void
    var onView: (String) -> Void
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]

    struct Note: Identifiable, Hashable {
        var id: String
        var date: String
        var source: String
        var count: Int
        var spent: Int
    }

    /// One row per note the user wrote (bill check-offs are left out — they weren't written).
    static func notes(_ entries: [Entry]) -> [Note] {
        var order: [String] = []
        var byNote: [String: [Entry]] = [:]
        for e in entries where !e.noteId.hasPrefix("bill-") {
            if byNote[e.noteId] == nil { order.append(e.noteId) }
            byNote[e.noteId, default: []].append(e)
        }
        return order.compactMap { id in
            guard let list = byNote[id], let first = list.first else { return nil }
            return Note(id: id, date: first.date, source: first.source.isEmpty ? first.title : first.source, count: list.count,
                        spent: list.filter { $0.flow == .out }.reduce(0) { $0 + $1.amount })
        }
    }

    /// "WEDNESDAY, 5 AUG"
    static func heading(_ iso: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEEE, d MMM"
        return f.string(from: Day.date(iso)).uppercased()
    }

    var body: some View {
        let notes = Self.notes(entries)
        let days = Array(Dictionary(grouping: notes, by: \.date).keys).sorted(by: >)
        List {
            if notes.isEmpty {
                Text("Notes you save will show up here.")
                    .font(AppFont.main(14))
                    .foregroundStyle(Tokens.grey400)
            }
            ForEach(days, id: \.self) { day in
                Section {
                    ForEach(notes.filter { $0.date == day }) { note in
                        NavigationLink {
                            NoteDetailView(note: note, onView: onView)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(note.source)
                                    .font(AppFont.main(15, .semibold))
                                    .foregroundStyle(Tokens.text900)
                                    .lineLimit(2)
                                Text("\(note.count) \(note.count == 1 ? "item" : "items")")
                                    .font(AppFont.main(12))
                                    .foregroundStyle(Tokens.grey400)
                            }
                        }
                    }
                } header: {
                    Text(Self.heading(day))
                        .font(AppFont.main(11, .semibold, relativeTo: .caption))
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Chat History")
        .toolbarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onNew) { Image(systemName: "plus") }
                    .accessibilityLabel("New note")
            }
        }
    }
}

/// One saved note: what was written and the lines it became.
private struct NoteDetailView: View {
    var note: ChatHistoryView.Note
    var onView: (String) -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var app
    @Query private var entries: [Entry]
    @State private var confirmDelete = false

    var body: some View {
        let lines = entries.filter { $0.noteId == note.id }.sorted { $0.createdAt < $1.createdAt }
        List {
            Section {
                Text(note.source)
                    .font(AppFont.main(15))
                    .padding(.vertical, Space.s4)
            } header: {
                Text("You wrote · \(Day.long(note.date))")
            }
            Section("Saved as") {
                ForEach(lines) { e in EntryRow(entry: e, hidden: app.hidden) }
            }
            Section {
                Button("View on Today", systemImage: "list.bullet") { onView(note.date) }
                Button("Remove this note", systemImage: "trash", role: .destructive) { confirmDelete = true }
            }
        }
        .font(AppFont.main(16))
        .navigationTitle(Day.short(note.date))
        .toolbarTitleDisplayMode(.inline)
        .confirmationDialog("Remove the \(lines.count) \(lines.count == 1 ? "line" : "lines") from this note?",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Yes, remove", role: .destructive) {
                LocalStore(context: context).removeNote(note.id)
                dismiss()
            }
        }
    }
}
