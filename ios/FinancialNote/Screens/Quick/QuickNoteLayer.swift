import SwiftData
import SwiftUI

/// Quick note — Figma High Fi 2 › Quick note (943:24983) and "Here's what I got" (943:25079).
/// A card that floats just above the keyboard: "## n Submit your note expense", the day, the note,
/// two quick chips and send. Sending turns it into the result; the green check saves.
/// Everything is read on the phone by the local note reader — nothing is sent anywhere.
struct QuickNoteLayer: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]

    @State private var date = Day.today()
    @State private var text = ""
    @State private var drafts: [Draft]?
    @State private var picking = false
    @State private var fixing: FixTarget?
    @FocusState private var focused: Bool

    struct FixTarget: Identifiable { let id: Int }

    private static let defaultChips = ["đậu hũ 15k", "thịt xay 50k"]

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .onTapGesture(perform: close)
                .accessibilityLabel("Close quick note")
                .accessibilityAddTraits(.isButton)

            Group {
                if let drafts {
                    result(drafts)
                } else {
                    composer
                }
            }
            .padding(Space.s16)
            .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c20))
            .shadow(color: .black.opacity(0.12), radius: 16, y: 4)
            .padding(.horizontal, Space.s12)
            .padding(.bottom, Space.s12)
            .transition(.sheetLike)
        }
        .onAppear(perform: load)
        .sheet(isPresented: $picking) { DayPickerSheet(day: $date) }
        .sheet(item: $fixing) { target in
            DraftFixSheet(draft: binding(for: target.id))
        }
        .accessibilityAddTraits(.isModal)
    }

    // MARK: - Writing

    private var composer: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            HStack(spacing: Space.s8) {
                Text("## \(noteNumber)")
                    .font(AppFont.main(16, .semibold))
                    .foregroundStyle(Tokens.text900)
                Text("Submit your note expense")
                    .font(AppFont.main(16, .medium))
                    .foregroundStyle(Tokens.text900)
                Spacer(minLength: 0)
                Button("Close", systemImage: "xmark", action: close)
                    .labelStyle(.iconOnly)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.grey400)
            }
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

            TextField("e.g. coffee 24k, breakfast 35k…", text: $text, axis: .vertical)
                .font(AppFont.main(14))
                .foregroundStyle(Tokens.text700)
                .lineLimit(2...6)
                .focused($focused)
                .submitLabel(.send)
                .accessibilityLabel("Write what you spent")
                .onChange(of: text) { _, new in
                    // Return sends, like the web app; a pasted list with new lines is kept as is.
                    if new.hasSuffix("\n") {
                        text = String(new.dropLast())
                        send()
                    }
                }

            Divider().overlay(Tokens.bd0)

            HStack(spacing: Space.s8) {
                ScrollView(.horizontal) {
                    HStack(spacing: Space.s8) {
                        ForEach(chips, id: \.self) { chip in
                            Button(chip) { add(chip) }
                                .font(AppFont.main(12, .medium))
                                .foregroundStyle(Tokens.text700)
                                .padding(.horizontal, Space.s8)
                                .padding(.vertical, Space.s6)
                                .overlay(RoundedRectangle(cornerRadius: Corner.c6).strokeBorder(Tokens.bd1))
                                .buttonStyle(.plain)
                                .accessibilityHint("Adds it to the note")
                        }
                    }
                }
                .scrollIndicators(.hidden)
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(canSend ? Tokens.text900 : Tokens.grey300, in: .circle)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel("Send")
            }
        }
    }

    // MARK: - "Here's what I got"

    private func result(_ drafts: [Draft]) -> some View {
        let missing = drafts.contains { $0.amount == nil }
        return VStack(alignment: .leading, spacing: Space.s12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(drafts.count) \(drafts.count == 1 ? "item" : "items")")
                        .font(AppFont.main(13))
                        .foregroundStyle(Tokens.grey400)
                    Text("Here's what I got")
                        .font(AppFont.main(20, .bold, relativeTo: .title3))
                        .foregroundStyle(Tokens.text900)
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer()
                Button(action: save) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .bold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .tint(Tokens.action)
                .disabled(missing || drafts.isEmpty)
                .accessibilityLabel("Save \(drafts.count) \(drafts.count == 1 ? "item" : "items")")
            }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(drafts.enumerated()), id: \.offset) { i, d in
                        Button { fixing = FixTarget(id: i) } label: { row(i, d) }
                            .buttonStyle(.plain)
                            .accessibilityHint("Fix this line")
                        if i < drafts.count - 1 { Divider().overlay(Tokens.bd0) }
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: 340)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Space.s12) {
                Button {
                    withAnimation(reduceMotion ? nil : .snappy) { self.drafts = nil }
                    focused = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Tokens.brand600)
                        .frame(width: 36, height: 36)
                        .background(Tokens.brand50, in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Change the note")
                Text(missing ? "One line has no amount. Tap it to fix" : "Not quite? Tap a row to fix")
                    .font(AppFont.main(14))
                    .foregroundStyle(Tokens.grey400)
            }
        }
    }

    private func row(_ i: Int, _ d: Draft) -> some View {
        HStack(spacing: Space.s12) {
            Text("\(i + 1)")
                .font(AppFont.main(14, .medium))
                .foregroundStyle(Tokens.text700)
                .frame(width: 32, height: 32)
                .background(Tokens.bg4, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(d.title)
                    .font(AppFont.main(14, .medium))
                    .foregroundStyle(Tokens.text900)
                    .multilineTextAlignment(.leading)
                CategoryLabel(category: d.category)
            }
            Spacer(minLength: Space.s8)
            if let amount = d.amount {
                AmountText(value: amount, sign: d.flow == .out ? "-" : "")
            } else {
                Text("Add amount")
                    .font(AppFont.main(14, .semibold))
                    .foregroundStyle(Tokens.brand600)
            }
        }
        .padding(.vertical, Space.s8)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Logic

    /// Which note of the day this is: "## 3" when two were already written.
    private var noteNumber: Int {
        Set(entries.filter { $0.date == date }.map(\.noteId)).count + 1
    }

    /// The user's own two most recent lines, so the common ones are one tap away.
    private var chips: [String] {
        var seen: [String] = []
        for e in entries where e.flow == .out {
            let chip = "\(e.title.lowercased(with: Locale(identifier: "vi"))) \(Int((Double(e.amount) / 1000).rounded()))k"
            if !seen.contains(chip) { seen.append(chip) }
            if seen.count == 2 { break }
        }
        return seen.count == 2 ? seen : Self.defaultChips
    }

    private var canSend: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func load() {
        guard let q = app.quick else { return }
        date = q.date
        text = q.text
        drafts = q.drafts
        if drafts == nil { focused = true }
    }

    private func add(_ chip: String) {
        let t = text.trimmingCharacters(in: .whitespaces)
        text = t.isEmpty ? chip : "\(t.hasSuffix(",") ? String(t.dropLast()) : t), \(chip)"
        focused = true
    }

    private func send() {
        let note = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { return }
        focused = false
        withAnimation(reduceMotion ? nil : .snappy) { drafts = NoteParser.parse(note, day: date) }
    }

    private func save() {
        guard let drafts, !drafts.isEmpty, !drafts.contains(where: { $0.amount == nil }) else { return }
        let noteId = UUID().uuidString
        let now = Date.now
        let source = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let list = drafts.enumerated().map { i, d in
            Entry(date: d.date, title: d.title, amount: d.amount ?? 0, flow: d.flow, category: d.category,
                  noteId: noteId, source: source, createdAt: now.addingTimeInterval(Double(i) / 1000))
        }
        LocalStore(context: context).addEntries(list)
        app.day = drafts[0].date
        app.tab = .today
        close()
    }

    private func close() {
        focused = false
        withAnimation(reduceMotion ? nil : .snappy) { app.quick = nil }
    }

    private func binding(for i: Int) -> Binding<Draft> {
        Binding(
            get: { drafts?.indices.contains(i) == true ? drafts![i] : Draft(title: "", amount: nil, flow: .out, category: .other, date: date) },
            set: { if drafts?.indices.contains(i) == true { drafts![i] = $0 } })
    }
}

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
