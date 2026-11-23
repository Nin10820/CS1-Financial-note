import SwiftUI

/// A month's saving plan: the goal, what's kept so far, and the daily budget that keeps the
/// goal in reach — (money in − goal − bills) spread over the month's days. Bills are left out
/// of the days, since they land on one day but belong to the whole month.
struct SavingPlan {
    let month: String
    let today: String
    let goal: Int
    let suggested: Int
    let kept: Int
    /// Put aside toward the goal so far, at today's pace (see `init`).
    let saved: Int
    let dailyBudget: Int
    let days: [String]
    private let spentByDay: [String: Int]

    init(month: String, today: String, entries: [Entry], goalSetting: Int, countBills: Bool = false) {
        self.month = month
        self.today = today
        let lines = entries.filter { Month.of($0.date) == month }
        let income = lines.filter { $0.flow == .in }.reduce(0) { $0 + $1.amount }
        // No money in yet this month: plan on last month's.
        let planIncome = income > 0 ? income : entries
            .filter { Month.of($0.date) == Month.add(month, -1) && $0.flow == .in }.reduce(0) { $0 + $1.amount }
        let out = lines.filter { $0.flow == .out }
        let bills = out.filter { $0.category == .bills }.reduce(0) { $0 + $1.amount }
        let (y, m, _) = Day.parts(month + "-01")
        let count = Day.daysIn(year: y, month: m)
        // Suggested: what last month's everyday spending says is left after bills, less a 10%
        // cushion, rounded down to half a million. No last month yet: a fifth of the money in.
        let before = entries.filter { Month.of($0.date) == Month.add(month, -1) && $0.flow == .out && $0.category != .bills }
        let (py, pm, _) = Day.parts(Month.add(month, -1) + "-01")
        let perDay = before.reduce(0) { $0 + $1.amount } / Day.daysIn(year: py, month: pm)
        let room = before.isEmpty ? planIncome / 5 : Int(Double(planIncome - bills - perDay * count) * 0.9)
        suggested = max(500_000, room / 500_000 * 500_000)
        goal = goalSetting > 0 ? goalSetting : suggested
        kept = income - out.reduce(0) { $0 + $1.amount }
        // Bills counted: they come out of the days like any spend; otherwise they're set aside first.
        dailyBudget = max(0, (planIncome - goal - (countBills ? 0 : bills)) / count)
        days = (1...count).map { String(format: "%@-%02d", month, $0) }
        var byDay: [String: Int] = [:]
        for e in out where countBills || e.category != .bills { byDay[e.date, default: 0] += e.amount }
        spentByDay = byDay
        // Saved toward the goal, at today's pace: each day gone by puts its share of the goal
        // aside, plus whatever it stayed under the daily budget (or minus what it went over).
        let gone = days.filter { $0 <= today }
        let budget = dailyBudget, aside = goal
        let underBudget = gone.reduce(0) { $0 + (budget - (byDay[$1] ?? 0)) }
        saved = aside * gone.count / count + underBudget
    }

    func spent(on day: String) -> Int { spentByDay[day] ?? 0 }

    /// 0…1, how far under the budget the day stayed (nil for days still to come).
    func level(_ day: String) -> Double? {
        guard day <= today else { return nil }
        guard dailyBudget > 0 else { return 0.15 }
        let ratio = Double(spent(on: day)) / Double(dailyBudget)
        switch ratio {
        case ...0.5: return 1
        case ...0.8: return 0.75
        case ...1: return 0.5
        default: return 0.15
        }
    }
}

/// The month as a calendar of dots, Monday first. Darker = further under the day's budget;
/// days to come are just an outline; the picked day has a ring.
struct SavingDots: View {
    var plan: SavingPlan
    var picked: String?
    var color: Color

