import SwiftData
import SwiftUI

/// Today — Figma High Fi 2 › Today (962:31983): "Today" and profile in the toolbar, month and
/// Daily / Weekly / Monthly, the week strip, then either the greeting (empty day) or the dark
/// green card with the list underneath (Final 765:19666).
struct TodayView: View {
    @Environment(AppState.self) private var app
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @Query private var profiles: [Profile]

    @State private var filter: Filter = .all
    @State private var picking = false
    @State private var openEntry: Entry?
    @State private var summaryOpen = false
    @State private var scrolled = false
    @State private var laterNotice: String?

    enum Filter: String, CaseIterable { case all = "All", expense = "Expense", receive = "Receive" }

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
                    if list.isEmpty {
                        EmptyDay(name: profiles.first?.name ?? "Nin", nothingNote: nothingNote) { idea in
                            switch idea {
                            case .write: app.openQuickNote()
                            case .due: app.tab = .due
                            case .decisions:
                                laterNotice = "Talking decisions through comes later. For now I record what you spend and receive, and keep track of bills."
                            }
                        }
                        .padding(.top, Space.s32)
                    } else {
                        card(list)
                        listSection(list)
                    }
                }
                .padding(.horizontal, Space.s20)
                .padding(.bottom, Space.s24)
            }
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
        ToolbarItem(placement: .topBarLeading) {
            Button("Today") {
                app.day = app.today
            }
            .font(AppFont.main(15, .semibold))
            .accessibilityLabel("Go to today")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                app.tab = .profile
            } label: {
                Image(systemName: "person")
                    .foregroundStyle(Tokens.brand500)
            }
            .accessibilityLabel("Profile")
        }
    }

    private var header: some View {
        @Bindable var app = app
        let (y, m, _) = Day.parts(app.day)
        return HStack {
            Button {
                picking = true
            } label: {
                Text("\(Day.monthsShort[m - 1]) \(String(y))")
                    .font(AppFont.heading(28, .semibold, relativeTo: .largeTitle))
                    .foregroundStyle(Tokens.text900)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(Day.monthsLong[m - 1]) \(String(y)). Pick a day")
            Spacer()
            Menu {
                Picker("Show", selection: $app.range) {
                    ForEach(DayRange.allCases) { Text($0.label).tag($0) }
                }
            } label: {
                HStack(spacing: Space.s4) {
                    Text(app.range.label)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .semibold))
                }
                .font(AppFont.main(15, .medium))
                .foregroundStyle(Tokens.text700)
            }
            .accessibilityLabel("Show \(app.range.label)")
        }
        .padding(.top, Space.s4)
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
            onSummary: { summaryOpen = true })
    }

    private func listSection(_ list: [Entry]) -> some View {
        let shown = list.filter {
            switch filter {
            case .all: true
            case .expense: $0.flow == .out
            case .receive: $0.flow == .in
            }
        }
        return VStack(alignment: .leading, spacing: Space.s12) {
            Text("List")
                .font(AppFont.main(18, .semibold, relativeTo: .headline))
                .foregroundStyle(Tokens.text900)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: Space.s8) {
                ForEach(Filter.allCases, id: \.self) { f in
                    FilterChip(label: f.rawValue, selected: filter == f) { filter = f }
                }
            }
            if shown.isEmpty {
                Text("Nothing \(filter == .expense ? "spent" : "received") \(rangeWords).")
                    .font(AppFont.main(14))
                    .foregroundStyle(Tokens.grey400)
                    .padding(.vertical, Space.s16)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(shown) { e in
                        Button { openEntry = e } label: { EntryRow(entry: e, hidden: app.hidden) }
                            .buttonStyle(.plain)
                        if e.id != shown.last?.id { Divider().overlay(Tokens.bd0) }
                    }
                }
            }
        }
        .padding(Space.s16)
        .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c20))
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

    private var rangeWords: String {
        switch app.range {
        case .day: "on this day"
        case .week: "this week"
        case .month: "this month"
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
        case .day: "Today · \(app.day == app.today ? "Today" : Day.short(app.day))"
        case .week: "Today · Week of \(Day.short(Day.monday(of: app.day)))"
        case .month: "Today · \(Day.monthsShort[Day.parts(app.day).m - 1])"
        }
    }
}

/// The empty day: logo, "Good Morning, Nin", three ideas (High Fi 2 › Today).
private struct EmptyDay: View {
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
            VStack(spacing: Space.s8) {
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
        }
        .buttonStyle(.plain)
    }
}
