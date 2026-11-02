import Foundation

/// Numbers and words on Finance, ported from `Finance.tsx`. Everything here is what the user
/// wrote down — nothing talks to a bank, and nothing comments on how anyone spends.
enum FinanceText {
    /// "21 Aug 2026"
    static func dayLabel(_ iso: String) -> String {
        let (y, m, d) = Day.parts(iso)
        return "\(d) \(Day.monthsShort[m - 1]) \(y)"
    }

    /// "Sep 2026"
    static func monthLabel(_ month: String) -> String {
        let (y, m, _) = Day.parts(month + "-01")
        return "\(Day.monthsShort[m - 1]) \(y)"
    }

    /// Growth against the same month last year, when the chart goes back that far.
    static func growth(_ points: [(month: String, value: Int)]) -> Int? {
        let p = points.sorted { $0.month < $1.month }
        guard p.count > 12 else { return nil }
        let now = Double(p[p.count - 1].value)
        let then = Double(p[p.count - 13].value)
        guard then != 0 else { return nil }
        return Int(((now - then) / then * 100).rounded())
    }

    /// "You have carried this since you were 23." (or "since Jan 2023" without a birth year).
    static func since(careDates: [String], birthYear: Int?, today: String) -> String {
        let first = careDates.min() ?? today
        if let birthYear { return "You have carried this since you were \(Day.parts(first).y - birthYear)." }
        return "You have carried this since \(monthLabel(Month.of(first)))."
    }

    /// How often each person was helped: "every month, 46 times", "4 terms of tuition", "24 bills".
    static func cadence(who: String, firstTitle: String, count: Int) -> String {
        let text = (who + " " + firstTitle).lowercased()
        if text.range(of: #"tuition|brother|sister|\bem\b"#, options: .regularExpression) != nil {
            return "\(count) terms of tuition"
        }
        if who.lowercased().range(of: "household|nhà", options: .regularExpression) != nil { return "\(count) bills" }
        return "every month, \(count) times"
    }

    /// Share of what came in over the last 30 days that went to family, as a plain fact.
    static func familyShare(incoming: [(date: String, amount: Int)], care: [(date: String, amount: Int)], today: String) -> Int? {
        let since = Day.addDays(today, -30)
        let earned = incoming.filter { $0.date >= since }.reduce(0) { $0 + $1.amount }
        guard earned > 0 else { return nil }
        let gave = care.filter { $0.date >= since }.reduce(0) { $0 + $1.amount }
        return Int((Double(gave) / Double(earned) * 100).rounded())
    }

    struct DebtRow {
        var bill: Bill
        var paid: Int
        var left: Int
        var owe: Int
    }

    /// Installments with payments still to make, and what is still owed on each.
    static func debt(_ bills: [Bill]) -> (rows: [DebtRow], total: Int) {
        let rows = bills
            .filter { $0.kind == .installment && ($0.payments ?? 0) > 0 }
            .map { b -> DebtRow in
                let paid = b.paid.count
                let left = max(0, (b.payments ?? 0) - paid)
                return DebtRow(bill: b, paid: paid, left: left, owe: left * b.amount)
            }
            .filter { $0.left > 0 }
        return (rows, rows.reduce(0) { $0 + $1.owe })
    }

    /// What each group means, shown under the picker when adding an asset.
    static func hint(_ kind: AssetKind) -> String {
        switch kind {
        case .available: "Money you can use right away — cash, your main account."
        case .growing: "Put somewhere to grow — gold, a fund, stocks."
        case .aside: "Locked away for later — a savings deposit."
        case .owed: "Money someone owes you."
        }
    }
}
