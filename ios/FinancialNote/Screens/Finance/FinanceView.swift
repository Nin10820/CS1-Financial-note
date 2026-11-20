import Charts
import SwiftData
import SwiftUI

/// Finance — Figma High Fi 2 › Asset (943:25860 overview, 943:25978 scrolled, 943:26145 family).
/// Everything here is what the user wrote down; the app never connects to a bank.
struct FinanceView: View {
    @Environment(AppState.self) private var app
    @Query(sort: \Asset.amount, order: .reverse) private var assets: [Asset]
    @Query(sort: \AssetMove.date, order: .reverse) private var moves: [AssetMove]
    @Query(sort: \CareGift.date, order: .reverse) private var care: [CareGift]
    @Query(sort: \WorthPoint.month) private var worth: [WorthPoint]
    @Query(sort: \Bill.createdAt) private var bills: [Bill]
    @Query(sort: \FamilyLoan.date, order: .reverse) private var loans: [FamilyLoan]
    @Query private var profiles: [Profile]
    @Query private var entries: [Entry]

    @State private var view: FinanceTab = .overview
    @State private var adding = false
    @State private var path: [Route] = []
    @State private var pageHeight: CGFloat = 0
    /// The month touched on the Total Asset line (nil: now).
    @State private var pickedMonth: String?
    /// The group tapped on Overview's pie: the ring shows its share.
    @State private var overviewGroup: AssetKind?
    /// How far back the Total Asset line goes.
    @State private var worthRange: WorthRange = .sixMonths
    /// The monthly saving goal from Today (0: use the suggestion).
    @AppStorage("savingGoal") private var savingGoal = 0

    enum FinanceTab: String, CaseIterable { case overview = "Overview", total = "Total Asset", debt = "Debt" }
    enum Route: Hashable { case family, yourself, asset(String) }

    var body: some View {
        @Bindable var app = app
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s16) {
                    Picker("Finance view", selection: $view) {
                        ForEach(FinanceTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 6)
                    switch view {
                    case .overview: overview
                    case .total: TotalAssetsSection(assets: assets, moves: moves, bills: bills, loans: loans, today: app.today,
                                                    hidden: app.assetsHidden) { adding = true }
                    case .debt: DebtSection(bills: bills, loans: loans, today: app.today, hidden: app.assetsHidden)
                    }
                }
                .padding(.horizontal, Space.s20)
                .frame(minHeight: pageHeight, alignment: .top)
                .pageSwipe(back: { turn(-1) }, forward: { turn(1) })
                .padding(.bottom, 96)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { pageHeight = $0 }
            .onChange(of: app.addAssetRequest) { _, _ in adding = true }
            .modifier(MinimizesTabBar())
            .background(Tokens.canvas)
            .navigationTitle("Finance")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button(app.assetsHidden ? "Show amounts" : "Hide amounts",
                               systemImage: app.assetsHidden ? "eye" : "eye.slash") { app.assetsHidden.toggle() }
                        Button("For your family", systemImage: "person.2") { path.append(.family) }
                            .disabled(care.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("More")
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) { ProfileButton() }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .family: RevealPage(tint: .family) { FamilyView(care: care, birthYear: profiles.first?.birthYear) }
                case .yourself: RevealPage(tint: .yourself) { YourselfView(entries: entries, bills: bills) }
                case .asset(let id): AssetDetailView(assetId: id)
                }
            }
            .sheet(isPresented: $adding) { AddAssetSheet().sheetSurface() }
        }
    }

    /// Swipe between Overview, Total Asset and Debt, like tapping the segments.
    private func turn(_ n: Int) {
        let all = FinanceTab.allCases
        guard let i = all.firstIndex(of: view), all.indices.contains(i + n) else { return }
        animate { view = all[i + n] }
    }

    // MARK: - Overview

    @ViewBuilder
    private var overview: some View {
        if assets.isEmpty {
            VStack(spacing: Space.s12) {
                Text("Nothing written down yet")
                    .font(AppFont.main(16, .semibold))
                    .foregroundStyle(Tokens.text900)
                Text("Add what you keep — cash, savings, gold, a fund — and this page adds it up. Nothing connects to your bank.")
                    .font(AppFont.main(14))
                    .foregroundStyle(Tokens.grey400)
                    .multilineTextAlignment(.center)
                Button("Add an asset", systemImage: "plus") { adding = true }
                    .font(AppFont.main(14, .semibold))
                    .buttonStyle(.glassProminent)
                    .tint(Tokens.action)
            }
            .frame(maxWidth: .infinity)
            .padding(Space.s24)
            .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c20))
        } else {
            // Money others owe you (Owed) is still yours, so it counts.
            let shares = AssetMath.shares(assets)
            let growth = FinanceText.growth(worth.map { ($0.month, $0.value) })
            let owed = BillMath.monthSummary(bills, month: Month.of(app.today)).totalRemaining + LoanMath.owed(loans, today: app.today)
            let series = WorthChart.series(worth)
            let picked = series.first { $0.month == pickedMonth }
            // Money put in, by month: a dot on the line's bar for each month you added some.
            let deposits = Dictionary(grouping: moves.filter { $0.kind == .putIn }) { Month.of($0.date) }
                .mapValues { $0.reduce(0) { $0 + $1.amount } }
            // No card: the amount sits on the page and the line runs edge to edge, like View Analysis.
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    // Total assets as a story over time: touch a month on the line to read it here.
                    TotalBlock(total: picked?.value ?? shares.total, month: picked.map { FinanceText.monthLabel($0.month) },
                               growth: picked == nil ? growth : nil, putIn: picked.flatMap { deposits[$0.month] },
                               hidden: app.assetsHidden)
                    Spacer(minLength: Space.s8)
                    Menu {
                        Picker("Show", selection: $worthRange) {
                            ForEach(WorthRange.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                    } label: {
                        HStack(spacing: Space.s4) {
                            Text(worthRange.short)
                            AppIcon(.caretUpDown, size: 14, relativeTo: .caption)
                        }
                        .font(AppFont.capture(.medium))
                        .foregroundStyle(Tokens.text700)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                    }
                    .accessibilityLabel("Show \(worthRange.label)")
                    .onChange(of: worthRange) { _, _ in pickedMonth = nil }
                }
                if series.count > 1 {
                    WorthChart(points: series, deposits: deposits, months: worthRange.months, hidden: app.assetsHidden,
                               picked: $pickedMonth)
                        .padding(.horizontal, -Space.s20)
                        .padding(.top, Space.s8)
                        .padding(.bottom, Space.s20)
                } else {
                    Text("The line appears after your second month of updates.")
                        .font(AppFont.main(12))
                        .foregroundStyle(Tokens.grey400)
                        .padding(.vertical, Space.s16)
                }
                // Today's net worth: what you own less what you owe.
                NetWorthBar(assets: shares.total, owed: owed, hidden: app.assetsHidden)
                    .padding(Space.s16)
                    .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c20))
            }

            // Every month money went in, year by year.
            if moves.contains(where: { $0.kind == .putIn }) {
                // The plan is the saving goal set on Today (or its suggestion).
                DepositDots(moves: moves, today: app.today,
                            plan: savingGoal > 0 ? savingGoal
                                : SavingPlan(month: Month.of(app.today), today: app.today, entries: entries, goalSetting: 0).suggested,
                            hidden: app.assetsHidden)
                    .padding(.top, Space.s8)
            }

            // What you own by group, and who you owe. The lists live on Total Asset and Debt.
            AssetsPie(assets: assets, hidden: app.assetsHidden, picked: $overviewGroup)
                .background(Tokens.card, in: .rect(cornerRadius: Corner.c20))
                .padding(.top, Space.s8)
            DebtPie(bills: bills, loans: loans, today: app.today, hidden: app.assetsHidden)
                .background(Tokens.card, in: .rect(cornerRadius: Corner.c20))

            // What went to the people you love, and into yourself.
            let selfTotal = SelfMath.lines(entries: entries, bills: bills).reduce(0) { $0 + $1.amount }
            VStack(alignment: .leading, spacing: Space.s8) {
                FinanceSectionTitle(title: "Invested in people") { EmptyView() }
                HStack(spacing: Space.s12) {
                    Button { path.append(.family) } label: {
                        LifeCard(tint: .family, title: "Your family", amount: care.reduce(0) { $0 + $1.amount },
                                 sub: care.isEmpty ? "Nothing yet" : FinanceText.since(careDates: care.map(\.date),
                                     birthYear: profiles.first?.birthYear, today: app.today),
                                 hidden: app.assetsHidden)
                    }
                    Button { path.append(.yourself) } label: {
                        LifeCard(tint: .yourself, title: "Yourself", amount: selfTotal,
                                 sub: "Learning, moving and health", hidden: app.assetsHidden)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.top, Space.s8)
        }
    }
}