    var body: some View {
        let lead = (Calendar(identifier: .gregorian).component(.weekday, from: Day.date(plan.days[0])) + 5) % 7
        let cells: [String?] = Array(repeating: nil, count: lead) + plan.days.map { Optional($0) }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        VStack(spacing: Space.s6) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"].indices, id: \.self) { i in
                    Text(["M", "T", "W", "T", "F", "S", "S"][i]).font(AppFont.main(11)).foregroundStyle(Tokens.grey400)
                }
                ForEach(cells.indices, id: \.self) { i in
                    if let day = cells[i] {
                        dot(day)
                    } else {
                        Color.clear.frame(height: 22)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Days this month")
        .accessibilityValue("\(plan.days.filter { (plan.level($0) ?? 0) >= 0.5 }.count) days within the budget")
    }

    private func dot(_ day: String) -> some View {
        let level = plan.level(day)
        return ZStack {
            if let level {
                Circle().fill(color.opacity(level))
            } else {
                Circle().strokeBorder(Tokens.bd1, lineWidth: 1)
            }
            if day == picked || (picked == nil && day == plan.today) {
                Circle().strokeBorder(Tokens.text900, lineWidth: 1.5).padding(-3)
            }
        }
        .frame(width: 22, height: 22)
        .frame(maxWidth: .infinity)
    }
}

/// Set the monthly saving goal: the number pad, a few quick picks, and the suggestion.
struct GoalSheet: View {
    @Binding var value: Int?
    var suggested: Int
    var onSave: (Int?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Space.s16) {
                Text("How much do you want to keep this month?")
                    .font(AppFont.main(14)).foregroundStyle(Tokens.grey400)
                HStack(alignment: .firstTextBaseline, spacing: Space.s4) {
                    Text(Money.format(value ?? 0))
                        .font(AppFont.heading(40, .medium)).foregroundStyle(Tokens.text900)
                        .monospacedDigit().contentTransition(.numericText())
                    Text("đ").font(AppFont.heading(28)).foregroundStyle(Tokens.grey400)
                }
                ScrollView(.horizontal) {
                    HStack(spacing: Space.s8) {
                        chip("Suggested " + AnalyticsView.compact(suggested), suggested)
                        ForEach([2_000_000, 3_000_000, 5_000_000, 8_000_000, 10_000_000], id: \.self) { v in
                            chip(AnalyticsView.compact(v), v)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                Spacer(minLength: 0)
            }
            .padding(Space.s20)
            .safeAreaInset(edge: .bottom, spacing: 0) { AmountPad(value: $value) }
            .sheetHeader("Saving goal", trailing: .save(enabled: (value ?? 0) > 0) { onSave(value); dismiss() })
        }
        .presentationDetents([.large])
    }

    private func chip(_ label: String, _ v: Int) -> some View {
        Button { withAnimation(.snappy) { value = v } } label: {
            Text(label).font(AppFont.main(14, .medium))
                .padding(.horizontal, Space.s12)
                .frame(height: 36)
        }
        .buttonStyle(.glass)
    }
}

/// Put a custom amount aside today: the number pad, today's leftover, and a few round amounts.
struct SaveSheet: View {
    @Binding var value: Int?
    var left: Int
    var onSave: (Int?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Space.s16) {
                Text("How much did you put aside today?")
                    .font(AppFont.main(14)).foregroundStyle(Tokens.grey400)
                HStack(alignment: .firstTextBaseline, spacing: Space.s4) {
                    Text(Money.format(value ?? 0))
                        .font(AppFont.heading(40, .medium)).foregroundStyle(Tokens.text900)
                        .monospacedDigit().contentTransition(.numericText())
                    Text("đ").font(AppFont.heading(28)).foregroundStyle(Tokens.grey400)
                }
                ScrollView(.horizontal) {
                    HStack(spacing: Space.s8) {
                        if left > 0 { chip("Today's left " + AnalyticsView.compact(left), left) }
                        ForEach([50_000, 100_000, 200_000, 500_000, 1_000_000], id: \.self) { v in
                            chip(AnalyticsView.compact(v), v)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                Text("Only noted in the app — no money moves.")
                    .font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                Spacer(minLength: 0)
            }
            .padding(Space.s20)
            .safeAreaInset(edge: .bottom, spacing: 0) { AmountPad(value: $value) }
            .sheetHeader("Put aside", trailing: .save(enabled: (value ?? 0) > 0) { onSave(value); dismiss() })
        }
        .presentationDetents([.large])
    }

    private func chip(_ label: String, _ v: Int) -> some View {
        Button { withAnimation(.snappy) { value = v } } label: {
            Text(label).font(AppFont.main(14, .medium))
                .padding(.horizontal, Space.s12)
                .frame(height: 36)
        }
        .buttonStyle(.glass)
    }
}
