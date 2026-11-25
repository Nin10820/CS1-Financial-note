import Charts
import SwiftData
import SwiftUI

/// View Analysis, from the chart button on Today's green card (Figma "View Analysis"):
/// D / W / M / Y / All, the picked date and amount, a bar chart (dark = money out,
/// striped green = money in), the All / out / in filter — then the template cards below
/// (Finance App 1231:9323), filled with the user's own lines and following the filter:
/// - Spending — big total, change against the month before, weekly area line (Average Order Value)
/// - Where it went — donut by category with a legend (Expenses)
/// - Kept — ring of what's left of the money in (Returning Customer Rate)
/// - Biggest spends — bars (Delivery Time by Carrier)
/// - This week — line against last week (Conversion Rate)
/// Opens as a sheet; the expand button moves it onto Today's page, where the tab bar stays.
struct AnalyticsView: View {
    var entries: [Entry]
    /// The day the period is built around (starts on the day picked on Today).
    @State var anchor: String
    var today: String
    var hidden: Bool
    /// On Today's page (back and + buttons) rather than in a sheet (expand and close).
    var pushed = false
    var onExpand: (() -> Void)? = nil
    var onAdd: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var period: AnalysisPeriod = .week
    @State private var filter: FlowFilter = .all
    @State private var picked: Int?
    /// What was put aside toward the saving goal (moves on the Savings asset).
    @Query private var moves: [AssetMove]
    @Environment(\.modelContext) private var context
    @State private var savingCustom = false
    @State private var saveDraft: Int?
    /// The top chart has scrolled away: the date, amount and filter stay pinned under the bar.
    @State private var pinned = false
    /// The big All / out / in row has gone under the bar too: the pinned header shows it.
    @State private var filterGone = false
    /// How far the chart has shrunk while scrolling (0…`collapseRoom`): the header above it
    /// stays put and only the bars get shorter, then the page scrolls on as usual.
    @State private var collapse: CGFloat = 0
    private let collapseRoom: CGFloat = 120
    /// The group picked on the needs pie (its lines and a tip show underneath).
    @State private var need: SpendNeed?
    /// What the months line shows, and the month picked on it.
    @State private var series: MoneySeries = .income
    @State private var pickedMonth: String?
    /// The income source picked on the money-in pie.
    @State private var source: IncomeKind?
    /// The monthly saving goal, kept on this phone (0 = use the suggestion).
    @AppStorage("savingGoal") private var savingGoal = 0
    /// Count bills in the daily budget and the dots (off: bills are set aside first).
    @AppStorage("savingCountsBills") private var countBills = false
    @State private var settingGoal = false
    @State private var goalDraft: Int?

    static let orange = Color(hex: 0xFF8000)
    static let green = Color(hex: 0x00AD00)

    /// The month the cards look at.
    private var month: String { Month.of(period == .all ? today : anchor) }

    /// All time: from the first line written to today.
    private var allSpan: (from: String, to: String) { (entries.map(\.date).min() ?? today, today) }

    var body: some View {
        if pushed {
            page
        } else {
            NavigationStack { page }
        }
    }

    private var page: some View {
        ScrollView {
            VStack(spacing: Space.s16) {
                overview
                // The cards follow the filter above: money out, money in, or both.
                VStack(spacing: Space.s16) {
                    if filter != .in {
                        whereItWent
                        trend
                    }
                    if filter != .out {
                        cameFrom
                    }
                    // The line over months only says something when looking at a year or all time.
                    if period == .year || period == .all {
                        overMonths
                    }
                    if filter != .out {
                        kept
                    }
                    if filter != .in {
                        biggest
                    }
                }
                .animation(.snappy, value: filter)
                .padding(.horizontal, Space.s16)
            }
            .padding(.bottom, Space.s32)
        }
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, y in
            let c = min(max(y, 0), collapseRoom).rounded()
            if c != collapse { collapse = c }
        }
        .overlay(alignment: .top) {
            if pinned {
                pinnedBar.transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Tokens.bgGrouped)
        // The bar sits on white, flush with the chart under it.
        .toolbarBackground(Tokens.bgWhite, for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .sheetHeader("View Analysis",
                     leading: pushed ? .none : .icon("Open as a page", systemImage: "arrow.up.forward.square") { onExpand?() },
                     trailing: pushed ? .none : .close)
        .toolbar {
            if pushed {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { onAdd?() } label: { AppIcon(.plus, size: 20) }
                        .accessibilityLabel("Add")
                }
            }
        }
        .onChange(of: filter) { _, f in
            switch f {
            case .out: series = .expenses
            case .in: series = .income
            case .all: break
            }
        }
        .sheet(isPresented: $savingCustom) { Group {
            SaveSheet(value: $saveDraft, left: todayLeft) { v in
                LocalStore(context: context).putAside(v ?? 0, date: today)
            }
        }.sheetSurface() }
        .sheet(isPresented: $settingGoal) { Group {
            GoalSheet(value: $goalDraft,
                      suggested: SavingPlan(month: month, today: today, entries: entries, goalSetting: 0).suggested) { v in
                savingGoal = v ?? 0
            }
        }.sheetSurface() }
    }

    // MARK: - Top chart (View Analysis)

    /// What the top of the page says: the bars, the date or period, its amount, and the
    /// period's money out and in for the filter.
    private var summary: (bars: [AnalysisBar], title: String, value: Int, out: Int, incoming: Int) {
        let bars = AnalysisBars.make(period, anchor: anchor, custom: allSpan, entries: entries)
        let shown = picked.flatMap { bars.indices.contains($0) ? bars[$0] : nil }
        let out = shown?.out ?? bars.reduce(0) { $0 + $1.out }
        let incoming = shown?.incoming ?? bars.reduce(0) { $0 + $1.incoming }
        let value = filter == .out ? out : filter == .in ? incoming : incoming - out
        return (bars, shown?.title ?? AnalysisBars.periodTitle(period, anchor: anchor, custom: allSpan), value,
                bars.reduce(0) { $0 + $1.out }, bars.reduce(0) { $0 + $1.incoming })
    }

