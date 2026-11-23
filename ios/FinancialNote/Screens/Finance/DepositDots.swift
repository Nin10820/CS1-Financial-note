import SwiftUI

/// How often money went in, like Saving goal's dots: one row a year, one dot a month, against
/// that year's monthly plan (tap the year to set it). Rounded squares, like a contribution grid:
/// grey = nothing went in, then three greens, pale to deep = less than the plan, about the plan,
/// more than the plan. Months before the first deposit and months to come are fainter. Tap a
/// square to read that month.
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

    /// Less than the plan, about the plan, more than the plan: three greens far apart in lightness,
    /// so each step reads at a glance. On dark they brighten; on light they deepen.
    static let greens: [Color] = [
        Color(light: 0xB9E09A, dark: 0x2F5A1C),
        Color(light: 0x5FA82F, dark: 0x6DB83B),
        Color(light: 0x24480F, dark: 0xCDEFB0),
    ]
    /// A month with nothing put in: a quiet filled square, not a ring.
    static let empty = Color(light: 0xE9ECF0, dark: 0x2B2F36)
    private static let names = ["Less", "On plan", "More"]

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
                ForEach(years, id: \.self) { y in
                    HStack(spacing: 0) {
                        // The year on the left, its monthly plan on the right; tap either to set the plan.
                        planButton(y) {
                            Text(String(y)).font(AppFont.main(12)).foregroundStyle(Tokens.text700)
                                .frame(width: 42, alignment: .leading)
                        }
                        ForEach(1...12, id: \.self) { m in
                            let month = String(format: "%04d-%02d", y, m)
                            dot(month, sum: sums[month], level: levels[month], future: month > now, before: month < first,
                                on: month == focus)
                        }
                        planButton(y) {
                            planText(y).font(AppFont.main(12))
                                .frame(width: 36, alignment: .trailing)
                        }
                    }
                }
            }
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

    /// The year's monthly plan, green when set for that year, grey when carried over.
    private func planText(_ y: Int) -> some View {
        Text(hidden ? "•••" : AnalyticsView.compact(plan(for: y)))
            .foregroundStyle(plans[String(y)] == nil ? Tokens.grey300 : Tokens.brand600)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    /// Tap the year (or its plan) to set that year's monthly plan.
    private func planButton(_ y: Int, @ViewBuilder _ label: () -> some View) -> some View {
        Button { draft = plans[String(y)] ?? plan(for: y); editing = y } label: {
            label().contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(y) plan, \(hidden ? "hidden" : Money.format(plan(for: y)) + " dong a month")")
        .accessibilityHint("Sets the monthly plan for \(y)")
    }

    private func dot(_ month: String, sum: Int?, level: Int?, future: Bool, before: Bool, on: Bool) -> some View {
        Button {
            withAnimation(.snappy) { picked = month == picked ? nil : month }
        } label: {
            ZStack {
                if let level {
                    RoundedRectangle(cornerRadius: 5).fill(Self.greens[level])
                } else {
                    RoundedRectangle(cornerRadius: 5).fill(Self.empty).opacity(future || before ? 0.45 : 1)
                }
                if on { RoundedRectangle(cornerRadius: 7).strokeBorder(Tokens.text900, lineWidth: 1.5).padding(-2.5) }
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(2)
            .frame(maxWidth: .infinity)
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
            .sheetHeader("Plan for \(String(year))", trailing: .save(enabled: (value ?? 0) > 0) { onSave(value); dismiss() })
        }
        .presentationDetents([.large])
    }
}
