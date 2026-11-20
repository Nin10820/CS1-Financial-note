import SwiftUI

/// How often money went in, like Saving goal's dots: one row a year, one dot a month, against
/// that year's monthly plan (tap the year to set it). Four looks: an empty ring = nothing went in, then three
/// greens, dim to bright = less than the plan, about the plan, more than the plan. Months
/// before the first deposit and months to come are faint. Tap a dot to read that month.
struct DepositDots: View {
    var moves: [AssetMove]
    var today: String
    /// The fallback plan for a year with none set (the saving goal, or its suggestion).
    var plan: Int
    var hidden: Bool
    @State private var picked: String?
    /// Each year's monthly plan, "2024": 5000000, kept on this phone.
    @AppStorage("depositPlans") private var plansRaw = ""
    /// The year whose plan is being set.
    @State private var editing: Int?
    @State private var draft: Int?

    private var plans: [String: Int] {
        (try? JSONDecoder().decode([String: Int].self, from: Data(plansRaw.utf8))) ?? [:]
    }

    /// A year's plan: its own, else the nearest earlier year's, else the fallback.
    private func plan(for year: Int) -> Int {
        let set = plans
        if let own = set[String(year)] { return own }
        let earlier = set.compactMap { k, v in Int(k).map { ($0, v) } }.filter { $0.0 < year }.max { $0.0 < $1.0 }
        return earlier?.1 ?? plan
    }

    private func save(_ value: Int?, for year: Int) {
        var set = plans
        set[String(year)] = (value ?? 0) > 0 ? value : nil
        if let data = try? JSONEncoder().encode(set) { plansRaw = String(decoding: data, as: UTF8.self) }
    }

    /// Less than the plan, about the plan, more than the plan: three solid greens that read apart.
    /// On dark they brighten toward the chart pill's pale green; on light they deepen.
    static let greens: [Color] = [
        // Far apart in lightness: dim, the full brand green, nearly white.
        Color(light: 0xDCF0CC, dark: 0x2A4A1E),
        Color(light: 0x6DB83B, dark: 0x5FA82F),
        Color(light: 0x2C5A14, dark: 0xD6F5BC),
    ]
    private static let names = ["Less", "On plan", "More"]