// MARK: - Total + allocation

private struct TotalBlock: View {
    var total: Int
    /// The month touched on the line, or nil for now.
    var month: String?
    var growth: Int?
    /// Money put in during the touched month, shown where the growth badge sits.
    var putIn: Int? = nil
    var hidden: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            Text(month.map { "Total Asset · \($0)" } ?? "Total Asset")
                .font(AppFont.main(14, .medium))
                .foregroundStyle(month == nil ? Tokens.text700 : Tokens.brand600)
                .contentTransition(.opacity)
            HStack(alignment: .firstTextBaseline, spacing: Space.s6) {
                Text(hidden ? "••••••" : Money.format(total))
                    .font(AppFont.amount(36))
                    .monospacedDigit()
                    .foregroundStyle(Tokens.text900)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("đ").font(AppFont.currency(for: 36)).foregroundStyle(Tokens.grey400)
            }
            .accessibilityElement(children: .combine)
            // On its own line under the amount.
            if let growth, !hidden { GrowthBadge(pct: growth) }
            if let putIn {
                Label(hidden ? "Put in" : "Put in " + AnalyticsView.compact(putIn) + "đ", systemImage: "plus")
                    .font(AppFont.main(12, .semibold))
                    .foregroundStyle(Tokens.brand700)
                    .padding(.horizontal, Space.s6)
                    .padding(.vertical, 2)
                    .background(Tokens.brand100, in: .rect(cornerRadius: Corner.c6))
                    .accessibilityLabel(hidden ? "Money put in this month" : "Put in \(Money.format(putIn)) dong this month")
            }
        }
    }
}

/// Net worth today — total assets less what's owed (installments and family loans) — as one bar
/// split between the two, with the amounts.
private struct NetWorthBar: View {
    var assets: Int
    var owed: Int
    var hidden: Bool

    var body: some View {
        let net = assets - owed
        let whole = max(assets, 1)
        let netPct = Int((Double(max(net, 0)) / Double(whole) * 100).rounded())
        let debtColor = Color(hex: 0xF97066)
        VStack(alignment: .leading, spacing: Space.s12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Net worth").font(AppFont.main(14, .medium)).foregroundStyle(Tokens.text700)
                Spacer()
                Text(hidden ? "••••••" : (net < 0 ? "-" : "") + Money.format(abs(net)) + "đ")
                    .font(AppFont.heading(20, .semibold)).foregroundStyle(Tokens.text900).monospacedDigit()
            }
            GeometryReader { g in
                let w = g.size.width - (owed > 0 && net > 0 ? 4 : 0)
                HStack(spacing: 4) {
                    if net > 0 {
                        RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Tokens.brand500)
                            .frame(width: max(8, w * CGFloat(netPct) / 100))
                    }
                    if owed > 0 {
                        RoundedRectangle(cornerRadius: 6, style: .continuous).fill(debtColor)
                    }
                }
            }
            .frame(height: 24)
            .accessibilityHidden(true)
            HStack(spacing: Space.s16) {
                legend(Tokens.brand500, "Net worth", "\(netPct)%")
                legend(debtColor, "Debt " + (hidden ? "" : AnalyticsView.compact(owed)), "\(100 - netPct)%")
            }
            Text("All you own, less installments and family loans still owed.")
                .font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
        }
    }

    private func legend(_ color: Color, _ name: String, _ value: String) -> some View {
        HStack(spacing: Space.s6) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
            Text(name).foregroundStyle(Tokens.text700)
            Text(value).foregroundStyle(Tokens.text900)
        }
        .font(AppFont.main(12, .medium))
        .accessibilityElement(children: .combine)
    }
}

