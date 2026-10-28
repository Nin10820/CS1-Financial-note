import Foundation

/// A line the reader pulled out of a note, before the user confirms it.
nonisolated struct Draft: Equatable, Sendable, Identifiable {
    var id = UUID()
    var title: String
    /// nil when no amount could be read — the user fills it in before saving.
    var amount: Int?
    var flow: Flow
    var category: Category
    var date: String
    /// A bare number like "45" was read as 45,000.
    var assumedThousands = false

    static func == (a: Draft, b: Draft) -> Bool {
        a.title == b.title && a.amount == b.amount && a.flow == b.flow && a.category == b.category
            && a.date == b.date && a.assumedThousands == b.assumedThousands
    }
}

/// A local, rule-based reader so the app works with no network. Ported rule for rule from
/// `src/lib/parse.ts`: 24k, 35.000, 1tr2, 2tr5, 1.5tr, 100k, Vietnamese and English words,
/// "hôm qua" / "yesterday", "· cash". Keep the two in step: change a rule there, change it here.
nonisolated enum NoteParser {
    // JS `\b` only knows ASCII letters, while ICU's knows all of Unicode. `R` rewrites `\b` to the
    // ASCII version so a pattern matches exactly what it matches in the web app.
    private static let wordB = "(?:(?<![A-Za-z0-9_])(?=[A-Za-z0-9_])|(?<=[A-Za-z0-9_])(?![A-Za-z0-9_]))"

    private static func R(_ pattern: String) -> NSRegularExpression {
        let p = pattern.replacingOccurrences(of: "\\b", with: wordB)
        // swiftlint:disable:next force_try
        return try! NSRegularExpression(pattern: p, options: [.caseInsensitive])
    }

    private static let amount = R(
        #"(\d+(?:[.,]\d+)*)\s*(k|nghìn|nghin|ngàn|ngan|tr|triệu|trieu|m|đ|vnd|vnđ|d)?(\d)?(?![\p{L}\d])"#)

    private static let income = R(
        "paid me back|trả lại|tra lai|trả mình|nhận|nhan duoc|received|lương|luong|salary|thưởng|bonus|refund|hoàn tiền|hoan tien|got paid")

    private static let rules: [(Category, NSRegularExpression)] = [
        (.transport, R(#"xăng|xang|petrol|gas\b|grab|\bbe\b|taxi|xe ôm|gửi xe|gui xe|parking|bus|uber|vé xe|tàu|train"#)),
        // Whole words only for "bill", "fee", "rent", so "coffee" isn't a bill (fixed in d42f14d).
        (.bills, R(#"điện|tiền nước|internet|wifi|\bbills?\b|hoá đơn|hóa đơn|phí|\bfees?\b|\brent\b|tiền nhà|trả góp|installment"#)),
        (.shopping, R("mua|shopee|lazada|tiki|quần|áo|giày|dép|shirt|shoes|clothes|shopping")),
        (.food, R(#"cà phê|ca phe|cafe|\bcf\b|coffee|cơm|com tam|phở|pho|bún|bun|bánh|banh|ăn|an sang|trà sữa|tra sua|milk tea|lunch|breakfast|dinner|rice|sandwich|thịt|đậu|đậu hũ|rau|chợ|tofu|snack|nước|drink|tea|bia|beer|food|pizza|mì|noodle"#)),
    ]

    private static let dayWords = R(#"\b(hôm nay|hom nay|today|hôm qua|hom qua|yesterday)\b"#)
    private static let yesterday = R("hôm qua|hom qua|yesterday")
    private static let isDayWordRe = R("^(hôm nay|hom nay|today|hôm qua|hom qua|yesterday)$")
    /// How it was paid, written at the end: "· cash", "· transfer", "tiền mặt", "chuyển khoản".
    private static let paidWith = R(#"\s*[·\-–]?\s*(cash|transfer|card|tiền mặt|tien mat|chuyển khoản|chuyen khoan|\bck\b|thẻ)\s*$"#)
    private static let trailingMark = R(#"\s*[-–—:·]\s*$"#)
    private static let leadingMark = R(#"^\s*[-–—:·]\s*"#)
    private static let manySpaces = R(#"\s{2,}"#)
    private static let lineSplit = R(#"[\n;]+"#)
    private static let partSplit = R(#"(?<!\d),|,(?!\d)|\s+(?:và|va|and|\+)\s+"#)
    private static let thousandsTail = R(#"[.,]\d{3}$"#)

    // MARK: - Regex helpers that behave like the JS calls they replace

    private static func ns(_ s: String) -> NSRange { NSRange(s.startIndex..., in: s) }

    private static func test(_ re: NSRegularExpression, _ s: String) -> Bool {
        re.firstMatch(in: s, range: ns(s)) != nil
    }

    /// `s.replace(re, with)` — first match only, like a JS regex without `g`.
    private static func replaceFirst(_ re: NSRegularExpression, in s: String, with: String) -> String {
        guard let m = re.firstMatch(in: s, range: ns(s)), let r = Range(m.range, in: s) else { return s }
        return s.replacingCharacters(in: r, with: with)
    }

    private static func replaceAll(_ re: NSRegularExpression, in s: String, with: String) -> String {
        re.stringByReplacingMatches(in: s, range: ns(s), withTemplate: NSRegularExpression.escapedTemplate(for: with))
    }

    private static func split(_ s: String, by re: NSRegularExpression) -> [String] {
        var out: [String] = []
        var start = s.startIndex
        for m in re.matches(in: s, range: ns(s)) {
            guard let r = Range(m.range, in: s) else { continue }
            out.append(String(s[start..<r.lowerBound]))
            start = r.upperBound
        }
        out.append(String(s[start...]))
        return out
    }

    // MARK: - Reading

    struct AmountRead: Equatable {
        var value: Double
        var assumed: Bool
    }

    static func readAmount(_ raw: String, unit: String?, tail: String?) -> AmountRead {
        let u = (unit ?? "").lowercased()
        let isMillion = ["tr", "triệu", "trieu", "m"].contains(u)
        let isThousand = ["k", "nghìn", "nghin", "ngàn", "ngan"].contains(u)
        let decimal = Double(raw.replacingFirst(",", with: ".")) ?? .nan
        // "1tr2" → 1.2 million, "2tr5" → 2.5 million
        if isMillion, let tail, let t = Double(tail) { return .init(value: (decimal + t / 10) * 1e6, assumed: false) }
        if isMillion { return .init(value: decimal * 1e6, assumed: false) }
        if isThousand { return .init(value: decimal * 1e3, assumed: false) }
        // "35.000" or "35,000" → 35000
        let digits = Double(raw.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "")) ?? .nan
        if test(thousandsTail, raw) || u.hasPrefix("đ") || u.hasPrefix("vnd") || u == "d" {
            return .init(value: digits, assumed: false)
        }
        // A bare small number almost always means thousands ("cafe 45").
        if digits > 0 && digits < 1000 { return .init(value: digits * 1000, assumed: true) }
        return .init(value: digits, assumed: false)
    }

    private static func tidyTitle(_ s: String) -> String {
        var t = replaceAll(dayWords, in: s, with: " ")
        t = replaceFirst(paidWith, in: t, with: "")
        t = replaceFirst(trailingMark, in: t, with: "")
        t = replaceFirst(leadingMark, in: t, with: "")
        t = replaceAll(manySpaces, in: t, with: " ")
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = t.first else { return "" }
        return String(first).uppercased(with: Locale(identifier: "vi")) + t.dropFirst()
    }

    private static func isDayWord(_ s: String) -> Bool { test(isDayWordRe, s) }
    private static func hasAmount(_ s: String) -> Bool { test(amount, s) }

    /// Splits a note into drafts. `day` is the "YYYY-MM-DD" the note is written for.
    static func parse(_ text: String, day: String) -> [Draft] {
        let base = test(yesterday, text) ? Day.addDays(day, -1) : day
        // Each line (or ";") is read on its own; inside a line, split on "và/and/+" and on commas
        // that aren't inside a number ("35,000", "1,5tr").
        let segments: [String] = split(text, by: lineSplit).flatMap { line -> [String] in
            let parts = split(line, by: partSplit)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && !isDayWord($0) }
            // "Lunch, broken rice 40k" is one thing: a part with no amount joins the next part that has one.
            var merged: [String] = []
            var carry = ""
            for p in parts {
                if !hasAmount(p) {
                    carry = carry.isEmpty ? p : "\(carry), \(p)"
                    continue
                }
                merged.append(carry.isEmpty ? p : "\(carry), \(p)")
                carry = ""
            }
            if !carry.isEmpty { merged.append(carry) }
            return merged
        }

        return segments.map { segment in
            let r = ns(segment)
            let match = amount.firstMatch(in: segment, range: r)
            var read: AmountRead?
            var rest = segment
            if let match, let whole = Range(match.range, in: segment) {
                func group(_ i: Int) -> String? {
                    Range(match.range(at: i), in: segment).map { String(segment[$0]) }
                }
                read = readAmount(group(1) ?? "", unit: group(2), tail: group(3))
                // JS `segment.replace(match[0], " ")` swaps the first place that text appears.
                rest = segment.replacingFirst(String(segment[whole]), with: " ")
            }
            let flow: Flow = test(income, segment) ? .in : .out
            let category: Category = flow == .in ? .received : (rules.first { test($0.1, segment) }?.0 ?? .other)
            let value = read.map(\.value) ?? .nan
            let title = tidyTitle(rest)
            return Draft(
                title: title.isEmpty ? category.rawValue : title,
                amount: value > 0 ? Int(value.rounded()) : nil,
                flow: flow,
                category: category,
                date: base,
                assumedThousands: read?.assumed ?? false
            )
        }
    }
}

nonisolated extension String {
    func replacingFirst(_ target: String, with replacement: String) -> String {
        guard let r = range(of: target) else { return self }
        return replacingCharacters(in: r, with: replacement)
    }
}
