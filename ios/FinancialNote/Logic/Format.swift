import Foundation

/// Dates are plain "YYYY-MM-DD" strings in the user's local time, money is whole đồng.
/// Same convention as `src/lib/format.ts`, so data exported from either app reads the same.
nonisolated enum Day {
    private static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }

    static func iso(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func today(_ now: Date = .now) -> String { iso(now) }

    /// Year, month, day of an ISO date string.
    static func parts(_ iso: String) -> (y: Int, m: Int, d: Int) {
        let p = iso.split(separator: "-").map { Int($0) ?? 0 }
        return (p.count > 0 ? p[0] : 0, p.count > 1 ? p[1] : 1, p.count > 2 ? p[2] : 1)
    }

    /// Local midnight of an ISO date. Day overflow rolls into the next month, like JS `new Date(y, m, d)`.
    static func date(_ iso: String) -> Date {
        let (y, m, d) = parts(iso)
        return date(year: y, month: m, day: d)
    }

    static func date(year: Int, month: Int, day: Int) -> Date {
        // Build from the 1st and add, so out-of-range months and days roll over instead of failing.
        let first = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? .now
        let withMonth = calendar.date(byAdding: .month, value: month - 1, to: first) ?? first
        return calendar.date(byAdding: .day, value: day - 1, to: withMonth) ?? withMonth
    }

    static func addDays(_ iso: String, _ days: Int) -> String {
        let (y, m, d) = parts(iso)
        return self.iso(date(year: y, month: m, day: d + days))
    }

    /// Days in a month (1-based month).
    static func daysIn(year: Int, month: Int) -> Int {
        calendar.range(of: .day, in: .month, for: date(year: year, month: month, day: 1))?.count ?? 30
    }

    static let monthsShort = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    static let monthsLong = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ]

    /// "August 07, 2026" — the header date pill.
    static func long(_ iso: String) -> String {
        let (y, m, d) = parts(iso)
        return "\(monthsLong[m - 1]) \(String(format: "%02d", d)), \(y)"
    }

    /// "07 Aug" — "Spent on 07 Aug".
    static func short(_ iso: String) -> String {
        let (_, m, d) = parts(iso)
        return "\(String(format: "%02d", d)) \(monthsShort[m - 1])"
    }

    /// "Oct 15" — used for "Was due Oct 15".
    static func monthDay(_ iso: String) -> String {
        let (_, m, d) = parts(iso)
        return "\(monthsShort[m - 1]) \(d)"
    }

    static func greeting(_ now: Date = .now) -> String {
        let h = calendar.component(.hour, from: now)
        if h < 12 { return "Good Morning" }
        if h < 18 { return "Good Afternoon" }
        return "Good Evening"
    }
}

/// Month keys are "YYYY-MM".
nonisolated enum Month {
    static func of(_ iso: String) -> String { String(iso.prefix(7)) }

    static func add(_ month: String, _ n: Int) -> String {
        let (y, m, _) = Day.parts(month + "-01")
        let total = y * 12 + (m - 1) + n
        let ny = Int((Double(total) / 12).rounded(.down))
        return String(format: "%04d-%02d", ny, total - ny * 12 + 1)
    }

    static func between(_ a: String, _ b: String) -> Int {
        let (y1, m1, _) = Day.parts(a + "-01")
        let (y2, m2, _) = Day.parts(b + "-01")
        return (y2 - y1) * 12 + (m2 - m1)
    }
}

nonisolated enum Money {
    /// "42,000" — thousands with commas, as in the Figma file.
    static func format(_ n: Int) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: n)) ?? String(n)
    }
}