struct GrowthBadge: View {
    var pct: Int

    var body: some View {
        Label("\(abs(pct))%", systemImage: pct < 0 ? "arrow.down.right" : "arrow.up.right")
            .font(AppFont.main(12, .semibold))
            .foregroundStyle(Tokens.brand700)
            .padding(.horizontal, Space.s6)
            .padding(.vertical, 2)
            .background(Tokens.brand100, in: .rect(cornerRadius: Corner.c6))
            .accessibilityLabel("\(pct < 0 ? "Down" : "Up") \(abs(pct)) percent on a year ago")
    }
}

// MARK: - Net-worth chart (Swift Charts)

/// Total assets month by month, edge to edge in the card (no scale): a soft line over a
/// fading fill, the last eight months along the bottom. The picked month (the latest unless you
/// touch another) gets a light column, a ringed dot and its amount in a green pill.
/// How far back the Total Asset line goes.
enum WorthRange: CaseIterable {
    case sixMonths, oneYear, threeYears, all
    var label: String {
        switch self {
        case .sixMonths: "Last 6 months"
        case .oneYear: "Last year"
        case .threeYears: "Last 3 years"
        case .all: "All time"
        }
    }
    var short: String {
        switch self {
        case .sixMonths: "6 months"
        case .oneYear: "1 year"
        case .threeYears: "3 years"
        case .all: "All"
        }
    }
    /// Months shown, nil for all.
    var months: Int? {
        switch self {
        case .sixMonths: 6
        case .oneYear: 12
        case .threeYears: 36
        case .all: nil
        }
    }
}

private struct WorthChart: View {
    struct Point: Hashable { var month: String; var value: Int }
    var points: [Point]
    /// Money put in by month ("2021-03": 5,000,000): each one is a dot on the bar under the line.
    var deposits: [String: Int]
    var months: Int?
    var hidden: Bool
    /// The touched month, shared with the amount above (nil: the latest).
    @Binding var picked: String?

    /// Every month from the first point to the last; a month nobody wrote down keeps the one before,
    /// so 2020 to now reads as real time, not as the few months that have a point.
    static func series(_ points: [WorthPoint]) -> [Point] {
        let sorted = points.sorted { $0.month < $1.month }
        guard let first = sorted.first, let last = sorted.last else { return [] }
        var out: [Point] = []
        var i = 0, month = first.month, value = first.value
        while month <= last.month {
            while i < sorted.count && sorted[i].month <= month { value = sorted[i].value; i += 1 }
            out.append(Point(month: month, value: value))
            month = Month.add(month, 1)
        }
        return out
    }