    private var overview: some View {
        let s = summary
        // The chart gives up height and the block moves down by the same amount, so the
        // picker, date and amount stay where they are while the cards slide up.
        let shrink = period == .day ? 0 : collapse
        return VStack(alignment: .leading, spacing: Space.s16) {
            PeriodPicker(period: $period) { p in
                picked = nil
            }
            amountBlock(s.title, s.value, size: 44)
                // As soon as the amount reaches the bar it shrinks into the pinned header,
                // and the chart slides on underneath it.
                .onGeometryChange(for: Bool.self) { $0.frame(in: .scrollView).minY < 0 } action: { gone in
                    withAnimation(.snappy) { pinned = gone }
                }
            // A day needs no bar chart; the two pies below say where its money went and came from.
            if period != .day {
                AnalysisBarChart(bars: s.bars, filter: filter, picked: picked, hidden: hidden, focus: focus(s.bars.count),
                                 unit: period == .year || (period == .all && Calendar.current.dateComponents([.day], from: Day.date(allSpan.from), to: Day.date(allSpan.to)).day ?? 0 > 31) ? "month" : "day",
                                 plot: 210 - shrink) { i in
                    withAnimation(.snappy) { picked = picked == i ? nil : i }
                }
            }
            LightFlowFilter(filter: $filter, out: s.out, incoming: s.incoming, hidden: hidden)
                .onGeometryChange(for: Bool.self) { $0.frame(in: .scrollView).maxY < 90 } action: { gone in
                    withAnimation(.snappy) { filterGone = gone }
                }
        }
        .padding(.horizontal, Space.s16)
        .padding(.top, Space.s8 + shrink)
        .padding(.bottom, Space.s20)
        .background(Tokens.bgWhite)
        .pageSwipe(back: { shift(-1) }, forward: { shift(1) })
    }

