import Foundation

/// "Say it your way" on New bill: one sentence becomes a filled-in bill to check and save.
/// "Internet 250k every month on the 5th", "laptop 12tr trả góp 12 tháng", "bảo hiểm 1tr2 một lần ngày 20".
/// Reads, on the phone: the kind (installment / one-off / monthly by default), the due day,
/// the number of payments, "about …" (changes each month), then the name and amount with the
/// note parser. Anything it can't find stays empty for the form.
enum BillSentence {
    static func read(_ text: String, month: String, today: String) -> BillDraft {
        let lower = text.lowercased(with: Locale(identifier: "vi"))
        func has(_ p: String) -> Bool { lower.range(of: p, options: .regularExpression) != nil }
        func first(_ p: String) -> Int? {
            guard let r = try? NSRegularExpression(pattern: p),
                  let m = r.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
                  let g = Range(m.range(at: 1), in: lower) else { return nil }
            return Int(lower[g])
        }

        let kind: BillKind =
            has(#"trả góp|tra gop|góp|installment|instalment"#) ? .installment
            : has(#"một lần|1 lần|mot lan|once|one[- ]?off|lần này"#) ? .oneoff
            : .recurring
        var d = BillDraft(month: month, today: today, kind: kind)

        // Due day: "ngày 15", "mùng 5", "on the 5th", "5th", "day 5".
        if let day = first(#"(?:ngày|ngay|mùng|mung|day)\s*(\d{1,2})"#)
            ?? first(#"on the\s*(\d{1,2})"#)
            ?? first(#"\b(\d{1,2})(?:st|nd|rd|th)\b"#),
           (1...31).contains(day) {
            let (y, m, _) = Day.parts(month + "-01")
            d.due = String(format: "%@-%02d", month, min(day, Day.daysIn(year: y, month: m)))
        }

        // Installments: "12 tháng", "12 kỳ", "12 months", "12 payments".
        if kind == .installment, let n = first(#"(\d{1,3})\s*(?:tháng|thang|kỳ|ky|months?|payments?)"#), n > 0 {
            d.payments = n
        }
        d.varies = kind == .recurring && has(#"khoảng|tầm|tam |about|around|~|thay đổi|changes"#)

        // Name and amount: drop the words read above, let the note parser do the rest.
        var rest = text
        for p in [#"(?i)(trả góp|tra gop|góp|installment|instalment)"#,
                  #"(?i)(một lần|1 lần|mot lan|once|one[- ]?off|lần này)"#,
                  #"(?i)(mỗi tháng|hàng tháng|hang thang|moi thang|every month|monthly|per month|/tháng|/month)"#,
                  #"(?i)(ngày|ngay|mùng|mung|day)\s*\d{1,2}"#, #"(?i)on the\s*\d{1,2}(st|nd|rd|th)?"#,
                  #"(?i)\b\d{1,2}(st|nd|rd|th)\b"#,
                  #"(?i)\d{1,3}\s*(tháng|thang|kỳ|ky|months?|payments?)"#,
                  #"(?i)\b(khoảng|tầm|about|around)\b|~"#] {
            rest = rest.replacingOccurrences(of: p, with: " ", options: .regularExpression)
        }
        rest = rest.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,.-–—"))
        if let line = NoteParser.parse(rest, day: today).first {
            d.name = line.title
            if kind == .installment { d.principal = line.amount } else { d.amount = line.amount }
            if let p = line.paidFrom { d.payWith = p }
        } else {
            d.name = rest
        }
        return d
    }
}