    var body: some View {
        let shown = Array(points.suffix(max(months ?? points.count, 2)))
        // Up to a year: the month. Up to three years: "Apr 25". Longer: just the year, on its January.
        let long = shown.count > 12, veryLong = shown.count > 36
        let year = { (m: String) in Day.parts(m + "-01").0 }
        let label = { (m: String) -> String in
            let (y, mm, _) = Day.parts(m + "-01")
            if veryLong { return String(y) }
            return Day.monthsShort[mm - 1] + (long ? " " + String(String(y).suffix(2)) : "")
        }
        // A few labels along the bottom (every month up to seven, else at most five), always the last.
        // All time: each year once (every other year past eight), the first one too if it starts early in the year.
        let years = Set(shown.map { year($0.month) }).count
        let yearStep = years > 8 ? 2 : 1
        let firstYear = shown.first.map { year($0.month) } ?? 0
        let step = shown.count <= 7 ? 1 : max(1, Int((Double(shown.count) / 5).rounded(.up)))
        let tick = { (i: Int) -> Bool in
            guard veryLong else { return (shown.count - 1 - i) % step == 0 }
            let m = shown[i].month, y = year(m)
            guard (y - firstYear) % yearStep == 0 else { return false }
            return m.hasSuffix("-01") || (i == 0 && Day.parts(m + "-01").1 <= 6)
        }
        let focus = shown.first { $0.month == picked } ?? shown.last!
        let lo = shown.map(\.value).min() ?? 0, hi = shown.map(\.value).max() ?? 1
        let pad = max((hi - lo) / 3, hi / 40, 1)
        // The bottom of the chart never goes under 0đ, so a month at 0đ sits on the floor.
        let base = lo >= 0 ? max(lo - pad, 0) : lo - pad
        let dots = shown.filter { deposits[$0.month] != nil }.count
        VStack(spacing: Space.s12) {
            Chart {
                // Light column behind the picked month.
                RectangleMark(x: .value("Month", focus.month), width: .ratio(0.7))
                    .foregroundStyle(LinearGradient(colors: [Tokens.brand500.opacity(0), Tokens.brand500.opacity(0.22)],
                                                    startPoint: .top, endPoint: .bottom))
                ForEach(shown, id: \.month) { p in
                    AreaMark(x: .value("Month", p.month), yStart: .value("Base", base), yEnd: .value("Worth", p.value))
                        .foregroundStyle(LinearGradient(colors: [Tokens.brand500.opacity(0.22), Tokens.brand500.opacity(0)],
                                                        startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Month", p.month), y: .value("Worth", p.value))
                        .foregroundStyle(Tokens.brand500)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .interpolationMethod(.catmullRom)
                }
                PointMark(x: .value("Month", focus.month), y: .value("Worth", focus.value))
                    .symbol {
                        Circle().fill(Tokens.brand500).frame(width: 12, height: 12)
                            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    }
                    .annotation(position: .top, spacing: 10, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        if !hidden {
                            Text(AnalyticsView.compact(focus.value) + "đ")
                                .font(AppFont.main(13, .semibold))
                                .foregroundStyle(Color(hex: 0x0D121C))
                                .padding(.horizontal, Space.s12)
                                .frame(height: 30)
                                .background(Color(hex: 0xA4DA7C), in: .capsule)
                        }
                    }
            }
            // Just a little room over the highest month: the 44 pt on top already holds the amount pill.
            .chartYScale(domain: base...(hi + max((hi - base) / 20, 1)))
            // Months in order (the picked month's column is drawn first, and would lead otherwise).
            .chartXScale(domain: shown.map(\.month), range: .plotDimension(padding: 8))
            .chartYAxis(.hidden)
            .chartXAxis(.hidden)
            // A tap or a drag picks the month under the finger; it stays when the finger lifts.
            // The latest month means "now".
            .chartOverlay { proxy in
                Rectangle().fill(.clear).contentShape(.rect)
                    .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                        guard let key: String = proxy.value(atX: g.location.x),
                              let p = shown.first(where: { $0.month == key }) else { return }
                        let next = p.month == shown.last?.month ? nil : p.month
                        if next != picked { withAnimation(.snappy) { picked = next } }
                    })
            }
            .chartPlotStyle { $0.padding(.top, 44) }
            .frame(height: 190)
            .noPageSwipe()
            // The bar under the line: a dot for every month you put money in; the picked one rings.
            if dots > 0 {
                ZStack {
                    Capsule().fill(Tokens.bd1).frame(height: 2)
                    HStack(spacing: 0) {
                        ForEach(shown, id: \.month) { p in
                            ZStack {
                                if deposits[p.month] != nil {
                                    let on = p.month == focus.month
                                    Circle().fill(Tokens.brand500)
                                        .frame(width: on ? 10 : 6, height: on ? 10 : 6)
                                        .overlay { if on { Circle().strokeBorder(Tokens.canvas, lineWidth: 2) } }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(height: 10)
                .padding(.horizontal, Space.s8)
                // The bar's line sits right on the chart's floor (cancels the stack's gap and half the bar).
                .padding(.top, -(Space.s12 + 5))
                .accessibilityHidden(true)
            }
            // Months along the bottom; the picked one in green (all time: the picked month's year).
            HStack(spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.element.month) { i, p in
                    let on = veryLong ? year(p.month) == year(focus.month) : p.month == focus.month
                    Text(tick(i) ? label(p.month) : "")
                        .font(AppFont.main(12, on ? .semibold : .medium))
                        .foregroundStyle(on ? Tokens.brand600 : Tokens.text700)
                        .lineLimit(1).fixedSize()
                        .frame(maxWidth: .infinity, alignment: !veryLong && i == shown.count - 1 ? .trailing : .center)
                }
            }
            .padding(.horizontal, Space.s8)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .animation(.snappy, value: shown.count)
        .accessibilityLabel("Total assets over the last \(shown.count) months, money put in during \(dots) of them")
        .accessibilityValue(hidden ? "Hidden" : "\(FinanceText.monthLabel(focus.month)), \(Money.format(focus.value)) dong")
    }
}

// MARK: - History

/// A coloured tile with a short mark ("Au", "fm", "TP"…) for an asset row.
struct AssetTile: View {
    var icon: AssetIcon
    var size: CGFloat = 36
    var round = false

    var body: some View {
        AssetGlyph(icon: icon, size: size * 0.45)
            .frame(width: size, height: size)
            .background(Tokens.assetTile(icon), in: round ? AnyShape(.circle) : AnyShape(.rect(cornerRadius: Corner.c8)))
            .accessibilityHidden(true)
    }
}

/// What's drawn on an asset tile: a symbol for the kind of money (₫, $, ₿, a chart…),
/// "Au" for gold, a piggy bank for the saving goal.
struct AssetGlyph: View {
    var icon: AssetIcon
    var size: CGFloat

    var body: some View {
        Group {
            if let symbol = icon.symbol {
                Image(systemName: symbol).font(.system(size: size, weight: .bold))
            } else if icon == .piggy {
                AppIcon(.piggyBank, size: size * 1.15)
            } else {
                Text(icon.mark).font(AppFont.main(size * 0.8, .bold))
            }
        }
        .foregroundStyle(icon == .gold ? Color(hex: 0x0D121C) : .white)
    }
}

struct MoneyRow: View {
    var title: String
    var sub: String
    var amount: Int
    var sign: String = ""
    var icon: AssetIcon?
    var hidden: Bool
    /// Opens something (the asset) when tapped.
    var chevron = false

    var body: some View {
        HStack(spacing: Space.s12) {
            if let icon { AssetTile(icon: icon) }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppFont.main(14, .semibold)).foregroundStyle(Tokens.text900)
                Text(sub).font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
            }
            Spacer()
            AmountText(value: amount, sign: sign, hidden: hidden)
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.grey300)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, Space.s8)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Total Asset and Debt

/// Total Asset — where values get updated: net worth on top (assets less installments still
/// owed), then the table with Now and Put in as buttons — tap Now to write down today's worth,
/// Put in to add money. Every change keeps its date, so the gains follow on their own.
private struct TotalAssetsSection: View {
    var assets: [Asset]
    var moves: [AssetMove]
    var bills: [Bill]
    var loans: [FamilyLoan]
    var today: String
    var hidden: Bool
    /// The page's top already shows net worth (both layouts), so this card can step aside.
    var onAdd: () -> Void
    @State private var quick: QuickMove?
    /// The group picked on the pie's legend: the list below shows only it.
    @State private var group: AssetKind?
    @State private var showHistory = false

    var body: some View {
        // Everything you own, money others owe you included. Debt isn't taken off here:
        // that's Net worth on Overview.
        let worth = assets.reduce(0) { $0 + $1.amount }
        let putIn = assets.reduce(0) { $0 + (AssetMath.growth($1, moves: moves)?.putIn ?? $1.amount) }
        let gain = worth - putIn
        VStack(alignment: .leading, spacing: Space.s24) {
            // Total asset on top; underneath, what went into the assets and how they moved,
            // then the groups, in one card.
            let pct = putIn > 0 ? Double(gain) / Double(putIn) * 100 : 0
            JoinedCard {
                StatCard(label: "Total asset", amount: worth, hidden: hidden, stats: [
                    ("Put in", hidden ? "•••" : AnalyticsView.compact(putIn), false),
                    (gain < 0 ? "Loss" : "Gain", hidden ? "•••" : (gain < 0 ? "−" : "+") + AnalyticsView.compact(abs(gain)), gain > 0),
                    ("Change", (gain < 0 ? "−" : "+") + String(format: "%.1f%%", abs(pct)), gain > 0),
                ])
            } bottom: {
                AssetsPie(assets: assets, hidden: hidden, picked: $group)
            }

            HistoryLink(sub: Self.historySub(moves.map(\.date))) { showHistory = true }
                .padding(.top, Space.s8 - Space.s24) // 8 pt under the card above

            HoldingsTable(assets: group.map { g in assets.filter { $0.kind == g } } ?? assets, moves: moves, hidden: hidden,
                          editable: true, title: group?.label ?? "Assets") { asset, kind in
                quick = QuickMove(asset: asset, kind: kind)
            }

        }
        .sheet(item: $quick) { q in QuickMoveSheet(move: q, moves: moves, today: today).sheetSurface() }
        .sheet(isPresented: $showHistory) { AssetHistorySheet(moves: moves, hidden: hidden).sheetSurface() }
    }

    /// "12 changes · last 16 Nov 2026"
    static func historySub(_ dates: [String]) -> String {
        guard let last = dates.max() else { return "Nothing yet" }
        return "\(dates.count) change\(dates.count == 1 ? "" : "s") · last " + HoldingsTable.shortDay(last)
    }
}

/// The asset sheet as a list (like a subscriptions list): a round tile, the name with its gain
/// or loss under it, and what it's worth now with what went in under that. Read-only on
/// Overview (a row opens the asset); on Total Asset the amount is a button for a quick update.
struct HoldingsTable: View {
    var assets: [Asset]
    var moves: [AssetMove]
    var hidden: Bool
    var editable = false
    var title = "Assets"
    var onQuick: (Asset, AssetMoveKind) -> Void = { _, _ in }

    var body: some View {
        let rows = assets.map { a in (asset: a, putIn: AssetMath.growth(a, moves: moves)?.putIn ?? a.amount) }
        VStack(alignment: .leading, spacing: Space.s8) {
            FinanceSectionTitle(title: title) {
                if !editable {
                    Text("\(rows.count) \(rows.count == 1 ? "asset" : "assets")")
                        .font(AppFont.table(12)).foregroundStyle(Tokens.grey400)
                }
            }
            VStack(spacing: 0) {
                if rows.isEmpty {
                    Text("Nothing here yet.").font(AppFont.table(12)).foregroundStyle(Tokens.grey400).padding(.vertical, Space.s16)
                }
                ForEach(Array(rows.enumerated()), id: \.element.asset.id) { i, r in
                    if i > 0 { Divider().overlay(Tokens.bd0).padding(.leading, 56) }
                    row(r.asset, putIn: r.putIn)
                }
            }
            .padding(.horizontal, Space.s16)
            .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c20))
        }
    }

    private func row(_ a: Asset, putIn: Int) -> some View {
        HStack(spacing: Space.s12) {
            NavigationLink(value: FinanceView.Route.asset(a.id)) {
                HStack(spacing: Space.s12) {
                    AssetTile(icon: a.icon, size: 40, round: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.name).font(AppFont.table(15, .semibold)).foregroundStyle(Tokens.text900).lineLimit(1)
                        Text("\(hidden ? "" : "in " + AnalyticsView.compact(putIn) + " · ")\(HoldingsTable.shortDay(a.updatedOn))")
                            .font(AppFont.table(12)).foregroundStyle(Tokens.grey400).lineLimit(1)
                    }
                    Spacer(minLength: Space.s4)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens its history")
            Button { onQuick(a, .value) } label: {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(hidden ? "•••" : Money.format(a.amount) + "đ")
                        .font(AppFont.heading(16, .semibold)).foregroundStyle(Tokens.text900)
                    gainLine(a.amount - putIn, of: putIn)
                }
                .monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.8)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            // Read-only on Overview without greying the amount out.
            .allowsHitTesting(editable)
            .accessibilityLabel("\(a.name), " + (hidden ? "amount hidden" : "worth \(Money.format(a.amount)) dong, put in \(Money.format(putIn)) dong"))
            .accessibilityHint(editable ? "Update what it's worth" : "")
        }
        .padding(.vertical, Space.s12)
    }

    /// "+22.2M · +25%" in green, "−33.3M · −31%" in grey (no red alarms), "No change" when flat.
    private func gainLine(_ change: Int, of putIn: Int) -> some View {
        let pct = putIn > 0 ? Int((Double(change) / Double(putIn) * 100).rounded()) : 0
        let text = change == 0 ? "No change"
            : (change > 0 ? "+" : "−") + (hidden ? "•••" : AnalyticsView.compact(abs(change)))
              + (putIn > 0 ? " · " + (pct == 0 ? "<1%" : (change > 0 ? "+" : "−") + "\(abs(pct))%") : "")
        return Text(text)
            .font(AppFont.table(12, .medium))
            .foregroundStyle(change > 0 ? Tokens.success : Tokens.grey400)
            .monospacedDigit()
    }

    /// "16 Nov" — this year's dates without the year.
    static func shortDay(_ iso: String) -> String {
        let (y, m, d) = Day.parts(iso)
        return "\(d) \(Day.monthsShort[m - 1])" + (String(y) == String(Day.today().prefix(4)) ? "" : " \(y)")
    }
}

/// What the quick sheet is for: today's worth of an asset, or money put in.
struct QuickMove: Identifiable {
    var asset: Asset
    var kind: AssetMoveKind
    var id: String { asset.id + kind.rawValue }
}

/// Quick update from the table: pick what happened — new worth, money put in or taken out —
/// see the asset's put in / now / gain change as you type, pick the day (today by default),
/// and save. It goes into the asset's history like any other move.
struct QuickMoveSheet: View {
    var move: QuickMove
    var moves: [AssetMove]
    var today: String
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var kind: AssetMoveKind
    @State private var value: Int?
    @State private var date: Date

    init(move: QuickMove, moves: [AssetMove], today: String) {
        self.move = move
        self.moves = moves
        self.today = today
        _kind = State(initialValue: move.kind)
        _date = State(initialValue: Day.date(today))
    }

    var body: some View {
        let a = move.asset
        let putIn = AssetMath.growth(a, moves: moves)?.putIn ?? a.amount
        let typed = value ?? 0
        // What the asset would look like after saving.
        let after: (putIn: Int, now: Int) = switch kind {
        case .value: (putIn, value ?? a.amount)
        case .putIn: (putIn + typed, a.amount + typed)
        case .takeOut: (putIn - min(typed, a.amount), a.amount - min(typed, a.amount))
        }
        NavigationStack {
            VStack(alignment: .leading, spacing: Space.s16) {
                Picker("What happened", selection: $kind) {
                    Text("Update value").tag(AssetMoveKind.value)
                    Text("Put in").tag(AssetMoveKind.putIn)
                    Text("Take out").tag(AssetMoveKind.takeOut)
                }
                .pickerStyle(.segmented)
                .onChange(of: kind) { _, _ in value = nil }

                VStack(alignment: .leading, spacing: Space.s4) {
                    Text(prompt(a.name)).font(AppFont.main(14)).foregroundStyle(Tokens.grey400)
                    // The current worth shows greyed until you type; typing starts a fresh number.
                    HStack(alignment: .firstTextBaseline, spacing: Space.s4) {
                        Text(Money.format(value ?? (kind == .value ? a.amount : 0)))
                            .font(AppFont.heading(40, .medium))
                            .foregroundStyle(value == nil ? Tokens.grey300 : Tokens.text900)
                            .monospacedDigit().contentTransition(.numericText())
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Text("đ").font(AppFont.heading(28)).foregroundStyle(Tokens.grey400)
                    }
                }

                // Put in / Now / Gain, before → after.
                HStack(spacing: Space.s8) {
                    summary("Put in", putIn, after.putIn)
                    summary("Now", a.amount, after.now)
                    summary("Gain", a.amount - putIn, after.now - after.putIn, signed: true)
                }
                .padding(Space.s12)
                .background(Tokens.bg4.opacity(0.6), in: .rect(cornerRadius: Corner.c16, style: .continuous))

                DatePicker("Day", selection: $date, in: ...Day.date(today), displayedComponents: .date)
                    .font(AppFont.main(14, .medium))
                    .foregroundStyle(Tokens.text700)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s8)
            .safeAreaInset(edge: .bottom, spacing: 0) { AmountPad(value: $value) }
            .navigationTitle(a.name)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", systemImage: "checkmark") {
                        LocalStore(context: context).move(a, kind, amount: typed, date: Day.iso(date))
                        dismiss()
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Tokens.brand600)
                    .disabled(typed <= 0 || (kind == .value && typed == a.amount) || (kind == .takeOut && a.amount == 0))
                }
            }
        }
        .presentationDetents([.large])
    }

    private func prompt(_ name: String) -> String {
        switch kind {
        case .value: "What is \(name) worth now?"
        case .putIn: "How much did you put in?"
        case .takeOut: "How much did you take out?"
        }
    }

    /// One figure: "110M", or "110M → 74M" while what you type would change it.
    private func summary(_ label: String, _ before: Int, _ after: Int, signed: Bool = false) -> some View {
        func text(_ v: Int) -> String { (signed ? (v < 0 ? "−" : "+") : "") + AnalyticsView.compact(abs(v)) }
        return VStack(alignment: .leading, spacing: 2) {
            Text(label).font(AppFont.main(11)).foregroundStyle(Tokens.grey400)
            HStack(spacing: Space.s4) {
                Text(text(before))
                    .foregroundStyle(after == before ? Tokens.text900 : Tokens.grey400)
                if after != before {
                    Image(systemName: "arrow.right").font(.system(size: 10, weight: .bold)).foregroundStyle(Tokens.grey400)
                    Text(text(after))
                        .foregroundStyle(signed ? (after >= 0 ? Tokens.success : Tokens.text900) : Tokens.text900)
                        .contentTransition(.numericText())
                }
            }
            .font(AppFont.main(14, .semibold))
            .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct DebtSection: View {
    var bills: [Bill]
    var loans: [FamilyLoan]
    var today: String
    var hidden: Bool
    @Environment(\.modelContext) private var context
    @State private var addingLoan = false
    @State private var openPerson: String?
    @State private var showHistory = false

    var body: some View {
        let d = FinanceText.debt(bills)
        let month = Month.of(today)
        let monthly = d.rows.reduce(0) { $0 + $1.bill.amount }
        let family = LoanMath.people(loans, today: today)
        let familyOwed = family.reduce(0) { $0 + $1.owed }
        VStack(alignment: .leading, spacing: Space.s24) {
            JoinedCard {
                StatCard(label: "Still to pay", amount: d.total + familyOwed, hidden: hidden, stats: [
                    ("Installments", hidden ? "•••" : AnalyticsView.compact(d.total), false),
                    ("Family", hidden ? "•••" : AnalyticsView.compact(familyOwed), false),
                    ("A month", hidden ? "•••" : AnalyticsView.compact(monthly), false),
                ])
            } bottom: {
                DebtPie(bills: bills, loans: loans, today: today, hidden: hidden)
            }

            HistoryLink(sub: TotalAssetsSection.historySub(
                bills.filter { $0.kind == .installment }.flatMap { $0.paid.values.map { Day.iso($0.at) } } + loans.map(\.date)
            )) { showHistory = true }
                .padding(.top, Space.s8 - Space.s24) // 8 pt under the card above
            .sheet(isPresented: $showHistory) {
                DebtHistorySheet(bills: bills, loans: loans, today: today, hidden: hidden).sheetSurface()
            }

            familyCard(family)

            if d.rows.isEmpty {
                Text("No installments left to pay.").font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading, spacing: Space.s8) {
                FinanceSectionTitle(title: "Installments") { EmptyView() }
                VStack(spacing: 0) {
                    HStack(spacing: Space.s8) {
                        Text("Installment").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Paid").frame(width: 52, alignment: .trailing)
                        Text("Left").frame(width: 72, alignment: .trailing)
                        Text(Day.monthsShort[Day.parts(today).m - 1]).frame(width: 44, alignment: .center)
                    }
                    .font(AppFont.table(11, .semibold))
                    .tracking(0.3)
                    .foregroundStyle(Tokens.grey400)
                    .textCase(.uppercase)
                    .padding(.vertical, Space.s8)
                    .accessibilityHidden(true)
                    Divider().overlay(Tokens.bd0)
                    ForEach(d.rows, id: \.bill.id) { r in
                        let due = BillMath.dueIn(r.bill, month: month) != nil
                        let paidNow = r.bill.paid[month] != nil
                        HStack(spacing: Space.s8) {
                            VStack(alignment: .leading, spacing: Space.s4) {
                                Text(r.bill.name).font(AppFont.table(14, .semibold)).foregroundStyle(Tokens.text900).lineLimit(1)
                                Text((r.bill.lender.map { "\($0) · " } ?? "") + (hidden ? "•••" : AnalyticsView.compact(r.bill.amount)) + "/month")
                                    .font(AppFont.table(11)).foregroundStyle(Tokens.grey400).lineLimit(1)
                                ProgressView(value: Double(r.paid), total: Double(max(r.bill.payments ?? 1, 1)))
                                    .tint(Tokens.brand500)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(r.paid)/\(r.bill.payments ?? 0)")
                                .font(AppFont.table(14, .medium)).foregroundStyle(Tokens.text700).monospacedDigit()
                                .frame(width: 52, alignment: .trailing)
                            Text(hidden ? "•••" : AnalyticsView.compact(r.owe))
                                .font(AppFont.table(14, .semibold)).foregroundStyle(Tokens.text900).monospacedDigit()
                                .frame(width: 72, alignment: .trailing)
                            Button {
                                withAnimation(.snappy) {
                                    LocalStore(context: context).setBillPaid(r.bill, month: month, paid: !paidNow, date: today)
                                }
                            } label: {
                                Image(systemName: paidNow ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22, weight: paidNow ? .regular : .light))
                                    .foregroundStyle(paidNow ? Tokens.brand500 : Tokens.grey300)
                                    .contentTransition(.symbolEffect(.replace))
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .disabled(!due)
                            .opacity(due ? 1 : 0.3)
                            .sensoryFeedback(.success, trigger: paidNow)
                            .accessibilityLabel(paidNow ? "Mark this month's \(r.bill.name) as not paid" : "Mark this month's \(r.bill.name) as paid")
                        }
                        .padding(.vertical, Space.s12)
                        Divider().overlay(Tokens.bd0)
                    }
                    Text("Tick a month here or in Due — both stay in step.")
                        .font(AppFont.table(11)).foregroundStyle(Tokens.grey400)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, Space.s12)
                }
                .padding(.horizontal, Space.s16)
                .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c20))
                }
            }
        }
    }

    /// Money family sent, owed back with yearly interest: per person what came in, the interest
    /// so far and what's owed today. Tap a person to see each payment; + to add one.
    private func familyCard(_ family: [LoanMath.Person]) -> some View {
        VStack(alignment: .leading, spacing: Space.s8) {
        FinanceSectionTitle(title: "Family loans") {
            Button { addingLoan = true } label: {
                Label("Add", systemImage: "plus").font(AppFont.table(12, .semibold))
                    .padding(.horizontal, Space.s12).frame(height: 32)
            }
            .buttonStyle(.glass)
        }
        VStack(spacing: 0) {
            if family.isEmpty {
                Text("Money from family you'll pay back goes here, with its interest.")
                    .font(AppFont.table(12)).foregroundStyle(Tokens.grey400)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Space.s16)
            }
            // Same colour per person as on the pie above.
            let colors = Dictionary(DebtPie.debts(bills: bills, loans: loans, today: today).map { ($0.name, $0.color) },
                                    uniquingKeysWith: { a, _ in a })
            ForEach(Array(family.enumerated()), id: \.element.who) { i, p in
                if i > 0 { Divider().overlay(Tokens.bd0).padding(.leading, 56) }
                let interestLeft = max(0, p.interest - p.interestPaid)
                Button { openPerson = p.who } label: {
                    HStack(spacing: Space.s12) {
                        Text(String(p.who.prefix(1)).uppercased())
                            .font(AppFont.table(16, .bold)).foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(colors[p.who] ?? Tokens.grey400, in: .circle)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.who).font(AppFont.table(15, .semibold)).foregroundStyle(Tokens.text900).lineLimit(1)
                            Text((hidden ? "" : "got " + AnalyticsView.compact(p.principal) + " · ") + String(format: "%g%% a year", p.rate))
                                .font(AppFont.table(12)).foregroundStyle(Tokens.grey400).lineLimit(1)
                        }
                        Spacer(minLength: Space.s4)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(hidden ? "•••" : Money.format(p.owed) + "đ")
                                .font(AppFont.heading(16, .semibold)).foregroundStyle(Tokens.text900)
                            Text(hidden ? "•••" : "+" + AnalyticsView.compact(interestLeft) + " interest")
                                .font(AppFont.table(12, .medium)).foregroundStyle(Tokens.grey400)
                        }
                        .monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .padding(.vertical, Space.s12)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(p.who), " + (hidden ? "amounts hidden" :
                    "borrowed \(Money.format(p.principal)) dong, interest \(Money.format(interestLeft)) dong, owed \(Money.format(p.owed)) dong"))
                .accessibilityHint("Shows each payment")
            }
            Divider().overlay(Tokens.bd0)
            Text("Interest runs day by day on what's still borrowed. Paying interest takes it off first.")
                .font(AppFont.table(11)).foregroundStyle(Tokens.grey400)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Space.s12)
        }
        .padding(.horizontal, Space.s16)
        .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c20))
        }
        .sheet(isPresented: $addingLoan) {
            AddLoanSheet(people: Array(Set(loans.map(\.who))).sorted(), today: today)
                .sheetSurface()
        }
        .sheet(item: Binding(get: { openPerson.map { PersonID(id: $0) } }, set: { openPerson = $0?.id })) { p in
            LoanPersonSheet(who: p.id, loans: loans.filter { $0.who == p.id }, today: today, hidden: hidden)
                .sheetSurface()
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(AppFont.main(14, .semibold)).foregroundStyle(Tokens.text900)
            Text(label).font(AppFont.main(11)).foregroundStyle(Tokens.grey400)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Add asset

/// New asset, or (with `editing`) its name and group. A change of worth goes through
/// Add money / Take out / Update value on the asset, so its history stays right.
struct AddAssetSheet: View {
    var editing: Asset? = nil
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amount: Int?
    @State private var kind: AssetKind = .available
    /// When the money went in: today, or back when you started (it shows on the line from then).
    @State private var since = Date.now
    /// New asset starts on the quick pick (Figma-style step 1); editing goes straight to the form.
    @State private var picked = false

    var body: some View {
        NavigationStack {
            Group {
                if editing == nil && !picked { groupPicker } else { form }
            }
            .background(editing == nil && !picked ? Tokens.bg3 : Color.clear)
            .navigationTitle(editing == nil ? "New asset" : "Edit asset")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                if editing == nil && picked {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Change group", systemImage: "chevron.left") { animate { picked = false } }
                    }
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") { dismiss() }
                    }
                }
                if editing != nil || picked {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", systemImage: "checkmark", action: save)
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || (editing == nil && (amount ?? 0) <= 0))
                    }
                }
            }
        }
        .onAppear {
            if let a = editing {
                name = a.name
                kind = a.kind
            }
        }
    }

    /// Step 1: "Adding new [kind of] — tell us what you know:", the four groups, or one sentence.
    private var groupPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            AddingLead(label: "kind of", chosen: false)
                .padding(.horizontal, Space.s20).padding(.vertical, Space.s16)
            Spacer(minLength: 0)
            QuickPickCard(
                title: "Which group?",
                options: AssetKind.allCases.map {
                    QuickPickOption(id: $0, title: $0.label, hint: FinanceText.hint($0), mark: Tokens.assetKind($0))
                },
                sayPlaceholder: "e.g. vàng SJC 15tr, tiết kiệm TPBank 50tr",
                onPick: { kind = $0; picked = true },
                onSay: { text in
                    let read = AssetSentence.read(text, today: app.today)
                    name = read.name
                    amount = read.amount
                    kind = read.kind
                    picked = true
                })
            .padding(.horizontal, Space.s12)
            .padding(.top, Space.s24)
            .padding(.bottom, Space.s16)
        }
    }

    private var form: some View {
            Form {
                Section("What is it?") {
                    TextField("Gold, Saving - TP Bank, Fund…", text: $name)
                }
                .listRowBackground(Tokens.card)
                if editing == nil {
                let past = Day.iso(since) < app.today
                Section {
                    HStack {
                        TextField("0", text: Binding(
                            get: { amount.map(Money.format) ?? "" },
                            set: { amount = Int($0.filter(\.isNumber)) }))
                            .keyboardType(.numberPad)
                            .monospacedDigit()
                        Text("đ").foregroundStyle(Tokens.grey400)
                    }
                    DatePicker("Put in on", selection: $since, in: ...Date.now, displayedComponents: .date)
                        .tint(Tokens.brand600)
                } header: {
                    Text(past ? "How much did you put in then?" : "How much is it worth now?")
                } footer: {
                    if past {
                        Text("Add later deposits with Add money on the asset, each on its own day, then Update value for what it's worth now.")
                    }
                }
                .listRowBackground(Tokens.card)
                }
                Section {
                    Picker("Which group?", selection: $kind) {
                        ForEach(AssetKind.allCases, id: \.self) { k in
                            Label {
                                Text(k.label)
                            } icon: {
                                Image(systemName: "square.fill").foregroundStyle(Tokens.assetKind(k))
                            }
                            .tag(k)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Which group?")
                } footer: {
                    Text(FinanceText.hint(kind))
                }
                .listRowBackground(Tokens.card)
            }
            .appListSurface()
            .font(AppFont.main(16))
    }

    private func save() {
        let n = name.trimmingCharacters(in: .whitespaces)
        if let a = editing {
            LocalStore(context: context).editAsset(a, name: n, kind: kind)
            dismiss()
            return
        }
        LocalStore(context: context).addAsset(
            Asset(name: n, kind: kind, icon: AssetMath.guessIcon(n, kind: kind), amount: amount ?? 0, updated: min(Day.iso(since), app.today)))
        dismiss()
    }
}

/// A title over a Finance card ("Assets", "Family loans"), with anything on its right.
struct FinanceSectionTitle<Trailing: View>: View {
    var title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Text(title).font(AppFont.heading(18, .medium, relativeTo: .title3)).foregroundStyle(Tokens.text900)
                .contentTransition(.opacity)
            Spacer()
            trailing
        }
        .frame(minHeight: 32)
        .padding(.horizontal, Space.s4)
    }
}
