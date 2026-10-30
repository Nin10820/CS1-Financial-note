import SwiftData
import SwiftUI

/// The AI tab — Figma "Talk With AI" (1073:18676): the greeting, then write what you spent in
/// your own words. The reader runs on the phone and nothing is sent anywhere; lines are only
/// saved after Confirm. ≡ slides Chat History in from the left (1077:22810).
struct AssistantView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @Query private var profiles: [Profile]

    @State private var turns: [Turn] = []
    @State private var text = ""
    @State private var date = Day.today()
    @State private var picking = false
    @State private var fixing: FixTarget?
    @State private var later: String?
    @State private var drawer = false
    @State private var path: [ChatHistoryView.Note] = []
    @FocusState private var focused: Bool

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
        /// Set when the note came from Notes of the day: shown as a note card.
        var attached: (date: String, lines: [String])?
        /// A plain message instead of a note ("… comes later").
        var notice: String?
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.s20) {
                        if turns.isEmpty {
                            EmptyDay(name: profiles.first?.name ?? "Nin", nothingNote: nil) { idea in
                                switch idea {
                                case .write: focused = true
                                case .due: app.tab = .due
                                case .decisions:
                                    later = "Talking decisions through comes later. For now I record what you spend and receive, and keep track of bills."
                                }
                            }
                            .padding(.top, Space.s32)
                        }
                        ForEach($turns) { $turn in
                            TurnView(turn: $turn, hidden: app.hidden, today: app.today,
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
            .background(alignment: .top) {
                LinearGradient(colors: [Tokens.brand100, Tokens.bg3], startPoint: .top, endPoint: .bottom)
                    .frame(height: 240).ignoresSafeArea().accessibilityHidden(true)
            }
            .background(Tokens.bg3)
            .safeAreaInset(edge: .bottom) { bottom }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        focused = false
                        animate { drawer = true }
                    } label: { Image(systemName: "line.3.horizontal") }
                        .accessibilityLabel("Chat history")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { app.tab = .today }
                }
            }
            .navigationDestination(for: ChatHistoryView.Note.self) { note in
                NoteDetailView(note: note, onView: view)
            }
        }
        .overlay { if drawer { historyDrawer } }
        .sheet(isPresented: $picking) { DayPickerSheet(day: $date) }
        .sheet(item: $fixing) { target in DraftFixSheet(draft: draftBinding(target)) }
        .alert("Comes later", isPresented: Binding(get: { later != nil }, set: { if !$0 { later = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(later ?? "")
        }
        .onAppear(perform: takeSeed)
        .onChange(of: turns.isEmpty, initial: true) { _, empty in app.aiChatting = !empty }
        .onChange(of: app.assistant?.id) { _, _ in takeSeed() }
    }

    // MARK: - Bottom: actions and composer

    private var bottom: some View {
        VStack(alignment: .trailing, spacing: Space.s12) {
            if turns.isEmpty && !app.actionsOpen {
                GlassEffectContainer(spacing: Space.s12) {
                    VStack(alignment: .trailing, spacing: Space.s12) {
                        ActionPill(title: "Talk With AI", systemImage: "sparkles") { focused = true }
                        ActionPill(title: "Template", systemImage: "doc.text") { app.templateOpen = true }
                        ActionPill(title: "Scan", systemImage: "qrcode.viewfinder") { app.scanOpen = true }
                    }
                }
            }
            composer
        }
        .padding(.horizontal, Space.s16)
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
                    Button("Notes of the day", systemImage: "note.text") {
                        app.day = date
                        app.dayNoteOpen = true
                    }
                    Button("Template", systemImage: "doc.text") { app.templateOpen = true }
                    Button("Scan", systemImage: "qrcode.viewfinder") { app.scanOpen = true }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Tokens.text700)
                        .frame(width: 36, height: 36)
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
                    .frame(height: 36)
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
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .accessibilityLabel("Voice note")
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(canSend ? Tokens.text900 : Tokens.grey300, in: .circle)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel("Send")
            }
        }
        .padding(Space.s16)
        .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c20))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 2)
    }

    // MARK: - Chat History drawer

    private var historyDrawer: some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(0.16)
                .ignoresSafeArea()
                .onTapGesture { animate { drawer = false } }
                .accessibilityLabel("Close chat history")
                .accessibilityAddTraits(.isButton)
            NavigationStack {
                ChatHistoryView(
                    onNew: {
                        turns = []
                        text = ""
                        animate { drawer = false }
                        focused = true
                    },
                    onView: view,
                    onOpen: { note in
                        animate { drawer = false }
                        path = [note]
                    })
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { animate { drawer = false } } label: { Image(systemName: "line.3.horizontal") }
                            .accessibilityLabel("Close chat history")
                    }
                }
            }
            .frame(width: 310)
            .background(Tokens.bg1)
            .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: Corner.c20, topTrailingRadius: Corner.c20))
            .ignoresSafeArea(edges: .vertical)
            .transition(UIAccessibility.isReduceMotionEnabled ? .opacity : .move(edge: .leading))
        }
        .accessibilityAddTraits(.isModal)
    }

    // MARK: - Logic

    private var canSend: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Takes what Today, Notes of the day or the + menu asked the tab to start with.
    private func takeSeed() {
        guard let seed = app.assistant else { return }
        app.assistant = nil
        date = seed.date
        if let notice = seed.notice {
            turns.append(Turn(text: "", drafts: [], notice: notice))
        } else if let lines = seed.noteLines, !lines.isEmpty {
            dropReviews()
            let joined = lines.joined(separator: "\n")
            animate {
                turns.append(Turn(text: joined, drafts: NoteParser.parse(joined, day: seed.date),
                                  attached: (seed.date, lines)))
            }
        } else {
            focused = true
        }
    }

    /// An unfinished review is dropped when a new note comes in; nothing from it was saved.
    private func dropReviews() {
        for i in turns.indices where turns[i].status == .review && turns[i].notice == nil { turns[i].status = .discarded }
    }

    private func send() {
        let note = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { return }
        text = ""
        dropReviews()
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
        path = []
        drawer = false
        app.tab = .today
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

/// One note and the reply (Figma 1077:22408, 1086:27021).
private struct TurnView: View {
    @Binding var turn: AssistantView.Turn
    var hidden: Bool
    var today: String
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
                mine
                reply
            }
        }
    }

    /// What the user sent: a note card for Notes of the day, otherwise a bubble.
    @ViewBuilder
    private var mine: some View {
        VStack(alignment: .trailing, spacing: Space.s8) {
            if let a = turn.attached {
                NoteCard(title: "Note - \(Day.long(a.date))", lines: a.lines)
                    .frame(maxWidth: 220)
                    .padding(Space.s8)
                    .background(Tokens.bg4, in: .rect(cornerRadius: Corner.c16))
                bubble(a.date == today ? "My note today" : "My note for \(Day.short(a.date))")
            } else {
                bubble(turn.text)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func bubble(_ text: String) -> some View {
        Text(text)
            .font(AppFont.main(15))
            .foregroundStyle(Tokens.text900)
            .padding(.horizontal, Space.s12)
            .padding(.vertical, Space.s8)
            .background(Tokens.bg4, in: .rect(cornerRadius: Corner.c12))
            .padding(.leading, Space.s32)
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
                    Spacer()
                    replyButton("Undo", filled: false, action: onUndo)
                    replyButton("View list", filled: true, action: onView)
                }
            }
        case .review:
            if drafts.isEmpty {
                bot("I couldn't find anything to save. Try a line with an amount, like “coffee 24k”.")
            } else {
                let missing = drafts.filter { $0.amount == nil }.count
                VStack(alignment: .leading, spacing: Space.s8) {
                    VStack(alignment: .leading, spacing: 2) {
                        bot("Here's what I got — nothing is saved until you confirm:")
                        ForEach(Array(drafts.enumerated()), id: \.offset) { _, d in
                            Text("•  \(d.title): \(d.amount.map { hidden ? "•••" : "\(Money.format($0))đ" } ?? "no amount")")
                                .font(AppFont.main(14))
                                .foregroundStyle(Tokens.text700)
                        }
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(drafts.enumerated()), id: \.offset) { i, d in
                            if i > 0 { Divider().overlay(Tokens.bd0) }
                            Button { onFix(i) } label: { DraftRow(draft: d, hidden: hidden) }
                                .buttonStyle(.plain)
                                .accessibilityHint("Fix this line")
                        }
                    }
                    .padding(.horizontal, Space.s12)
                    .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c14))
                    .overlay(RoundedRectangle(cornerRadius: Corner.c14).strokeBorder(Tokens.secondary300))
                    HStack(spacing: Space.s8) {
                        if missing > 0 {
                            Text("\(missing) \(missing == 1 ? "line needs" : "lines need") an amount")
                                .font(AppFont.main(12))
                                .foregroundStyle(Tokens.grey400)
                        }
                        Spacer()
                        replyButton("Discard", filled: false, action: onDiscard)
                        replyButton("Confirm", filled: true, action: onConfirm)
                            .disabled(missing > 0)
                            .opacity(missing > 0 ? 0.5 : 1)
                    }
                }
            }
        }
    }

    private func replyButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.main(14, .semibold))
                .foregroundStyle(filled ? .white : Tokens.text900)
                .padding(.horizontal, Space.s16)
                .frame(minHeight: 36)
                .background(filled ? Tokens.action : Tokens.bgWhite, in: .capsule)
                .overlay(Capsule().strokeBorder(filled ? .clear : Tokens.bd1))
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }

    private func bot(_ text: String) -> some View {
        Text(text)
            .font(AppFont.main(15))
            .foregroundStyle(Tokens.text700)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A line read from a note: name, category, amount (or "Add amount"), and a pencil to fix it.
private struct DraftRow: View {
    var draft: Draft
    var hidden: Bool

    var body: some View {
        HStack(spacing: Space.s12) {
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
            Image(systemName: "pencil")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Tokens.text700)
                .accessibilityHidden(true)
        }
        .padding(.vertical, Space.s12)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
