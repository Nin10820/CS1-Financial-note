import Foundation

/// Made-up data that fills every screen for demos and first launch, ported from `src/lib/sample.ts`.
/// Every item has `sample: true` so it can be removed in one switch without touching anything the
/// user wrote.
enum SampleData {
    struct Bundle {
        var entries: [Entry]
        var notes: [DayNote]
        var bills: [Bill]
        var assets: [Asset]
        var moves: [AssetMove]
        var care: [CareGift]
        var worth: [WorthPoint]
        var birthYear: Int
    }

    private static func id(_ s: String) -> String { "sample-\(s)" }

    /// Same month offset as the web sample: the day is capped at 28 so it always exists.
    static func addMonthsIso(_ iso: String, _ n: Int) -> String {
        let (y, m, d) = Day.parts(iso)
        return Day.iso(Day.date(year: y, month: m + n, day: min(d, 28)))
    }

    // [title, amount, category, flow] per day, newest day first.
    private static let days: [[(String, Int, Category, Flow)]] = [
        [("Cơm tấm", 35_000, .food, .out), ("Cafe with the team", 40_000, .food, .out),
         ("Grab to work", 42_000, .transport, .out), ("Lunch, broken rice", 45_000, .food, .out)],
        [("Phở bò", 55_000, .food, .out), ("Petrol", 100_000, .transport, .out),
         ("Peter paid me back for lunch", 45_000, .received, .in), ("Milk tea", 35_000, .food, .out)],
        [("Groceries at the market", 180_000, .food, .out), ("Book", 120_000, .shopping, .out),
         ("Parking", 5_000, .transport, .out)],
        [("Bánh mì", 25_000, .food, .out), ("Grab home", 60_000, .transport, .out),
         ("Dinner with family", 320_000, .food, .out)],
        [("Haircut", 80_000, .other, .out), ("Coffee", 29_000, .food, .out), ("T-shirt", 199_000, .shopping, .out)],
        [("Salary", 18_500_000, .received, .in), ("Bún chả", 50_000, .food, .out)],
        [("Snack", 15_000, .food, .out), ("Water", 10_000, .food, .out), ("Bus card top-up", 100_000, .transport, .out)],
    ]

    private static func k(_ amount: Int) -> String { "\(Int((Double(amount) / 1000).rounded()))k" }

