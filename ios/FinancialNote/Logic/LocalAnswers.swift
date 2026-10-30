import Foundation

/// Answers a few questions about the user's own money, worked out on the phone from what is
/// saved. Facts only — totals, categories, bills — never advice or comments on spending.
enum LocalAnswers {
    /// One answer: a sentence and the rows under it.
    struct Report: Equatable, Sendable {
        var title: String
        var summary: String
        var rows: [Row]
    }

    struct Row: Equatable, Sendable {
        var label: String
        var detail: String?
        var amount: Int
    }

    /// The questions it understands; anything else gets an honest "comes later".
    enum Ask: String, CaseIterable, Sendable {
        case today, week, month, lastMonth, bills, received

        var title: String {
            switch self {
            case .today: "Today's spending"
            case .week: "This week's spending"
            case .month: "Monthly spending review"
            case .lastMonth: "Last month's spending"
            case .bills: "Bills left this month"
            case .received: "Money in this month"
            }
        }

        /// The suggestion chip text.
        var question: String {
            switch self {
            case .today: "What did I spend today?"
            case .week: "How much this week?"
            case .month: "Where did this month go?"
            case .lastMonth: "How was last month?"
            case .bills: "Which bills are left?"
            case .received: "What came in this month?"
            }
        }
    }

    /// A line the user saved, as plain values (so this works without the database).
    struct Line: Sendable {
        var date: String
        var title: String
        var amount: Int
        var flow: Flow
        var category: Category
    }

    /// Reads a typed question. nil when it reads like a spending note instead.
    static func ask(for text: String) -> Ask? {
        let t = text.lowercased(with: Locale(identifier: "vi"))
        func has(_ p: String) -> Bool { t.range(of: p, options: .regularExpression) != nil }
        // A line with an amount is a note to save, not a question.
        if has(#"\d+\s*(k|tr|nghìn|ngàn|đ|vnd)\b"#) || has(#"\d{2,}"#) { return nil }
        if has(#"bill|hoá đơn|hóa đơn|due|phải trả|trả góp"#) { return .bills }
        if has(#"came in|received|thu nhập|nhận|lương|income|money in"#) { return .received }
        if has(#"last month|tháng trước"#) { return .lastMonth }
        if has(#"today|hôm nay"#) { return .today }
        if has(#"week|tuần"#) { return .week }
        if has(#"month|tháng|category|danh mục|review"#) { return .month }
        if has(#"\?$|how much|bao nhiêu|what did|where|spend|spent|chi tiêu|tiêu"#) { return .month }
        return nil
    }

    static func report(_ ask: Ask, lines: [Line], bills: [Bill], today: String) -> Report {
        switch ask {
        case .today: return spending(ask.title, lines, from: today, to: today, words: "today")
        case .week:
            let mon = Day.monday(of: today)
            return spending(ask.title, lines, from: mon, to: Day.addDays(mon, 6), words: "this week")
        case .month:
            let m = Month.of(today)
            return spending(ask.title, lines, from: "\(m)-01", to: "\(m)-31", words: "in \(Day.monthsLong[Day.parts(today).m - 1])")
        case .lastMonth:
            let m = Month.add(Month.of(today), -1)
            return spending(ask.title, lines, from: "\(m)-01", to: "\(m)-31", words: "in \(DueText.monthName(m))")
        case .received:
            let m = Month.of(today)
            let ins = lines.filter { $0.flow == .in && $0.date >= "\(m)-01" && $0.date <= "\(m)-31" }
                .sorted { $0.amount > $1.amount }
            let total = ins.reduce(0) { $0 + $1.amount }
            return Report(
                title: ask.title,
                summary: ins.isEmpty ? "Nothing came in yet this month." : "\(Money.format(total)) đ came in this month.",
                rows: ins.prefix(6).map { Row(label: $0.title, detail: Day.short($0.date), amount: $0.amount) })
        case .bills:
            let month = Month.of(today)
            let s = BillMath.monthSummary(bills, month: month)
            return Report(
                title: ask.title,
                summary: s.still.isEmpty
                    ? (s.due.isEmpty ? "No bills due this month." : "All \(s.due.count) bills this month are paid.")
                    : "\(s.still.count) \(s.still.count == 1 ? "bill" : "bills") left, \(Money.format(s.remaining)) đ in total.",
                rows: s.still.map { Row(label: $0.bill.name, detail: DueText.listDate($0.date, paid: false, today: today), amount: $0.bill.amount) })
        }
    }

    /// Spending between two days, by category, biggest first.
    private static func spending(_ title: String, _ lines: [Line], from: String, to: String, words: String) -> Report {
        let out = lines.filter { $0.flow == .out && $0.date >= from && $0.date <= to }
        let total = out.reduce(0) { $0 + $1.amount }
        let rows = Dictionary(grouping: out, by: \.category)
            .map { cat, list in
                Row(label: cat.rawValue, detail: "\(list.count) \(list.count == 1 ? "item" : "items")",
                    amount: list.reduce(0) { $0 + $1.amount })
            }
            .sorted { $0.amount > $1.amount }
        return Report(
            title: title,
            summary: out.isEmpty ? "Nothing spent \(words)." : "You spent \(Money.format(total)) đ \(words), \(out.count) \(out.count == 1 ? "item" : "items").",
            rows: rows)
    }

    /// What to say when a question is outside what it can answer.
    static let outOfScope = "I can answer questions about what you saved — today, this week, this month, last month, money in and bills. Asking anything else comes later."
}