    private static let letters = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]

    var body: some View {
        let ins = moves.filter { $0.kind == .putIn && $0.amount > 0 && $0.date <= today }
        let byMonth = Dictionary(grouping: ins) { Month.of($0.date) }
        let sums = byMonth.mapValues { $0.reduce(0) { $0 + $1.amount } }
        let now = Month.of(today)
        let first = byMonth.keys.min() ?? now
        let (y0, _, _) = Day.parts(first + "-01")
        let (y1, _, _) = Day.parts(today)
        let years = Array(y0...max(y0, y1))
        // Months from the first deposit to now, and how many had money going in.
        let span = Month.between(first, now) + 1
        let active = sums.count
        let levels = Dictionary(uniqueKeysWithValues: sums.map { m, v in
            (m, Self.level(v, plan: plan(for: Day.parts(m + "-01").0)))
        })
        let focus = picked ?? now
        VStack(alignment: .leading, spacing: Space.s16) {
            HStack(alignment: .firstTextBaseline) {
                Text("How often you put money in").font(AppFont.main(14, .semibold)).foregroundStyle(Tokens.text900)
                Spacer(minLength: Space.s8)
            }
            HStack(spacing: Space.s24) {
                stat("\(active) of \(span)", "months with money in")
                stat("\(Self.streak(sums.keys, now: now))", "months in a row, best")
            }
            VStack(spacing: Space.s6) {
                HStack(spacing: 0) {
                    // Over the year column: the number under each year is its monthly plan (tap to set).
                    Text("Plan").font(AppFont.main(9, .medium)).foregroundStyle(Tokens.grey400).lineLimit(1)
                        .frame(width: 36, alignment: .leading)
                    ForEach(Self.letters.indices, id: \.self) { i in
                        Text(Self.letters[i]).font(AppFont.main(11)).foregroundStyle(Tokens.grey400)
                            .frame(maxWidth: .infinity)
                    }
                }
                ForEach(years, id: \.self) { y in
                    HStack(spacing: 0) {
                        // The year and its plan; tap to set the plan.
                        Button { draft = plans[String(y)] ?? plan(for: y); editing = y } label: {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(String(y)).font(AppFont.main(11, .medium)).foregroundStyle(Tokens.text700)
                                Text(hidden ? "•••" : AnalyticsView.compact(plan(for: y)))
                                    .font(AppFont.main(9, .medium))
                                    .foregroundStyle(plans[String(y)] == nil ? Tokens.grey300 : Tokens.brand600)
                            }
                            .frame(width: 36, alignment: .leading)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(y) plan, \(hidden ? "hidden" : Money.format(plan(for: y)) + " dong a month")")
                        .accessibilityHint("Sets the monthly plan for \(y)")
                        ForEach(1...12, id: \.self) { m in
                            let month = String(format: "%04d-%02d", y, m)
                            dot(month, sum: sums[month], level: levels[month], future: month > now, before: month < first,
                                on: month == focus)
                        }
                    }
                }
            }
            // What the four looks mean, against the plan.
            HStack(spacing: Space.s12) {
                HStack(spacing: Space.s4) {
                    Circle().strokeBorder(Tokens.grey400, lineWidth: 1).frame(width: 10, height: 10)
                    Text("None")
                }
                ForEach(Self.greens.indices, id: \.self) { i in
                    HStack(spacing: Space.s4) {
                        Circle().fill(Self.greens[i]).frame(width: 10, height: 10)
                        Text(Self.names[i])
                    }
                }
                Spacer(minLength: 0)
            }
            .font(AppFont.main(11))
            .foregroundStyle(Tokens.grey400)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityElement(children: .combine)
            // The picked month (this month until you tap one).
            let n = byMonth[focus]?.count ?? 0
            Text(FinanceText.monthLabel(focus) + " · " + (n == 0 ? "nothing put in"
                : (hidden ? "put in •••" : "put in " + AnalyticsView.compact(sums[focus] ?? 0) + "đ")
                    + (n > 1 ? ", \(n) times" : "")
                    + " · " + Self.names[levels[focus] ?? 0].lowercased()))
                .font(AppFont.main(12))
                .foregroundStyle(Tokens.grey400)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .contentTransition(.opacity)
        }
        .padding(Space.s16)
        .background(Tokens.card, in: .rect(cornerRadius: Corner.c20))
        .accessibilityElement(children: .contain)
        .sheet(item: Binding(get: { editing.map(YearID.init) }, set: { editing = $0?.year })) { e in
            YearPlanSheet(year: e.year, value: $draft) { save($0, for: e.year) }
                .sheetSurface()
        }
    }

    private func dot(_ month: String, sum: Int?, level: Int?, future: Bool, before: Bool, on: Bool) -> some View {
        Button {
            withAnimation(.snappy) { picked = month == picked ? nil : month }
        } label: {
            ZStack {
                if let level {
                    Circle().fill(Self.greens[level])
                } else {
                    Circle().strokeBorder(Tokens.bd1, lineWidth: 1).opacity(future || before ? 0.4 : 1)
                }
                if on { Circle().strokeBorder(Tokens.text900, lineWidth: 1.5).padding(-3) }
            }
            .frame(width: 18, height: 18)
            .frame(maxWidth: .infinity, minHeight: 26)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(future)
        .accessibilityLabel(FinanceText.monthLabel(month))
        .accessibilityValue(sum.map { (hidden ? "Money put in" : "Put in \(Money.format($0)) dong")
            + ", " + Self.names[level ?? 0].lowercased() } ?? "Nothing put in")
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(AppFont.heading(18, .semibold)).foregroundStyle(Tokens.text900).monospacedDigit()
            Text(label).font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
        }
        .accessibilityElement(children: .combine)
    }

    /// 0 less than the plan, 1 about the plan (90–120%), 2 more than the plan.
    static func level(_ sum: Int, plan: Int) -> Int {
        guard plan > 0 else { return 1 }
        let r = Double(sum) / Double(plan)
        return r < 0.9 ? 0 : r <= 1.2 ? 1 : 2
    }

    /// The longest run of months in a row with money going in.
    static func streak(_ months: some Sequence<String>, now: String) -> Int {
        var best = 0, run = 0, last: String?
        for m in months.sorted() {
            run = (last.map { Month.add($0, 1) == m } ?? false) ? run + 1 : 1
            best = max(best, run)
            last = m
        }
        return best
    }
}

private struct YearID: Identifiable {
    let year: Int
    var id: Int { year }
}

/// Set how much you plan to put in each month of one year: the number pad and a few round picks.
private struct YearPlanSheet: View {
    let year: Int
    @Binding var value: Int?
    var onSave: (Int?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Space.s16) {
                Text("How much do you plan to put in each month of \(String(year))?")
                    .font(AppFont.main(14)).foregroundStyle(Tokens.grey400)
                HStack(alignment: .firstTextBaseline, spacing: Space.s4) {
                    Text(Money.format(value ?? 0))
                        .font(AppFont.heading(40, .medium)).foregroundStyle(Tokens.text900)
                        .monospacedDigit().contentTransition(.numericText())
                    Text("đ").font(AppFont.heading(28)).foregroundStyle(Tokens.grey400)
                }
                ScrollView(.horizontal) {
                    HStack(spacing: Space.s8) {
                        ForEach([1_000_000, 2_000_000, 3_000_000, 5_000_000, 10_000_000, 15_000_000], id: \.self) { v in
                            Button { withAnimation(.snappy) { value = v } } label: {
                                Text(AnalyticsView.compact(v)).font(AppFont.main(14, .medium))
                                    .padding(.horizontal, Space.s12)
                                    .frame(height: 36)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                Text("Each month of \(String(year)) is compared with this: less, on plan or more.")
                    .font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                Spacer(minLength: 0)
            }
            .padding(Space.s20)
            .safeAreaInset(edge: .bottom, spacing: 0) { AmountPad(value: $value) }
            .navigationTitle("Plan for \(String(year))")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", systemImage: "checkmark") { onSave(value); dismiss() }
                        .buttonStyle(.glassProminent)
                        .tint(Tokens.brand600)
                        .disabled((value ?? 0) <= 0)
                }
            }
        }
        .presentationDetents([.large])
    }
}