    static func make(today: String, now: Date = .now) -> Bundle {
        var entries: [Entry] = []
        var notes: [DayNote] = []
        let dayMs = 86_400.0

        for (i, day) in days.enumerated() {
            let date = Day.addDays(today, -i)
            let noteId = id("note-\(i)")
            let source = day.map { "\($0.0) \(k($0.1))" }.joined(separator: ", ")
            for (j, item) in day.enumerated() {
                entries.append(Entry(
                    id: id("e-\(i)-\(j)"), date: date, title: item.0, amount: item.1, flow: item.3,
                    category: item.2, noteId: noteId, source: source,
                    createdAt: now.addingTimeInterval(-Double(i) * dayMs - Double(day.count - j) * 600),
                    sample: true))
            }
            if i < 2 {
                let lines = day.enumerated().map { k, item in
                    k == 1 ? "\(item.0) \(Self.k(item.1)) · cash" : "\(item.0) \(Self.k(item.1))"
                }
                notes.append(DayNote(date: date, lines: lines, updatedAt: now.addingTimeInterval(-Double(i) * dayMs), sample: true))
            }
        }

        let thisMonth = Month.of(today)
        let day15 = "\(thisMonth)-15"
        func paidMonths(_ from: Int, _ to: Int, _ amount: Int) -> [String: PaidRecord] {
            var out: [String: PaidRecord] = [:]
            for k in from...to {
                out[Month.of(addMonthsIso(day15, -k))] = PaidRecord(amount: amount, at: now.addingTimeInterval(-Double(k) * 2_592_000))
            }
            return out
        }

        let bills = [
            Bill(id: id("rent"), kind: .recurring, name: "Rent", icon: .house, amount: 2_500_000,
                 start: addMonthsIso("\(thisMonth)-05", -8), payWith: "Transfer", paid: paidMonths(0, 8, 2_500_000), createdAt: now, sample: true),
            Bill(id: id("power"), kind: .recurring, name: "Electricity", icon: .lightning, amount: 420_000, varies: true,
                 start: addMonthsIso("\(thisMonth)-12", -8), code: "PE0400123456", paid: paidMonths(0, 8, 410_000), createdAt: now, sample: true),
            Bill(id: id("water"), kind: .recurring, name: "Water Bill", icon: .drop, amount: 120_000, varies: true,
                 start: addMonthsIso(day15, -8), code: "WT2451234151", paid: paidMonths(0, 8, 118_000), createdAt: now, sample: true),
            Bill(id: id("net"), kind: .recurring, name: "Internet", icon: .phone, amount: 220_000,
                 start: addMonthsIso("\(thisMonth)-20", -8), paid: paidMonths(0, 8, 220_000), createdAt: now, sample: true),
            Bill(id: id("iphone"), kind: .installment, name: "iPhone 15 Pro", icon: .phone, amount: 1_100_000,
                 start: addMonthsIso("\(thisMonth)-25", -3), payWith: "TP Bank", lender: "TP Bank", principal: 12_120_000,
                 payments: 12, rate: 0, fee: 1.5, paid: paidMonths(1, 3, 1_100_000), createdAt: now, sample: true),
            Bill(id: id("course"), kind: .installment, name: "English Course", icon: .student, amount: 367_000,
                 start: addMonthsIso("\(thisMonth)-18", -5), lender: "Home Credit", principal: 2_200_000,
                 payments: 6, rate: 0, fee: 0, paid: paidMonths(1, 5, 367_000), createdAt: now, sample: true),
        ]

        // 122,647,000 đ split 40 / 30 / 20 / 10 like the Figma overview.
        let assets = [
            Asset(id: id("cash"), name: "Cash & bank account", kind: .available, icon: .cash, amount: 49_059_000, updated: today, sample: true),
            Asset(id: id("gold"), name: "Gold", kind: .growing, icon: .gold, amount: 14_500_000, updated: Day.addDays(today, -66), sample: true),
            Asset(id: id("fund"), name: "Fund - Fmarket", kind: .growing, icon: .fund, amount: 22_294_000, updated: Day.addDays(today, -95), sample: true),
            Asset(id: id("saving"), name: "Saving - TP Bank", kind: .aside, icon: .bank, amount: 24_529_000, updated: Day.addDays(today, -280), sample: true),
            Asset(id: id("lent"), name: "Lent to Minh", kind: .owed, icon: .lent, amount: 12_265_000, updated: Day.addDays(today, -40), sample: true),
        ]

        let moves = [
            AssetMove(id: id("m1"), title: "Gold", icon: .gold, amount: 14_500_000, date: Day.addDays(today, -66), sample: true),
            AssetMove(id: id("m2"), title: "Fund - Fmarket", icon: .fund, amount: 5_000_000, date: Day.addDays(today, -95), sample: true),
            AssetMove(id: id("m3"), title: "Saving - TP Bank", icon: .bank, amount: 450_000, date: Day.addDays(today, -280), sample: true),
            AssetMove(id: id("m4"), title: "Lent to Minh", icon: .lent, amount: 12_265_000, date: Day.addDays(today, -40), sample: true),
            AssetMove(id: id("m5"), title: "Fund - Fmarket", icon: .fund, amount: 3_000_000, date: Day.addDays(today, -160), sample: true),
        ]

        // Family support: parents every month, the younger brother's tuition each term, household bills.
        var care: [CareGift] = []
        for k in 0..<46 {
            care.append(CareGift(id: id("p\(k)"), who: "Parents", title: "Parents support", amount: k < 12 ? 2_000_000 : 1_500_000,
                                 date: addMonthsIso(Day.addDays(today, -6), -k), sample: true))
        }
        for k in 0..<4 {
            care.append(CareGift(id: id("b\(k)"), who: "Young brother", title: "Sibling tuition", amount: 6_500_000,
                                 date: addMonthsIso(Day.addDays(today, -45), -6 * k), sample: true))
        }
        for k in 0..<24 {
            care.append(CareGift(id: id("h\(k)"), who: "Household", title: "Household", amount: 1_250_000,
                                 date: addMonthsIso(Day.addDays(today, -3), -k), sample: true))
        }
        care.append(CareGift(id: id("med"), who: "Parents", title: "Medical costs", amount: 4_034_000,
                             date: addMonthsIso(today, -9), sample: true))

        // Net worth by month since Jan 2020: slow growth with some wobble, ending at today's total.
        let total = assets.reduce(0) { $0 + $1.amount }
        let (ty, tm, _) = Day.parts(today)
        let months = (ty - 2020) * 12 + tm
        let worth: [WorthPoint] = (0..<months).map { k in
            let t = Double(k) / Double(months - 1)
            let wobble = sin(Double(k) * 0.9) * 0.05 + sin(Double(k) * 0.37) * 0.07
            let value = (Double(total) * (0.18 + 0.82 * pow(t, 1.6)) * (1 + wobble * (1 - t * 0.6))).rounded()
            let month = String(format: "%04d-%02d", 2020 + k / 12, k % 12 + 1)
            return WorthPoint(month: month, value: k == months - 1 ? total : Int(value), sample: true)
        }

        return Bundle(entries: entries, notes: notes, bills: bills, assets: assets, moves: moves, care: care,
                      worth: worth, birthYear: ty - 27)
    }
}
