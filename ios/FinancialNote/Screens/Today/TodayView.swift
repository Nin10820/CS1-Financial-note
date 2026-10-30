import SwiftData
import SwiftUI

/// Today — Figma Today section (1077:22045): "Today" and profile top right, the picked day
/// large, the week strip, then the greeting (empty day) or the dark green card with
/// Recent / File underneath.
struct TodayView: View {
    @Environment(AppState.self) private var app
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @Query private var profiles: [Profile]

    @State private var pane: Pane = .recent
    @State private var picking = false
    @State private var openEntry: Entry?
    @State private var summaryOpen = false
    @State private var scrolled = false
    @State private var laterNotice: String?

    enum Pane: String, CaseIterable { case recent = "Recent", file = "File" }

    var body: some View {
        @Bindable var app = app
        let (from, to) = app.range.bounds(for: app.day)
        let list = entries.filter { $0.date >= from && $0.date <= to }
            .sorted { $0.date == $1.date ? $0.createdAt > $1.createdAt : $0.date > $1.date }

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s16) {
                    header
                    WeekStrip(day: $app.day, range: app.range, today: app.today, marked: Set(entries.map(\.date)))
                    if list.isEmpty && pane == .recent {
                        EmptyDay(name: profiles.first?.name ?? "Nin", nothingNote: nothingNote) { idea in
                            switch idea {
                            case .write: app.openAssistant()
                            case .due: app.tab = .due
                            case .decisions:
                                laterNotice = "Talking decisions through comes later. For now I record what you spend and receive, and keep track of bills."
                            }
                        }
                        .padding(.top, Space.s32)
                    } else {
                        if !list.isEmpty { card(list) }
                        listSection(list)
                    }
                }
                .padding(.horizontal, Space.s20)
                .padding(.bottom, Space.s24)
            }
            .modifier(MinimizesTabBar())
            .scrollBounceBehavior(.basedOnSize)
            .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top > 110 } action: { _, now in
                scrolled = now
            }
            .background(alignment: .top) { glow }
            .background(Tokens.bg3)
            .toolbar { toolbar }
            .navigationTitle(scrolled ? scrolledTitle : "")
            .toolbarTitleDisplayMode(.inline)
            .sheet(isPresented: $picking) { DayPickerSheet(day: $app.day) }
            .sheet(item: $openEntry) { EntrySheet(entry: $0) }
            .sheet(isPresented: $summaryOpen) { SummarySheet(title: summaryTitle, entries: list) }
            .alert("Comes later", isPresented: Binding(get: { laterNotice != nil }, set: { if !$0 { laterNotice = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(laterNotice ?? "")
            }
        }
    }

    // MARK: - Parts

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Today") {
                app.day = app.today
            }
            .font(AppFont.main(15, .semibold))
            .foregroundStyle(Tokens.text900)
            .accessibilityLabel("Go to today")
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                app.profileOpen = true
            } label: {
                Image(systemName: "person")
                    .foregroundStyle(Tokens.brand600)
            }
            .accessibilityLabel("Profile")
        }
    }

    /// "28• Oct 2026": the picked day large, a red dot when it is today. Tap to pick a day;
    /// touch and hold to switch between Daily, Weekly and Monthly.
    private var header: some View {
        @Bindable var app = app
        let (y, m, d) = Day.parts(app.day)
        return Menu {
            Button("Pick a day", systemImage: "calendar") { picking = true }
            Picker("Show", selection: $app.range) {
                ForEach(DayRange.allCases) { Text($0.label).tag($0) }
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: Space.s6) {
                HStack(alignment: .top, spacing: 2) {
                    Text(String(format: "%02d", d))
                        .font(AppFont.heading(40, .semibold, relativeTo: .largeTitle))
                        .foregroundStyle(Tokens.text900)
                        .monospacedDigit()
                    if app.day == app.today {
                        Circle().fill(Tokens.todayRed).frame(width: 8, height: 8).padding(.top, 8)
                    }
                }
                Text("\(Day.monthsShort[m - 1]) \(String(y))")
                    .font(AppFont.heading(24, .medium, relativeTo: .title))
                    .foregroundStyle(Tokens.grey400)
                if app.range != .day {
                    Text(app.range.label)
                        .font(AppFont.main(12, .semibold, relativeTo: .caption))
                        .foregroundStyle(Tokens.brand700)
                        .padding(.horizontal, Space.s8)
                        .padding(.vertical, 2)
                        .background(Tokens.brand100, in: .capsule)
                }
            }
            .contentShape(.rect)
        } primaryAction: {
            picking = true
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(Day.spoken(app.day)), \(String(y))\(app.day == app.today ? ", today" : ""). \(app.range.label)")
        .accessibilityHint("Picks a day. Touch and hold for Daily, Weekly or Monthly.")
    }

    private func card(_ list: [Entry]) -> some View {
        @Bindable var app = app
        let out = list.filter { $0.flow == .out }.reduce(0) { $0 + $1.amount }
        let incoming = list.filter { $0.flow == .in }.reduce(0) { $0 + $1.amount }
        let notes = Set(list.map(\.noteId)).count
        let updated = list.map(\.createdAt).max() ?? .now
        return SpendCard(
            label: cardLabel,
            out: out,
            incoming: incoming,
            meta: "\(notes) \(notes == 1 ? "note" : "notes") · updated \(Day.clock(updated))",
            hidden: $app.hidden,
            onSummary: nil)
            .contentShape(.rect)
            .onTapGesture { summaryOpen = true }
            .accessibilityAction(named: "Summary") { summaryOpen = true }
    }

    /// "Recent | File": the day's lines, or the notes written for it.
    private func listSection(_ list: [Entry]) -> some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            HStack(spacing: Space.s16) {
                ForEach(Pane.allCases, id: \.self) { p in
                    Button { animate { pane = p } } label: {
                        Text(p.rawValue)
                            .font(AppFont.heading(22, .semibold, relativeTo: .title2))
                            .foregroundStyle(pane == p ? Tokens.text900 : Tokens.grey400)
                            .frame(minHeight: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(pane == p ? [.isSelected, .isHeader] : .isHeader)
                }
            }
            switch pane {
            case .recent: recentRows(list)
            case .file: FilePane(range: app.range, day: app.day, today: app.today)
            }
        }
    }

    private func recentRows(_ shown: [Entry]) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { i, e in
                // Weekly and Monthly cover many days: each day gets a small heading.
                if app.range != .day && (i == 0 || shown[i - 1].date != e.date) {
                    Text(Day.dayHeading(e.date, today: app.today))
                        .font(AppFont.main(12, .semibold, relativeTo: .caption))
                        .foregroundStyle(Tokens.grey400)
                        .padding(.top, i == 0 ? 0 : Space.s16)
                        .padding(.bottom, Space.s4)
                        .accessibilityAddTraits(.isHeader)
                } else if i > 0 {
                    Divider().overlay(Tokens.bd1)
                }
                Button { openEntry = e } label: { EntryRow(entry: e, hidden: app.hidden) }
                    .buttonStyle(.plain)
            }
        }
    }

    /// Soft green light at the top of the screen (page glow from tokens.css).
    private var glow: some View {
        LinearGradient(colors: [Tokens.brand100, Tokens.bg3], startPoint: .top, endPoint: .bottom)
            .frame(height: 320)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

    // MARK: - Words

    private var cardLabel: String {
        let (_, m, _) = Day.parts(app.day)
        switch app.range {
        case .week: return "Spent this week"
        case .month: return "Spent in \(Day.monthsLong[m - 1])"
        case .day: return app.day == app.today ? "Spent today" : "Spent on \(Day.short(app.day))"
        }
    }

    private var summaryTitle: String {
        switch app.range {
        case .day: "Summary · \(Day.short(app.day))"
        case .week: "Summary · week of \(Day.short(Day.monday(of: app.day)))"
        case .month: "Summary · \(Day.monthsLong[Day.parts(app.day).m - 1])"
        }
    }

    /// "Nothing recorded on 07 Aug." under the greeting when it isn't today.
    private var nothingNote: String? {
        switch app.range {
        case .week: "Nothing recorded this week."
        case .month: "Nothing recorded in \(Day.monthsLong[Day.parts(app.day).m - 1])."
        case .day: app.day == app.today ? nil : "Nothing recorded on \(Day.short(app.day))."
        }
    }

    private var scrolledTitle: String {
        switch app.range {
        case .day: app.day == app.today ? "Today" : "Today · \(Day.short(app.day))"
        case .week: "Today · Week of \(Day.short(Day.monday(of: app.day)))"
        case .month: "Today · \(Day.monthsShort[Day.parts(app.day).m - 1])"
        }
    }
}

