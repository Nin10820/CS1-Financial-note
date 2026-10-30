import SwiftData
import SwiftUI

/// Assistant — Figma High Fi 2 (994:6222, 984:36122): write what you spent in your own words,
/// read it back as lines, fix any line, then confirm. The reader runs on the phone; nothing is
/// sent anywhere. The ≡ button opens Chat History (994:7938).
struct AssistantSheet: View {
    var seed: AssistantSeed
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @Query private var profiles: [Profile]

    @State private var turns: [Turn] = []
    @State private var text = ""
    @State private var date = Day.today()
    @State private var picking = false
    @State private var fixing: FixTarget?
    @State private var later: String?
    @State private var path: [Route] = []
    @State private var started = false
    @FocusState private var focused: Bool

    enum Route: Hashable { case history }

    struct FixTarget: Identifiable {
        var turn: UUID
        var index: Int
        var id: String { "\(turn)-\(index)" }
    }

    struct Turn: Identifiable {
        enum Status { case review, saved, discarded }
        let id = UUID()
        var text: String
        var drafts: [Draft]
        var status: Status = .review
        var noteId: String?
        /// Set when the note came from Notes of the day.
        var attachedLines: Int?
        /// A plain message instead of a note ("… comes later").
        var notice: String?
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.s16) {
                        if turns.isEmpty { hello }
                        ForEach($turns) { $turn in
                            TurnView(turn: $turn, hidden: app.hidden,
                                     onFix: { i in fixing = FixTarget(turn: turn.id, index: i) },
                                     onConfirm: { confirm(turn.id) },
                                     onDiscard: { set(turn.id, .discarded) },
                                     onUndo: { undo(turn.id) },
                                     onView: { view(turn.drafts.first?.date ?? date) })
                                .id(turn.id)
                        }
                    }
                    .padding(Space.s20)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: turns.count) { _, _ in
                    if let last = turns.last { animate { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }
            .background(Tokens.bg1)
            .safeAreaInset(edge: .bottom) { bottom }
            .navigationTitle("Assistant")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { path.append(.history) } label: { Image(systemName: "line.3.horizontal") }
                        .accessibilityLabel("Chat history")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .navigationDestination(for: Route.self) { _ in
                ChatHistoryView(
                    onNew: {
                        turns = []
                        text = ""
                        path = []
                        focused = true
                    },
                    onView: view)
            }
        }
        .presentationDetents([.large])
        .sheet(isPresented: $picking) { DayPickerSheet(day: $date) }
        .sheet(item: $fixing) { target in DraftFixSheet(draft: draftBinding(target)) }
        .alert("Comes later", isPresented: Binding(get: { later != nil }, set: { if !$0 { later = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(later ?? "")
        }
        .onAppear(perform: start)
    }

    // MARK: - Parts

    private var hello: some View {
        VStack(spacing: Space.s12) {
            LogoMark(size: 56)
            Text("Empty your head here\nI'll note for you")
                .font(AppFont.main(18, .semibold, relativeTo: .title3))
                .foregroundStyle(Tokens.text900)
                .multilineTextAlignment(.center)
            Text("\(Day.greeting()), \(profiles.first?.name ?? "Nin"). What did you spend today?")
                .font(AppFont.main(14))
                .foregroundStyle(Tokens.grey400)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.s32)
    }

    private var bottom: some View {
        VStack(alignment: .trailing, spacing: Space.s8) {
            if turns.isEmpty {
                Menu {
                    ForEach(templates, id: \.self) { line in
                        Button(line) { add(line) }
                    }
                    Divider()
                    Button("Notes of the day", systemImage: "note.text") { openDayNote() }
                } label: {
                    pill("Template", systemImage: "doc.text")
                }
                .accessibilityHint("Adds a line you often write")
                Button {
                    later = "Scanning a receipt or QR code comes later. You can type what you spent instead — one line is enough."
                } label: {
                    pill("Scan QR code", systemImage: "qrcode.viewfinder")
                }
                .buttonStyle(.plain)
            }
            composer
        }
        .padding(.horizontal, Space.s12)
        .padding(.bottom, Space.s8)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            TextField("e.g. coffee 24k, breakfast 35k…", text: $text, axis: .vertical)
                .font(AppFont.main(15))
                .lineLimit(1...6)
                .focused($focused)
                .submitLabel(.send)
                .accessibilityLabel("Write what you spent")
                .onChange(of: text) { _, new in
                    // Return sends; a pasted list with new lines is kept as it is.
                    if new.hasSuffix("\n") {
                        text = String(new.dropLast())
                        send()
                    }
                }
            HStack(spacing: Space.s8) {
                Menu {
                    Button("Notes of the day", systemImage: "note.text") { openDayNote() }
                    Button("Photo of a receipt — comes later", systemImage: "photo") {}
                        .disabled(true)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Tokens.text700)
                        .frame(width: 40, height: 40)
                        .background(Tokens.bg4, in: .circle)
                }
                .accessibilityLabel("More")
                Button { picking = true } label: {
                    HStack(spacing: Space.s4) {
                        Image(systemName: "calendar")
                        Text(date == app.today ? "Today" : Day.short(date))
                    }
                    .font(AppFont.main(13, .medium))
                    .foregroundStyle(Tokens.text900)
                    .padding(.horizontal, Space.s12)
                    .frame(height: 40)
                    .background(Tokens.bgWhite, in: .capsule)
                    .overlay(Capsule().strokeBorder(Tokens.bd1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("For \(Day.long(date)). Change day")
                Spacer()
                Button {
                    later = "Voice notes come later. You can use the microphone on the keyboard to dictate."
                } label: {
                    Image(systemName: "mic")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Tokens.text700)
                        .frame(width: 40, height: 40)
                        .background(Tokens.bg4, in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Voice note")
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .tint(Tokens.action)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Send")
            }
        }
        .padding(Space.s16)
        .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c20))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 2)
    }

    private func pill(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(AppFont.main(14, .semibold))
            .foregroundStyle(Tokens.brand700)
            .padding(.horizontal, Space.s16)
            .padding(.vertical, Space.s12)
            .background(Tokens.bgWhite, in: .capsule)
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    // MARK: - Logic

    /// The user's own recent lines, so the common ones are one tap away.
    private var templates: [String] {
        var seen: [String] = []
        for e in entries where e.flow == .out && !e.noteId.hasPrefix("bill-") {
            let line = "\(e.title.lowercased(with: Locale(identifier: "vi"))) \(Int((Double(e.amount) / 1000).rounded()))k"
            if !seen.contains(line) { seen.append(line) }
            if seen.count == 5 { break }
        }
        return seen.isEmpty ? ["đậu hũ 15k", "thịt xay 50k", "cafe 25k"] : seen
    }

    private func start() {
        guard !started else { return }
        started = true
        date = seed.date
        if let notice = seed.notice {
            turns = [Turn(text: "", drafts: [], notice: notice)]
        } else if let lines = seed.noteLines, !lines.isEmpty {
            let joined = lines.joined(separator: "\n")
            turns = [Turn(text: joined, drafts: NoteParser.parse(joined, day: seed.date), attachedLines: lines.count)]
        } else {
            focused = true
        }
    }

    private func add(_ line: String) {
        let t = text.trimmingCharacters(in: .whitespaces)
        text = t.isEmpty ? line : "\(t.hasSuffix(",") ? String(t.dropLast()) : t), \(line)"
        focused = true
    }

    private func send() {
        let note = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { return }
        text = ""
        // An unfinished review is dropped when a new note is sent; nothing from it was saved.
        for i in turns.indices where turns[i].status == .review && turns[i].notice == nil { turns[i].status = .discarded }
        animate { turns.append(Turn(text: note, drafts: NoteParser.parse(note, day: date))) }
    }

    private func set(_ id: UUID, _ status: Turn.Status, noteId: String? = nil) {
        guard let i = turns.firstIndex(where: { $0.id == id }) else { return }
        animate {
            turns[i].status = status
            if let noteId { turns[i].noteId = noteId }
        }
    }

    private func confirm(_ id: UUID) {
        guard let turn = turns.first(where: { $0.id == id }), !turn.drafts.isEmpty,
              !turn.drafts.contains(where: { $0.amount == nil }) else { return }
        let noteId = UUID().uuidString
        let now = Date.now
        let list = turn.drafts.enumerated().map { i, d -> Entry in
            let e = Entry(date: d.date, title: d.title, amount: d.amount ?? 0, flow: d.flow, category: d.category,
                          noteId: noteId, source: turn.text, createdAt: now.addingTimeInterval(Double(i) / 1000))
            e.paidFrom = d.paidFrom
            return e
        }
        LocalStore(context: context).addEntries(list)
        set(id, .saved, noteId: noteId)
    }

    private func undo(_ id: UUID) {
        guard let noteId = turns.first(where: { $0.id == id })?.noteId else { return }
        LocalStore(context: context).removeNote(noteId)
        set(id, .discarded)
    }

    private func view(_ day: String) {
        app.day = day
        app.range = .day
        app.tab = .today
        dismiss()
    }

    private func openDayNote() {
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            app.dayNoteOpen = true
        }
    }

    private func draftBinding(_ t: FixTarget) -> Binding<Draft> {
        Binding(
            get: {
                guard let i = turns.firstIndex(where: { $0.id == t.turn }), turns[i].drafts.indices.contains(t.index) else {
                    return Draft(title: "", amount: nil, flow: .out, category: .other, date: date)
                }
                return turns[i].drafts[t.index]
            },
            set: { new in
                guard let i = turns.firstIndex(where: { $0.id == t.turn }), turns[i].drafts.indices.contains(t.index) else { return }
                turns[i].drafts[t.index] = new
            })
    }
}

/// One note and the Assistant's answer.
private struct TurnView: View {
    @Binding var turn: AssistantSheet.Turn
    var hidden: Bool
    var onFix: (Int) -> Void
    var onConfirm: () -> Void
    var onDiscard: () -> Void
    var onUndo: () -> Void
    var onView: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            if let notice = turn.notice {
                bot(notice)
            } else {
                userBubble
                reply
            }
        }
    }

    private var userBubble: some View {
        HStack {
            Spacer(minLength: Space.s32)
            VStack(alignment: .leading, spacing: Space.s4) {
                if let n = turn.attachedLines {
                    Label("Notes of the day · \(n) \(n == 1 ? "line" : "lines")", systemImage: "note.text")
                        .font(AppFont.main(12, .semibold))
                        .foregroundStyle(Tokens.brand800)
                }
                Text(turn.text)
                    .font(AppFont.main(15))
                    .foregroundStyle(Tokens.text900)
            }
            .padding(.horizontal, Space.s16)
            .padding(.vertical, Space.s12)
            .background(Tokens.brand200, in: .rect(cornerRadius: Corner.c16))
        }
    }

    @ViewBuilder
    private var reply: some View {
        let drafts = turn.drafts
        switch turn.status {
        case .discarded:
            bot("Nothing from this note was saved.").opacity(0.7)
        case .saved:
            let total = drafts.filter { $0.flow == .out }.reduce(0) { $0 + ($1.amount ?? 0) }
            VStack(alignment: .leading, spacing: Space.s8) {
                bot("Saved \(drafts.count) \(drafts.count == 1 ? "item" : "items") to \(Day.short(drafts.first?.date ?? ""))"
                    + (total > 0 && !hidden ? " · spent \(Money.format(total)) đ." : "."))
                HStack(spacing: Space.s8) {
                    Button("Undo", action: onUndo).buttonStyle(.glass)
                    Button("View list", action: onView).buttonStyle(.glassProminent).tint(Tokens.action)
                }
                .font(AppFont.main(14, .semibold))
            }
        case .review:
            if drafts.isEmpty {
                bot("I couldn't find anything to save. Try a line with an amount, like “coffee 24k”.")
            } else {
                let missing = drafts.filter { $0.amount == nil }.count
                VStack(alignment: .leading, spacing: Space.s8) {
                    bot("Here's what I got — nothing is saved until you confirm.")
                    VStack(spacing: 0) {
                        ForEach(Array(drafts.enumerated()), id: \.offset) { i, d in
                            if i > 0 { Divider().overlay(Tokens.bd0) }
                            Button { onFix(i) } label: { DraftRow(index: i, draft: d, hidden: hidden) }
                                .buttonStyle(.plain)
                                .accessibilityHint("Fix this line")
                        }
                    }
                    .padding(.horizontal, Space.s12)
                    .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c16))
                    .overlay(RoundedRectangle(cornerRadius: Corner.c16).strokeBorder(Tokens.bd1))
                    if missing > 0 {
                        Text("\(missing) \(missing == 1 ? "line needs" : "lines need") an amount — tap it to fix")
                            .font(AppFont.main(12))
                            .foregroundStyle(Tokens.grey400)
                    }
                    HStack(spacing: Space.s8) {
                        Button("Discard", action: onDiscard).buttonStyle(.glass)
                        Button("Confirm", action: onConfirm)
                            .buttonStyle(.glassProminent)
                            .tint(Tokens.action)
                            .disabled(missing > 0)
                    }
                    .font(AppFont.main(14, .semibold))
                }
            }
        }
    }

    private func bot(_ text: String) -> some View {
        Text(text)
            .font(AppFont.main(15))
            .foregroundStyle(Tokens.text700)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A line read from a note: number, name, category, amount (or "Add amount").
private struct DraftRow: View {
    var index: Int
    var draft: Draft
    var hidden: Bool

    var body: some View {
        HStack(spacing: Space.s12) {
            Text("\(index + 1)")
                .font(AppFont.main(13, .medium))
                .foregroundStyle(Tokens.text700)
                .frame(width: 28, height: 28)
                .background(Tokens.bg4, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(draft.title).font(AppFont.main(14, .medium)).foregroundStyle(Tokens.text900)
                HStack(spacing: Space.s4) {
                    CategoryLabel(category: draft.category)
                    if draft.assumedThousands, let a = draft.amount {
                        Text("· read as \(Money.format(a))").font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                    }
                    if let p = draft.paidFrom {
                        Text("· \(p)").font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                    }
                }
            }
            Spacer(minLength: Space.s8)
            if let amount = draft.amount {
                AmountText(value: amount, sign: draft.flow == .out ? "-" : "", hidden: hidden)
            } else {
                Text("Add amount").font(AppFont.main(14, .semibold)).foregroundStyle(Tokens.brand700)
            }
        }
        .padding(.vertical, Space.s12)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
