import Foundation

/// Words and labels on the Due screens, ported from `Due.tsx`, `BillSheet.tsx` and `DueSheets.tsx`.
/// No "overdue" alarms anywhere (product rule): a past date just reads "Was due Oct 15".
enum DueText {
    /// "August, 2026"
    static func monthLabel(_ month: String) -> String {
        let (y, m, _) = Day.parts(month + "-01")
        return "\(Day.monthsLong[m - 1]), \(y)"
    }

    /// "August"
    static func monthName(_ month: String) -> String {
        Day.monthsLong[Day.parts(month + "-01").m - 1]
    }

    /// "Sep 15"
    static func dueLabel(_ iso: String) -> String { Day.monthDay(iso) }

    /// "25/09/2026"
    static func ddmmyyyy(_ iso: String) -> String {
        let (y, m, d) = Day.parts(iso)
        return String(format: "%02d/%02d/%04d", d, m, y)
    }

    /// "2.5 M" for the month cards in Coming up; under a million stays "420,000".
    static func short(_ n: Int) -> String {
        guard n >= 1_000_000 else { return Money.format(n) }
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US")
        f.maximumFractionDigits = 3
        f.minimumFractionDigits = 0
        return "\(f.string(from: NSNumber(value: Double(n) / 1e6)) ?? "") M"
    }

    /// The date under a bill's name in the list.
    static func listDate(_ due: String, paid: Bool, today: String) -> String {
        !paid && due < today ? "Was due \(dueLabel(due))" : dueLabel(due)
    }

    /// "Done", "Due Sep 15", "Was due Oct 15" or "Not due this month".
    static func status(_ bill: Bill, month: String, today: String) -> String {
        if bill.paid[month] != nil { return "Done" }
        guard let due = BillMath.dueIn(bill, month: month) else { return "Not due this month" }
        return due < today ? "Was due \(dueLabel(due))" : "Due \(dueLabel(due))"
    }

    /// The next unpaid due date from this month on, within two years.
    static func nextDue(_ bill: Bill, today: String) -> String? {
        let paid = bill.paid
        for i in 0..<24 {
            let m = Month.add(Month.of(today), i)
            if let d = BillMath.dueIn(bill, month: m), paid[m] == nil { return d }
        }
        return nil
    }

    /// "All paid", "Last one — done this month" or "6 left · ends 15/03/2027".
    static func installmentLine(_ bill: Bill, month: String) -> String {
        let st = BillMath.installmentStep(bill, month: month)
        switch st.left {
        case 0: return "All paid"
        case 1: return "Last one — done this month"
        default: return "\(st.left) left · ends \(ddmmyyyy(BillMath.lastDue(bill)))"
        }
    }

    /// What a month asks for in total: paid amounts where paid, the expected amount otherwise.
    static func monthTotal(_ bills: [Bill], month: String) -> Int {
        BillMath.monthSummary(bills, month: month).due.reduce(0) { sum, x in
            sum + (x.bill.paid[month]?.amount ?? x.bill.amount)
        }
    }
}