/// The empty day: logo, "Good Morning, Nin", three ideas (High Fi 2 › Today).
struct EmptyDay: View {
    enum Idea { case write, due, decisions }

    var name: String
    var nothingNote: String?
    var onIdea: (Idea) -> Void

    var body: some View {
        VStack(spacing: Space.s16) {
            LogoMark(size: 64)
            Text("\(Day.greeting()), \(name)")
                .font(AppFont.title(24, .bold, relativeTo: .title))
                .foregroundStyle(Tokens.text900)
                .multilineTextAlignment(.center)
            VStack(spacing: 0) {
                idea("What can I help you think through today?", .write)
                idea("What's worth talking about today?", .due)
                idea("Any decisions on your mind today?", .decisions)
            }
            if let nothingNote {
                Text(nothingNote)
                    .font(AppFont.main(12, .regular, relativeTo: .caption))
                    .foregroundStyle(Tokens.grey400)
                    .padding(.top, Space.s8)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func idea(_ text: String, _ idea: Idea) -> some View {
        Button {
            onIdea(idea)
        } label: {
            HStack(spacing: Space.s8) {
                Image("LogoMark")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 16)
                    .foregroundStyle(Tokens.grey400)
                    .accessibilityHidden(true)
                Text(text)
                    .font(AppFont.main(14))
                    .foregroundStyle(Tokens.text700)
                    .multilineTextAlignment(.leading)
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// "File": the notes written for the day (Notes of the day), as cards. Tap one to open it.
private struct FilePane: View {
    var range: DayRange
    var day: String
    var today: String
    @Environment(AppState.self) private var app
    @Query(sort: \DayNote.date, order: .reverse) private var notes: [DayNote]

    var body: some View {
        let (from, to) = range.bounds(for: day)
        let shown = notes.filter { $0.date >= from && $0.date <= to && !$0.lines.isEmpty }
        VStack(alignment: .leading, spacing: Space.s12) {
            if shown.isEmpty {
                Text("No note written \(range == .day ? (day == today ? "today" : "on \(Day.short(day))") : range == .week ? "this week" : "this month").")
                    .font(AppFont.main(14))
                    .foregroundStyle(Tokens.grey400)
            }
            ForEach(shown) { n in
                Button {
                    app.day = n.date
                    app.dayNoteOpen = true
                } label: {
                    NoteCard(title: "Note - \(Day.long(n.date))", lines: n.lines)
                }
                .buttonStyle(.plain)
            }
            Button {
                app.dayNoteOpen = true
            } label: {
                Label("Write a note for \(day == today ? "today" : Day.short(day))", systemImage: "square.and.pencil")
                    .font(AppFont.main(15, .semibold))
                    .foregroundStyle(Tokens.brand700)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }
}

/// A written note as a small card ("Note - August 07, 2026", the first lines, a "Note" tag).
struct NoteCard: View {
    var title: String
    var lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            Text(title).font(AppFont.main(14, .semibold)).foregroundStyle(Tokens.text900)
            ForEach(Array(lines.prefix(3).enumerated()), id: \.offset) { _, l in
                Text(l).font(AppFont.main(13)).foregroundStyle(Tokens.text700).lineLimit(1)
            }
            if lines.count > 3 {
                Text("+\(lines.count - 3) more").font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
            }
            Text("Note")
                .font(AppFont.main(12, .medium))
                .foregroundStyle(Tokens.brand800)
                .padding(.horizontal, Space.s8)
                .padding(.vertical, 2)
                .background(Tokens.brand100, in: .rect(cornerRadius: Corner.c4))
        }
        .padding(Space.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c14))
        .overlay(RoundedRectangle(cornerRadius: Corner.c14).strokeBorder(Tokens.bd1))
        .accessibilityElement(children: .combine)
    }
}