    /// The same date, amount and filter, smaller, held under the bar while the cards scroll.
    private var pinnedBar: some View {
        let s = summary
        // Two columns: date and amount on the left, out and in stacked on the right.
        return HStack(alignment: .center, spacing: Space.s12) {
            amountBlock(s.title, s.value, size: 28)
            Spacer(minLength: 0)
            if filterGone {
                FlowColumn(filter: $filter, out: s.out, incoming: s.incoming, hidden: hidden)
                    .frame(width: 150)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .padding(.horizontal, Space.s16)
        .padding(.top, Space.s4)
        .padding(.bottom, Space.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.bgWhite)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }

    private func amountBlock(_ title: String, _ value: Int, size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: size > 30 ? Space.s4 : 0) {
            Text(title)
                .font(AppFont.main(size > 30 ? 16 : 14, .medium))
                .foregroundStyle(Tokens.brand600)
                .contentTransition(.opacity)
            HStack(alignment: .firstTextBaseline, spacing: Space.s4) {
                Text(hidden ? "••••••" : (value < 0 ? "-" : "") + Money.format(abs(value)))
                    .font(AppFont.heading(size, .medium, relativeTo: .largeTitle))
                    .foregroundStyle(Tokens.text900)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text("đ").font(AppFont.heading(size > 30 ? 32 : 20)).foregroundStyle(Tokens.grey400)
            }
        }
        .accessibilityElement(children: .combine)
        .padding(.horizontal, Space.s4)
    }

    /// The pair to show first when the bars slide: the day or month being looked at.
    private func focus(_ count: Int) -> Int? {
        let day = min(anchor, today)
        switch period {
        case .month: return Day.parts(day).d - 1
        case .year: return Day.parts(day).m - 1
        case .all: return count - 1
        case .day, .week: return nil
        }
    }

    /// A sideways swipe on the top chart: the period before or after (never past today).
    private func shift(_ step: Int) {
        guard period != .all else { return }
        let next: String = switch period {
        case .day: Day.addDays(anchor, step)
        case .week: Day.addDays(anchor, 7 * step)
        case .month: Month.add(Month.of(anchor), step) + "-" + String(format: "%02d", min(Day.parts(anchor).d, 28))
        case .year: Month.add(Month.of(anchor), 12 * step) + "-" + String(format: "%02d", min(Day.parts(anchor).d, 28))
        case .all: anchor
        }
        guard next <= today || step < 0 else { return }
        withAnimation(.snappy) { anchor = min(next, today); picked = nil }
    }

    // MARK: - Data

    private var monthLines: [Entry] { entries.filter { Month.of($0.date) == month } }
    private var monthOut: [Entry] { monthLines.filter { $0.flow == .out } }
    private func outSum(_ lines: [Entry]) -> Int { lines.filter { $0.flow == .out }.reduce(0) { $0 + $1.amount } }
    private func inSum(_ lines: [Entry]) -> Int { lines.filter { $0.flow == .in }.reduce(0) { $0 + $1.amount } }

    /// Monday of the week the day falls in.
    private static func monday(_ iso: String) -> String {
        let weekday = Calendar(identifier: .gregorian).component(.weekday, from: Day.date(iso)) // 1 = Sunday
        return Day.addDays(iso, -((weekday + 5) % 7))
    }

    /// The lines of the period picked at the top (day, week, month, year or all time).
    private var spanLines: [Entry] {
        let span = AnalysisBars.range(period, anchor: anchor, custom: allSpan)
        return entries.filter { $0.date >= span.from && $0.date <= span.to }
    }


    /// Where spending is heading: money out month by month (this month with its likely end),
    /// against the average of the months before, in one plain sentence, and which categories
    /// moved most against the same days last month. Going down shows green; going up stays grey.
    private var trend: some View {
        let current = Month.of(today)
        let first = Month.of(allSpan.from)
        var months: [String] = []
        var m = Month.add(current, -5)
        while m <= current { if m >= first { months.append(m) }; m = Month.add(m, 1) }
        if months.isEmpty { months = [current] }
        let outLines = entries.filter { $0.flow == .out }
        func spent(_ month: String, upTo day: Int = 31) -> Int {
            outLines.filter { Month.of($0.date) == month && Day.parts($0.date).d <= day }.reduce(0) { $0 + $1.amount }
        }
        let (y, mo, d) = Day.parts(today)
        let days = Day.daysIn(year: y, month: mo)
        let soFar = spent(current)
        // Everyday spending keeps its pace to the month's end; bills already paid stay as they are.
        let everyday = outLines.filter { Month.of($0.date) == current && $0.category != .bills }.reduce(0) { $0 + $1.amount }
        let projected = (soFar + everyday * (days - d) / max(d, 1)) / 1000 * 1000
        // A first month that started part-way through doesn't count toward the average.
        let partialFirst = Day.parts(allSpan.from).d > 1 ? first : ""
        let past = months.dropLast().filter { $0 != partialFirst }.suffix(3).map { spent($0) }
        let average = past.isEmpty ? 0 : past.reduce(0, +) / past.count
        let change = Self.change(projected, average)
        let bars = months.map { (month: $0, spent: $0 == current ? soFar : spent($0), extra: $0 == current ? max(0, projected - soFar) : 0) }
        // Category moves: this month so far against the same days last month.
        let before = Month.add(current, -1)
        let nowBy = Dictionary(grouping: outLines.filter { Month.of($0.date) == current }, by: SpendKind.of)
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        let thenBy = Dictionary(grouping: outLines.filter { Month.of($0.date) == before && Day.parts($0.date).d <= d }, by: SpendKind.of)
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        let moves = Set(nowBy.keys).union(thenBy.keys)
            .map { (kind: $0, diff: (nowBy[$0] ?? 0) - (thenBy[$0] ?? 0)) }
            .filter { abs($0.diff) >= 50_000 }
            .sorted { abs($0.diff) > abs($1.diff) }
            .prefix(4)
        let label = { (m: String) in Day.monthsShort[Day.parts(m + "-01").m - 1] }
        let sentence: String = {
            guard average > 0, let change else { return "Keep writing things down — the trend shows up after a month or two." }
            let gap = Self.compact(abs(projected - average)) + "đ"
            if abs(change) < 0.05 { return "You're spending about as usual this month." }
            return change < 0
                ? "You're spending less than usual — at this pace you'll keep about \(hidden ? "a bit" : gap) more than an average month."
                : "You're spending more than usual — about \(hidden ? "a bit" : gap) above an average month at this pace."
        }()
        return AnalyticsCard(icon: .chartLineUp, tile: Tokens.success.opacity(0.08), tint: Tokens.success, title: "Trend") {
            BigNumber(value: projected, hidden: hidden, change: change, lowerIsGood: true,
                      note: "likely by the end of \(Day.monthsLong[mo - 1]) · vs. your \(past.count)-month average")
            Chart {
                ForEach(bars, id: \.month) { b in
                    BarMark(x: .value("Month", label(b.month)), y: .value("Spent", b.spent), stacking: .standard)
                        .foregroundStyle(b.month == current ? Tokens.brand500 : Tokens.brand500.opacity(0.45))
                        .cornerRadius(6)
                    if b.extra > 0 {
                        BarMark(x: .value("Month", label(b.month)), y: .value("Spent", b.extra), stacking: .standard)
                            .foregroundStyle(Tokens.brand500.opacity(0.18))
                            .cornerRadius(6)
                            .annotation(position: .top, spacing: 4) {
                                Text("likely").font(AppFont.main(11)).foregroundStyle(Tokens.grey400)
                            }
                    }
                }
                if average > 0 {
                    RuleMark(y: .value("Average", average))
                        .foregroundStyle(Tokens.text700.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, alignment: .leading, spacing: 4) {
                            Text(hidden ? "avg" : "avg " + Self.compact(average))
                                .font(AppFont.main(11, .medium)).foregroundStyle(Tokens.text700)
                        }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { v in
                    AxisGridLine().foregroundStyle(Tokens.bd1)
                    AxisValueLabel {
                        if !hidden, let n = v.as(Int.self) { Text(Self.compact(n)).font(AppFont.main(12)).foregroundStyle(Tokens.grey400) }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in AxisValueLabel().font(AppFont.main(12)).foregroundStyle(Tokens.grey400) }
            }
            .frame(height: 170)
            .noPageSwipe()
            Text(sentence).font(AppFont.main(14)).foregroundStyle(Tokens.text700)
                .fixedSize(horizontal: false, vertical: true)
            if !moves.isEmpty {
                VStack(alignment: .leading, spacing: Space.s8) {
                    Text("vs. the same days last month".uppercased())
                        .font(AppFont.main(11, .semibold)).tracking(0.4).foregroundStyle(Tokens.grey400)
                    ForEach(Array(moves), id: \.kind) { mv in
                        HStack(spacing: Space.s8) {
                            Circle().fill(mv.kind.color).frame(width: 8, height: 8)
                            Text(mv.kind.rawValue).font(AppFont.main(14, .medium)).foregroundStyle(Tokens.text700).lineLimit(1)
                            Spacer()
                            Text((mv.diff < 0 ? "↓ " : "↑ ") + (hidden ? "••••" : Self.compact(abs(mv.diff)) + "đ"))
                                .font(AppFont.main(14, .medium))
                                .foregroundStyle(mv.diff < 0 ? Tokens.success : Tokens.text700)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    /// Where the money went, by how needed it was: must-have, nice to have, could skip.
    /// Tap a group to see its lines and a tip on keeping more (for the period picked at the top).
    private var whereItWent: some View {
        let out = spanLines.filter { $0.flow == .out }
        let total = out.reduce(0) { $0 + $1.amount }
        let groups = Dictionary(grouping: out, by: SpendNeed.of)
        let rows = SpendNeed.allCases.map { n in (need: n, sum: (groups[n] ?? []).reduce(0) { $0 + $1.amount }) }
        let shown = need.flatMap { n in rows.first { $0.need == n } }
        return AnalyticsCard(icon: .chartPieSlice, tile: Self.orange.opacity(0.06), tint: Self.orange, title: "Where it went") {
            HStack(alignment: .center, spacing: Space.s20) {
                ZStack {
                    if total == 0 {
                        Circle().stroke(Tokens.bg4, lineWidth: 18).padding(9)
                    } else {
                        Chart(rows.filter { $0.sum > 0 }, id: \.need) { r in
                            SectorMark(angle: .value("Spent", r.sum), innerRadius: .ratio(0.72), angularInset: 2)
                                .foregroundStyle(r.need.color)
                                .opacity(need == nil || need == r.need ? 1 : 0.3)
                                .cornerRadius(4)
                        }
                        .chartLegend(.hidden)
                    }
                    VStack(spacing: 0) {
                        Text(shown.map { "\(Self.percent($0.sum, of: total))%" } ?? (hidden ? "••••" : Self.compact(total)))
                            .font(AppFont.heading(24, .medium))
                            .foregroundStyle(shown?.need.color ?? Tokens.text900)
                            .contentTransition(.numericText())
                            .minimumScaleFactor(0.7).lineLimit(1)
                        Text(shown?.need.rawValue.lowercased() ?? "spent")
                            .font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .padding(.horizontal, Space.s20)
                }
                .frame(width: 140, height: 140)
                VStack(alignment: .leading, spacing: Space.s6) {
                    ForEach(rows, id: \.need) { r in
                        Button {
                            withAnimation(.snappy) { need = need == r.need ? nil : r.need }
                        } label: {
                            HStack(spacing: Space.s8) {
                                Circle().fill(r.need.color).frame(width: 10, height: 10)
                                Text(r.need.rawValue).font(AppFont.main(14, need == r.need ? .semibold : .regular))
                                    .foregroundStyle(Tokens.text700).lineLimit(1).minimumScaleFactor(0.8)
                                Spacer(minLength: 4)
                                Text("\(Self.percent(r.sum, of: total))%").font(AppFont.main(14, .medium)).foregroundStyle(Tokens.text900)
                            }
                            .padding(.horizontal, Space.s8)
                            .frame(minHeight: 36)
                            .background(need == r.need ? r.need.color.opacity(0.12) : .clear, in: .rect(cornerRadius: Corner.c12))
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(r.need.rawValue), \(Self.percent(r.sum, of: total)) percent")
                        .accessibilityHint(need == r.need ? "Shows all groups" : "Shows what's in this group")
                        .accessibilityAddTraits(need == r.need ? .isSelected : [])
                    }
                }
            }
            .padding(.top, Space.s4)
            Text(need?.hint ?? "Tap a group to see what's in it.")
                .font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                .contentTransition(.opacity)
            // The picked group opens right here, under a dashed line: its kinds as a pie,
            // their lines, and a tip.
            if let n = need {
                VStack(alignment: .leading, spacing: Space.s16) {
                    GeometryReader { g in
                        Path { p in
                            p.move(to: .zero)
                            p.addLine(to: CGPoint(x: g.size.width, y: 0))
                        }
                        .stroke(Tokens.bd1, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    .frame(height: 1)
                    Text("\(n.rawValue) · Detail").font(AppFont.main(14, .semibold)).foregroundStyle(Tokens.text900)
                    NeedDetail(need: n, lines: spanLines.filter { $0.flow == .out && SpendNeed.of($0) == n }, hidden: hidden)
                        .id(n)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// Where money in came from (salary, a business, rent, freelance…) for the period picked at
    /// the top. Tap a source to see its lines.
    private var cameFrom: some View {
        let incoming = spanLines.filter { $0.flow == .in }
        let total = incoming.reduce(0) { $0 + $1.amount }
        let groups = Dictionary(grouping: incoming, by: IncomeKind.of)
        let rows = groups.map { (kind: $0.key, lines: $0.value, sum: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.sum > $1.sum }
        let shown = source.flatMap { k in rows.first { $0.kind == k } }
        return AnalyticsCard(icon: .wallet, tile: Tokens.success.opacity(0.08), tint: Tokens.success, title: "Where it came from") {
            HStack(alignment: .center, spacing: Space.s20) {
                ZStack {
                    if rows.isEmpty {
                        Circle().stroke(Tokens.bg4, lineWidth: 18).padding(9)
                    } else {
                        Chart(rows, id: \.kind) { r in
                            SectorMark(angle: .value("Received", r.sum), innerRadius: .ratio(0.72), angularInset: 2)
                                .foregroundStyle(r.kind.color)
                                .opacity(source == nil || source == r.kind ? 1 : 0.3)
                                .cornerRadius(4)
                        }
                        .chartLegend(.hidden)
                    }
                    VStack(spacing: 0) {
                        Text(shown.map { "\(Self.percent($0.sum, of: total))%" } ?? (hidden ? "••••" : Self.compact(total)))
                            .font(AppFont.heading(24, .medium))
                            .foregroundStyle(shown?.kind.color ?? Tokens.text900)
                            .contentTransition(.numericText())
                            .minimumScaleFactor(0.7).lineLimit(1)
                        Text(shown?.kind.rawValue.lowercased() ?? "received")
                            .font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, Space.s20)
                }
                .frame(width: 140, height: 140)
                VStack(alignment: .leading, spacing: Space.s4) {
                    if rows.isEmpty { Text("No money in here").font(AppFont.main(14)).foregroundStyle(Tokens.grey400) }
                    ForEach(rows, id: \.kind) { r in
                        Button {
                            withAnimation(.snappy) { source = source == r.kind ? nil : r.kind }
                        } label: {
                            HStack(spacing: Space.s8) {
                                Circle().fill(r.kind.color).frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(r.kind.rawValue).font(AppFont.main(14, source == r.kind ? .semibold : .medium))
                                        .foregroundStyle(Tokens.text700).lineLimit(1).minimumScaleFactor(0.8)
                                    Text(hidden ? "••••" : Self.compact(r.sum) + "đ")
                                        .font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                                }
                                Spacer(minLength: 2)
                                let pct = Self.percent(r.sum, of: total)
                                Text(pct == 0 ? "<1%" : "\(pct)%").font(AppFont.main(14, .medium)).foregroundStyle(Tokens.text900)
                            }
                            .padding(.horizontal, Space.s6)
                            .frame(minHeight: 40)
                            .background(source == r.kind ? r.kind.color.opacity(0.12) : .clear, in: .rect(cornerRadius: Corner.c12))
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(r.kind.rawValue), \(Self.percent(r.sum, of: total)) percent")
                        .accessibilityAddTraits(source == r.kind ? .isSelected : [])
                    }
                }
            }
            .padding(.top, Space.s4)
            if let shown {
                ItemList(title: shown.kind.rawValue, lines: shown.lines, color: shown.kind.color, hidden: hidden)
                    .transition(.opacity)
            } else if !rows.isEmpty {
                Text("Tap a source to see what's in it.").font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
            }
        }
    }

    /// Money in, out or kept month by month, as a line (the income look from the reference).
    private var overMonths: some View {
        // A year: its months up to now. All time: every month since the first line.
        let end = min(period == .all ? Month.of(today) : String(anchor.prefix(4)) + "-12", Month.of(today))
        let start = period == .all ? Month.of(allSpan.from) : String(anchor.prefix(4)) + "-01"
        var months: [String] = []
        var m = start
        while m <= end { months.append(m); m = Month.add(m, 1) }
        if months.isEmpty { months = [end] }
        func value(_ m: String) -> Int {
            let lines = entries.filter { Month.of($0.date) == m }
            switch series {
            case .income: return inSum(lines)
            case .expenses: return outSum(lines)
            case .kept: return inSum(lines) - outSum(lines)
            }
        }
        // Months before the first line written stay off the chart (keep at least three).
        while months.count > 3, months[0] < Month.of(allSpan.from) { months.removeFirst() }
        let points = months.map { (month: $0, value: value($0)) }
        let picked = points.first { $0.month == pickedMonth } ?? points.last!
        let label = { (m: String) in Day.monthsShort[Day.parts(m + "-01").m - 1] }
        return AnalyticsCard(icon: .chartLineUp, tile: Tokens.success.opacity(0.08), tint: Tokens.success, title: "Month by month") {
            HStack(spacing: Space.s8) {
                Menu {
                    ForEach(MoneySeries.allCases) { s in
                        Button(s.rawValue) { withAnimation(.snappy) { series = s } }
                    }
                } label: {
                    HStack(spacing: Space.s6) {
                        Circle().fill(series.color).frame(width: 8, height: 8)
                        Text(series.rawValue).font(AppFont.main(14, .medium))
                        AppIcon(.caretDown, size: 12)
                    }
                    .foregroundStyle(Tokens.text900)
                    .padding(.horizontal, Space.s12)
                    .frame(height: 32)
                    .background(Tokens.bg4, in: .capsule)
                }
                Spacer()
                Text(Day.monthsLong[Day.parts(picked.month + "-01").m - 1])
                    .font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                Text(hidden ? "••••" : (picked.value < 0 ? "−" : "") + Self.compact(abs(picked.value)) + "đ")
                    .font(AppFont.main(14, .semibold))
                    .foregroundStyle(Tokens.text900)
                    .padding(.horizontal, Space.s8)
                    .frame(height: 26)
                    .background(series.color.opacity(0.25), in: .capsule)
                    .contentTransition(.numericText())
            }
            Chart {
                ForEach(points, id: \.month) { p in
                    AreaMark(x: .value("Month", label(p.month)), y: .value("Amount", p.value))
                        .foregroundStyle(LinearGradient(colors: [series.color.opacity(0.18), series.color.opacity(0)],
                                                        startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Month", label(p.month)), y: .value("Amount", p.value))
                        .foregroundStyle(series.color)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .interpolationMethod(.catmullRom)
                }
                PointMark(x: .value("Month", label(picked.month)), y: .value("Amount", picked.value))
                    .symbol { PickedDot(color: series.color) }
            }
            .chartXSelection(value: Binding(get: { label(picked.month) }, set: { name in
                if let name, let m = points.first(where: { label($0.month) == name }) { pickedMonth = m.month }
            }))
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { v in
                    AxisValueLabel().font(AppFont.main(12))
                        .foregroundStyle(v.as(String.self) == label(picked.month) ? Tokens.text900 : Tokens.grey400)
                }
            }
            .frame(height: 140)
            .noPageSwipe()
        }
    }

    /// What's left of today's budget under this month's saving plan.
    private var todayLeft: Int {
        let plan = SavingPlan(month: Month.of(today), today: today, entries: entries, goalSetting: savingGoal, countBills: countBills)
        return max(0, plan.dailyBudget - plan.spent(on: today))
    }

    /// Saving goal (Returning Customer Rate style): how much of this month's goal is kept so far,
    /// the daily budget that keeps it on track, and a dot for each day — darker when that day
    /// stayed well under the budget. On D it's about the picked day.
    private var kept: some View {
        let plan = SavingPlan(month: month, today: today, entries: entries, goalSetting: savingGoal, countBills: countBills)
        let saves = moves.filter { $0.assetId == LocalStore.savingsId && $0.kind == .putIn }
        let putAside = saves.filter { Month.of($0.date) == month }.reduce(0) { $0 + $1.amount }
        let savedToday = saves.filter { $0.date == today }.reduce(0) { $0 + $1.amount }
        let leftToday = max(0, plan.dailyBudget - plan.spent(on: today))
        let share = plan.goal == 0 ? 0 : min(1, max(0, Double(putAside) / Double(plan.goal)))
        let gold = Color(hex: 0xFFC400)
        return AnalyticsCard(icon: .piggyBank, tile: Color(hex: 0xFFF9E6), tint: Color(hex: 0xE0A100), title: "Saving goal") {
            HStack(spacing: Space.s20) {
                ZStack {
                    Circle().stroke(Color(hex: 0xFFF3C4), lineWidth: 14)
                    Circle().trim(from: 0, to: share)
                        .stroke(gold, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(Int((share * 100).rounded()))%")
                            .font(AppFont.heading(22, .medium)).foregroundStyle(Tokens.text900)
                            .contentTransition(.numericText())
                        Text("of goal").font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                    }
                }
                .frame(width: 124, height: 124)
                .padding(7)
                VStack(alignment: .leading, spacing: Space.s12) {
                    Button { goalDraft = plan.goal; settingGoal = true } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: Space.s4) {
                                Text(hidden ? "••••" : Self.compact(plan.goal))
                                    .font(AppFont.heading(20, .medium)).foregroundStyle(Tokens.text900)
                                AppIcon(.pencil, size: 14).foregroundStyle(Tokens.grey400)
                            }
                            Text(savingGoal > 0 ? "Goal this month" : "Suggested goal")
                                .font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Saving goal, \(hidden ? "hidden" : Money.format(plan.goal) + " dong")")
                    .accessibilityHint("Change the goal")
                    StatLine(value: hidden ? "••••" : Self.compact(putAside), label: "Put aside")
                    StatLine(value: hidden ? "••••" : Self.compact(plan.dailyBudget), label: "To spend a day")
                }
                Spacer(minLength: 0)
            }
            if period == .day {
                // The picked day against its budget.
                let spent = plan.spent(on: min(anchor, today))
                let left = plan.dailyBudget - spent
                HStack(spacing: Space.s12) {
                    StatLine(value: hidden ? "••••" : Self.compact(spent), label: "Spent this day")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    StatLine(value: hidden ? "••••" : (left < 0 ? "−" : "") + Self.compact(abs(left)),
                             label: left >= 0 ? "Still fine to spend" : "Over the day's budget")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Space.s12)
                .background(Color(hex: 0xFFF9E6), in: .rect(cornerRadius: Corner.c14))
            }
            SavingDots(plan: plan, picked: period == .day ? anchor : nil, color: gold)
            HStack(alignment: .center, spacing: Space.s8) {
                Text("Darker days stayed further under the daily budget.")
                    .font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                Spacer(minLength: Space.s4)
                // Check: bills count in the days. Uncheck: they're taken out again.
                Button {
                    withAnimation(.snappy) { countBills.toggle() }
                } label: {
                    HStack(spacing: Space.s6) {
                        Image(systemName: countBills ? "checkmark.square.fill" : "square")
                            .font(.system(size: 18))
                            .foregroundStyle(countBills ? Tokens.brand600 : Tokens.grey300)
                            .contentTransition(.symbolEffect(.replace))
                        Text("Count bills").font(AppFont.main(12, .medium)).foregroundStyle(Tokens.text700)
                    }
                    .frame(minHeight: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Count bills")
                .accessibilityAddTraits(countBills ? .isSelected : [])
            }
            // Put today's money aside: one tap for what's left of today's budget, or any amount.
            // Tapping the quick save again takes it back.
            if month == Month.of(today) {
                HStack(spacing: Space.s8) {
                    Button {
                        withAnimation(.snappy) {
                            let store = LocalStore(context: context)
                            if savedToday > 0 { store.undoPutAside(on: today) } else { store.putAside(leftToday, date: today) }
                        }
                    } label: {
                        HStack(spacing: Space.s8) {
                            Image(systemName: savedToday > 0 ? "checkmark.circle.fill" : "arrow.down.to.line")
                                .contentTransition(.symbolEffect(.replace))
                            Text(savedToday > 0
                                 ? "Saved today · " + (hidden ? "••••" : Self.compact(savedToday) + "đ")
                                 : leftToday > 0 ? "Save today's " + (hidden ? "••••" : Self.compact(leftToday) + "đ") : "Nothing left today")
                                .lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .font(AppFont.main(14, .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(savedToday > 0 ? Tokens.brand600 : Color(hex: 0xE0A100))
                    .disabled(savedToday == 0 && leftToday == 0)
                    .sensoryFeedback(.success, trigger: savedToday)
                    .accessibilityHint(savedToday > 0 ? "Takes back today's saving" : "Notes what's left of today's budget as saved")
                    Button {
                        saveDraft = nil
                        savingCustom = true
                    } label: {
                        Text("Custom").font(AppFont.main(14, .semibold)).frame(minHeight: 44).padding(.horizontal, Space.s4)
                    }
                    .buttonStyle(.glass)
                }
                Text("Only noted here and on Savings in Finance — no money moves.")
                    .font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
            }
        }
    }

    /// Delivery Time by Carrier style: the biggest single spends.
    private var biggest: some View {
        let top = monthOut.sorted { $0.amount > $1.amount }.prefix(4)
        let maxAmount = top.first?.amount ?? 1
        let colors = [Color(hex: 0x00BA90), Color(hex: 0x00C900), Self.orange, Color(hex: 0xFF4D00)]
        return AnalyticsCard(icon: .receipt, tile: Self.orange.opacity(0.06), tint: Self.orange, title: "Biggest spends") {
            if top.isEmpty { Text("No spending yet").font(AppFont.main(14)).foregroundStyle(Tokens.grey400) }
            ForEach(Array(top.enumerated()), id: \.element.id) { i, e in
                VStack(spacing: Space.s8) {
                    HStack {
                        Text(e.title).font(AppFont.main(14)).foregroundStyle(Tokens.text700).lineLimit(1)
                        Spacer()
                        Text(hidden ? "••••" : Money.format(e.amount) + "đ").font(AppFont.main(14)).foregroundStyle(Tokens.text900)
                    }
                    GeometryReader { g in
                        Capsule().fill(colors[i].opacity(0.13))
                            .overlay(alignment: .leading) {
                                Capsule().fill(colors[i])
                                    .frame(width: max(8, g.size.width * CGFloat(e.amount) / CGFloat(maxAmount)))
                            }
                    }
                    .frame(height: 8)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: - Formatting

    static func monthTitle(_ m: String) -> String {
        let (y, mm, _) = Day.parts(m + "-01")
        return "\(Day.monthsShort[mm - 1]) \(y)"
    }

    /// 18,500,000 → "18.5M", 450,000 → "450K", 0 → "0".
    static func compact(_ n: Int) -> String {
        // A billion and up: "1.44B" reads better than "1443M".
        if n >= 1_000_000_000 {
            let v = Double(n) / 1_000_000_000
            return (v >= 100 ? String(Int(v.rounded())) : String(format: "%.2f", v)
                .replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)) + "B"
        }
        if n >= 1_000_000 {
            let v = Double(n) / 1_000_000
            return (v >= 100 || v == v.rounded() ? String(Int(v.rounded())) : String(format: "%.1f", v)) + "M"
        }
        return n >= 1000 ? "\(n / 1000)K" : "\(n)"
    }

    static func change(_ now: Int, _ before: Int) -> Double? {
        before == 0 ? nil : Double(now - before) / Double(before)
    }

    static func pct(_ v: Double) -> String { String(format: "%.1f%%", v * 100) }

    static func percent(_ part: Int, of whole: Int) -> Int {
        whole == 0 ? 0 : Int((Double(part) / Double(whole) * 100).rounded())
    }

    /// Category colours for the donut (Bills and Other get their own so slices stay apart).
    static func color(_ c: Category) -> Color {
        switch c {
        case .food: Tokens.categoryFood
        case .transport: Tokens.categoryTransport
        case .shopping: Color(hex: 0xFFC400)
        case .bills: Color(hex: 0x00C900)
        case .received: Tokens.categoryReceived
        case .other: Color(hex: 0x00BA90)
        }
    }
}

// MARK: - Card parts (Figma chart template)

/// White card, radius 30, soft shadow; icon tile, title, then the content.
private struct AnalyticsCard<Content: View>: View {
    var icon: Icon
    var tile: Color
    var tint: Color
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            HStack(spacing: Space.s12) {
                AppIcon(icon, size: 20)
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tile, in: .rect(cornerRadius: Corner.c12))
                Text(title).font(AppFont.main(16, .medium)).foregroundStyle(Tokens.text900)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: Space.s4)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            content
        }
        .padding(Space.s20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.bgWhite, in: .rect(cornerRadius: 30))
        .shadow(color: Color(hex: 0x1A1A1A).opacity(0.04), radius: 9, y: 5)
    }
}

/// "1,629,000đ  ↓ 3.9%" — spending going down shows green; going up stays plain grey.
private struct BigNumber: View {
    var value: Int
    var hidden: Bool
    var change: Double?
    var lowerIsGood: Bool
    var note: String = "vs. last month"

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            HStack(alignment: .center, spacing: Space.s8) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(hidden ? "••••••" : Money.format(value))
                        .font(AppFont.heading(32, .medium))
                        .foregroundStyle(Tokens.text900)
                        .contentTransition(.numericText())
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text("đ").font(AppFont.heading(20)).foregroundStyle(Tokens.grey400)
                }
                if let change {
                    let good = lowerIsGood ? change <= 0 : change >= 0
                    Text((change <= 0 ? "↓ " : "↑ ") + AnalyticsView.pct(abs(change)))
                        .font(AppFont.main(12, .medium))
                        .foregroundStyle(good ? Tokens.success : Tokens.text700)
                        .padding(.horizontal, Space.s8)
                        .frame(height: 24)
                        .background(good ? Color(hex: 0xF6FEFC) : Tokens.bg4, in: .capsule)
                }
            }
            if change != nil {
                Text(note).font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
            }
        }
    }
}

/// Three numbers in a row under a chart ("2.4 / Items per order").
private struct Stats: View {
    var items: [(String, String)]
    init(_ items: [(String, String)]) { self.items = items }

    var body: some View {
        HStack(alignment: .top, spacing: Space.s12) {
            ForEach(items, id: \.0) { label, value in
                StatLine(value: value, label: label).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct StatLine: View {
    var value: String
    var label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(AppFont.heading(20, .medium)).foregroundStyle(Tokens.text900).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(AppFont.main(12)).foregroundStyle(Tokens.grey400).lineLimit(1).minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
    }
}

/// White bubble over the picked point ("Week of Oct 12 / $65.48").
struct Tooltip: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
            Text(value).font(AppFont.main(16, .medium)).foregroundStyle(Tokens.text900)
        }
        .padding(.horizontal, Space.s12)
        .padding(.vertical, Space.s8)
        .background(Tokens.bgWhite, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(hex: 0x0D121C).opacity(0.04)))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 5)
    }
}

/// Ringed dot on the picked point.
private struct PickedDot: View {
    var color: Color
    var body: some View {
        Circle().fill(.white).frame(width: 12, height: 12)
            .overlay(Circle().strokeBorder(color, lineWidth: 2.5))
    }
}

/// What the months line shows.
enum MoneySeries: String, CaseIterable, Identifiable {
    case income = "Income", expenses = "Expenses", kept = "Kept"
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .income: Tokens.brand500
        case .expenses: Color(hex: 0xFF8000)
        case .kept: Color(hex: 0x2E90FA)
        }
    }
}

/// The detail card's body: a pie of the group's kinds with a legend (tap a kind to see
/// its lines), then one soft tip for keeping more.
private struct NeedDetail: View {
    var need: SpendNeed
    var lines: [Entry]
    var hidden: Bool
    @State private var kind: SpendKind?

    var body: some View {
        let kinds = Dictionary(grouping: lines, by: SpendKind.of)
            .map { (kind: $0.key, lines: $0.value, sum: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.sum > $1.sum }
        let total = max(kinds.reduce(0) { $0 + $1.sum }, 1)
        // Tips go to easy trims (coffee, milk tea, orders), never to time with people.
        let byName = Dictionary(grouping: lines.filter { SpendKind.of($0) != .social }, by: \.title)
            .map { (name: $0.key, sum: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.sum > $1.sum }
        VStack(alignment: .leading, spacing: Space.s16) {
            if kinds.isEmpty {
                Text("Nothing in this group here.").font(AppFont.main(14)).foregroundStyle(Tokens.grey400)
            } else {
                HStack(alignment: .center, spacing: Space.s20) {
                    Chart(kinds, id: \.kind) { k in
                        SectorMark(angle: .value("Spent", k.sum), angularInset: 2)
                            .foregroundStyle(k.kind.color)
                            .opacity(kind == nil || kind == k.kind ? 1 : 0.3)
                            .cornerRadius(6)
                    }
                    .chartLegend(.hidden)
                    .frame(width: 130, height: 130)
                    VStack(alignment: .leading, spacing: Space.s4) {
                        ForEach(kinds, id: \.kind) { k in
                            Button {
                                withAnimation(.snappy) { kind = kind == k.kind ? nil : k.kind }
                            } label: {
                                HStack(spacing: Space.s8) {
                                    Circle().fill(k.kind.color).frame(width: 10, height: 10)
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(k.kind.rawValue).font(AppFont.main(14, kind == k.kind ? .semibold : .medium))
                                            .foregroundStyle(Tokens.text700).lineLimit(1).minimumScaleFactor(0.8)
                                        Text(hidden ? "••••" : AnalyticsView.compact(k.sum) + "đ")
                                            .font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                                    }
                                    Spacer(minLength: 2)
                                    Text("\(AnalyticsView.percent(k.sum, of: total))%")
                                        .font(AppFont.main(14, .medium)).foregroundStyle(Tokens.text900)
                                }
                                .padding(.horizontal, Space.s6)
                                .frame(minHeight: 40)
                                .background(kind == k.kind ? k.kind.color.opacity(0.12) : .clear, in: .rect(cornerRadius: Corner.c12))
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(k.kind.rawValue), \(AnalyticsView.percent(k.sum, of: total)) percent")
                            .accessibilityAddTraits(kind == k.kind ? .isSelected : [])
                        }
                    }
                }
                if let picked = kinds.first(where: { $0.kind == kind }) {
                    ItemList(title: picked.kind.rawValue, lines: picked.lines, color: picked.kind.color, hidden: hidden)
                        .transition(.opacity)
                } else {
                    Text("Tap a kind to see what's in it.").font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                }
            }
            if let tip = tip(byName.first) {
                HStack(alignment: .top, spacing: Space.s8) {
                    AppIcon(.lightbulb, size: 18).foregroundStyle(Color(hex: 0xE0A100))
                    Text(tip).font(AppFont.main(14)).foregroundStyle(Tokens.text700)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Space.s12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: 0xFFF9E6), in: .rect(cornerRadius: Corner.c14))
            }
        }
    }

    /// One gentle idea for keeping more — never for essentials.
    private func tip(_ top: (name: String, sum: Int)?) -> String? {
        guard need != .essential, let top, top.sum > 0 else { return nil }
        let keep = hidden ? "a bit" : "about " + AnalyticsView.compact(top.sum / 2) + "đ"
        return need == .optional
            ? "Half as much “\(top.name)” and you'd keep \(keep) more."
            : "Trim “\(top.name)” by half and you'd keep \(keep) more."
    }
}

/// What's inside the picked kind or source: a small header ("IN SALARY · 2 ITEMS"), then a
/// card per name, iOS-style (grouped fill, soft continuous corners, no border), two to a row —
/// a single one spans the row.
private struct ItemList: View {
    var title: String
    var lines: [Entry]
    var color: Color
    var hidden: Bool

    var body: some View {
        let rows = Dictionary(grouping: lines, by: \.title)
            .map { (name: $0.key, sum: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.sum > $1.sum }
        let shown = Array(rows.prefix(8))
        let columns = Array(repeating: GridItem(.flexible(), spacing: Space.s8), count: shown.count == 1 ? 1 : 2)
        VStack(alignment: .leading, spacing: Space.s8) {
            Text("In \(title) · \(rows.count) \(rows.count == 1 ? "item" : "items")".uppercased())
                .font(AppFont.main(11, .semibold))
                .tracking(0.4)
                .foregroundStyle(Tokens.grey400)
                .padding(.leading, Space.s4)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: columns, spacing: Space.s8) {
                ForEach(shown, id: \.name) { r in
                    VStack(alignment: .leading, spacing: Space.s6) {
                        HStack(spacing: Space.s6) {
                            Circle().fill(color).frame(width: 8, height: 8)
                            Text(r.name).font(AppFont.main(14, .medium)).foregroundStyle(Tokens.text700)
                                .lineLimit(1).minimumScaleFactor(0.8)
                        }
                        Text(hidden ? "••••" : Money.format(r.sum) + "đ")
                            .font(AppFont.heading(18, .semibold)).foregroundStyle(Tokens.text900)
                            .monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, Space.s16)
                    .padding(.vertical, Space.s12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Tokens.bg4.opacity(0.6), in: .rect(cornerRadius: Corner.c16, style: .continuous))
                    .accessibilityElement(children: .combine)
                }
            }
            if rows.count > 8 {
                Text("and \(rows.count - 8) more").font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                    .padding(.leading, Space.s4)
            }
        }
    }
}
