import Foundation

/// Due-date and installment maths, ported from `src/lib/bills.ts`.
enum BillMath {
    /// The day this bill is due in `month` ("YYYY-MM"), or nil when it isn't due then.
    static func dueIn(_ bill: Bill, month: String) -> String? {
        let offset = Month.between(Month.of(bill.start), month)
        if offset < 0 { return nil }
        if bill.kind == .oneoff && offset != 0 { return nil }
        if bill.kind == .installment && offset >= (bill.payments ?? 1) { return nil }
        let (y, m, _) = Day.parts(month + "-01")
        let last = Day.daysIn(year: y, month: m)
        let day = min(Day.parts(bill.start).d, last)
        return "\(month)-\(String(format: "%02d", day))"
    }

    struct Step: Equatable {
        /// Installment number for the month (1-based).
        var index: Int
        var total: Int
        var paidCount: Int
        var left: Int
    }

    static func installmentStep(_ bill: Bill, month: String) -> Step {
        let n = bill.payments ?? 1
        let index = Month.between(Month.of(bill.start), month) + 1
        let paidCount = bill.paid.count
        return Step(index: index, total: n, paidCount: paidCount, left: max(0, n - paidCount))
    }

    static func lastDue(_ bill: Bill) -> String {
        guard bill.kind == .installment else { return bill.start }
        return dueIn(bill, month: Month.add(Month.of(bill.start), (bill.payments ?? 1) - 1)) ?? bill.start
    }

    /// Equal monthly payment: principal split evenly plus flat monthly interest on the principal.
    static func installmentPayment(principal: Int, payments: Int, ratePct: Double) -> Int {
        guard principal != 0, payments != 0 else { return 0 }
        let p = Double(principal)
        return Int((p / Double(payments) + p * ratePct / 100).rounded(.toNearestOrAwayFromZero))
    }

    struct DueItem {
        var bill: Bill
        var date: String
    }

    struct Summary {
        var due: [DueItem]
        var still: [DueItem]
        var done: [DueItem]
        var paid: Int
        var remaining: Int
        /// This month's unpaid bills plus every future installment.
        var totalRemaining: Int
    }

    /// What the Due screen shows for one month.
    static func monthSummary(_ bills: [Bill], month: String) -> Summary {
        let due = bills
            .compactMap { b in dueIn(b, month: month).map { DueItem(bill: b, date: $0) } }
            .sorted { $0.date < $1.date }
        let still = due.filter { $0.bill.paid[month] == nil }
        let done = due.filter { $0.bill.paid[month] != nil }
        let paid = done.reduce(0) { $0 + ($1.bill.paid[month]?.amount ?? 0) }
        let remaining = still.reduce(0) { $0 + $1.bill.amount }
        let future = bills.filter { $0.kind == .installment }.reduce(0) { sum, b in
            let paidMonths = b.paid
            var owed = 0
            for i in 0..<(b.payments ?? 1) {
                let m = Month.add(Month.of(b.start), i)
                if m > month && paidMonths[m] == nil { owed += b.amount }
            }
            return sum + owed
        }
        return Summary(due: due, still: still, done: done, paid: paid, remaining: remaining, totalRemaining: remaining + future)
    }

    /// Picks a tile from the name the user typed (Vietnamese or English).
    static func guessIcon(_ name: String, kind: BillKind) -> BillIcon {
        let n = name.lowercased(with: Locale(identifier: "vi"))
        func has(_ p: String) -> Bool { n.range(of: p, options: .regularExpression) != nil }
        if has("rent|nhà|nha tro|phòng|thuê") { return .house }
        if has("water|nước|nuoc") { return .drop }
        if has("gas|xăng|xang|petrol") { return .gasPump }
        if has("điện|dien|electric|power|evn") { return .lightning }
        if has("phone|iphone|samsung|điện thoại|sim|4g|wifi|internet|mạng") { return .phone }
        if has("course|học|hoc|school|english|tuition|lớp") { return .student }
        if has("macbook|laptop|tv|monitor|máy tính|ipad") { return .monitor }
        return kind == .installment ? .phone : .bell
    }
}
