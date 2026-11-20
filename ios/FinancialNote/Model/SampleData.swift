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
        var loans: [FamilyLoan]
        var worth: [WorthPoint]
        var birthYear: Int
    }

    private static func id(_ s: String) -> String { "sample-\(s)" }

    /// Same month offset as the web sample: the day is capped at 28 so it always exists.
    static func addMonthsIso(_ iso: String, _ n: Int) -> String {
        let (y, m, d) = Day.parts(iso)
        return Day.iso(Day.date(year: y, month: m + n, day: min(d, 28)))
    }

    private static func k(_ amount: Int) -> String { "\(Int((Double(amount) / 1000).rounded()))k" }

    // Everyday Vietnamese dishes for each meal; each costs between 30k and 50k.
    private static let breakfasts = ["Bánh mì ốp la", "Phở bò", "Xôi gà", "Bánh cuốn", "Hủ tiếu", "Bún bò Huế", "Cháo lòng", "Bánh mì chảo"]
    private static let lunches = ["Cơm tấm sườn", "Bún chả", "Cơm gà", "Mì Quảng", "Bún thịt nướng", "Cơm văn phòng", "Bún riêu", "Phở gà"]
    private static let dinners = ["Cơm sườn", "Bánh xèo", "Bún đậu mắm tôm", "Cơm chiên", "Hủ tiếu Nam Vang", "Bò kho bánh mì", "Bún cá", "Cơm niêu"]

    static func make(today: String, now: Date = .now) -> Bundle {
        var entries: [Entry] = []
        var notes: [DayNote] = []

        // Three months of an ordinary life, the same every time it's loaded (fixed seed):
        // breakfast, lunch and dinner (30–50k), a 20k coffee every day, 5k gym parking on
        // weekdays, petrol 100k every Saturday, dinner out with the girlfriend now and then
        // (100k, instead of dinner), a milk tea or a Shopee order now and then, the salary and
        // a freelance job once a month, a room let out, things sold online, and a friend paying
        // back now and then. Each line is written at the
        // hour it happened; today only has what has already happened.
        var seed: UInt64 = 20_260_301
        func roll(_ n: Int) -> Int {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int((seed >> 33) % UInt64(n))
        }
        func meal(_ names: [String]) -> (String, Int) { (names[roll(names.count)], 30_000 + roll(5) * 5_000) }
        let salaryDay = Day.parts(Day.addDays(today, -5)).d
        let freelanceDay = Day.parts(Day.addDays(today, -17)).d
        let calendar = Calendar(identifier: .gregorian)
        // The rest of life, spread over the categories: name, from, extra steps of 10k, category.
        let extras: [(String, Int, Int, Category)] = [
            // Housing & Utilities
            ("Nước giặt, giấy vệ sinh", 120_000, 8, .other), ("Bình gas", 380_000, 4, .other),
            ("Đồ gia dụng", 150_000, 15, .shopping), ("Giặt sấy", 60_000, 4, .other),
            // Transportation
            ("Grab đi làm", 45_000, 4, .transport), ("Rửa xe", 50_000, 2, .transport),
            ("Thay nhớt xe", 120_000, 4, .transport), ("Vé gửi xe tháng", 150_000, 0, .transport),
            // Health & Fitness
            ("Thuốc cảm", 60_000, 5, .other), ("Vitamin C", 150_000, 5, .other), ("Khám răng", 300_000, 10, .other),
            ("Cắt tóc", 80_000, 4, .other), ("Bơi", 40_000, 2, .other),
            // Education
            ("Sách kỹ năng", 120_000, 10, .other), ("Khoá học online Udemy", 249_000, 0, .other),
            ("Tài liệu IELTS", 180_000, 6, .other), ("Workshop thiết kế", 300_000, 10, .other),
            // Technology
            ("Cáp sạc", 150_000, 5, .shopping), ("Ốp điện thoại", 120_000, 5, .shopping),
            ("Chuột không dây", 350_000, 10, .shopping), ("Thay pin điện thoại", 450_000, 5, .other),
            // Hobbies
            ("Dây đàn guitar", 150_000, 5, .other), ("Màu vẽ", 200_000, 10, .other), ("Xem phim CGV", 110_000, 4, .other),
            ("Board game cafe", 80_000, 4, .other), ("Cầu lông", 60_000, 3, .other), ("Mô hình lego", 450_000, 20, .shopping),
            // Shopping
            ("Áo thun", 179_000, 10, .shopping), ("Quần jean", 450_000, 15, .shopping), ("Giày sneaker", 890_000, 30, .shopping),
            ("Kem chống nắng", 250_000, 8, .shopping), ("Balo", 390_000, 15, .shopping),
            // Travel
            ("Vé xe limousine Đà Lạt", 350_000, 5, .other), ("Homestay Đà Lạt", 600_000, 20, .other),
            ("Vé máy bay Đà Nẵng", 1_200_000, 40, .other),
            // Social & Gifts
            ("Quà sinh nhật bạn", 300_000, 20, .other), ("Mừng cưới", 500_000, 0, .other), ("Nhậu với bạn", 250_000, 10, .food),
            ("Họp lớp", 200_000, 10, .food), ("Bó hoa", 250_000, 10, .other),
            // Food & Drinks
            ("Đi chợ", 150_000, 10, .food), ("Siêu thị Bách Hoá Xanh", 220_000, 15, .food), ("Trái cây", 60_000, 5, .food),
            ("Highlands Coffee", 55_000, 2, .food), ("Bánh tráng trộn", 25_000, 1, .food),
        ]

        for i in 0..<92 {
            let date = Day.addDays(today, -i)
            let midnight = Day.date(date)
            let weekday = calendar.component(.weekday, from: midnight)   // 1 = Sunday … 7 = Saturday
            var items: [(title: String, amount: Int, category: Category, flow: Flow, hour: Double)] = []
            if Day.parts(date).d == salaryDay { items.append(("Lương tháng", 18_500_000, .received, .in, 9)) }
            // A freelance design job paid once a month, and a friend paying back now and then.
            if Day.parts(date).d == freelanceDay {
                items.append(("Freelance thiết kế", 2_500_000 + roll(4) * 500_000, .received, .in, 21))
            }
            if roll(12) == 0 { items.append(("Bạn trả tiền", 50_000 + roll(4) * 50_000, .received, .in, 20.5)) }
            // A room let out (paid on the 1st) and old things sold online now and then.
            if Day.parts(date).d == 1 { items.append(("Cho thuê phòng", 3_000_000, .received, .in, 10)) }
            if roll(10) == 0 { items.append(("Bán đồ online", 150_000 + roll(8) * 50_000, .received, .in, 21.5)) }
            let b = meal(breakfasts)
            items.append((b.0, b.1, .food, .out, 7.5))
            items.append(("Cà phê sữa đá", 20_000, .food, .out, 8.25))
            if weekday == 7 { items.append(("Đổ xăng", 100_000, .transport, .out, 10)) }
            let l = meal(lunches)
            items.append((l.0, l.1, .food, .out, 12))
            if (2...6).contains(weekday) { items.append(("Gửi xe gym", 5_000, .transport, .out, 17.5)) }
            // Subscriptions on their day each month.
            for (title, amount, day) in [("Netflix", 260_000, 3), ("Spotify", 59_000, 8), ("iCloud 200GB", 45_000, 12),
                                         ("YouTube Premium", 79_000, 20), ("Gym tháng", 500_000, 1)]
            where Day.parts(date).d == day {
                items.append((title, amount, .other, .out, 9.5))
            }
            // About every other day, one thing from the rest of life.
            if roll(2) == 0 {
                let e = extras[roll(extras.count)]
                items.append((e.0, e.1 + roll(e.2 + 1) * 10_000, e.3, .out, 16 + Double(roll(4))))
            }
            // Treats: a milk tea once or twice a week, a Shopee order a couple of times a month.
            if roll(5) == 0 { items.append(("Trà sữa", 35_000 + roll(3) * 5_000, .food, .out, 15)) }
            if roll(15) == 0 { items.append(("Đặt đồ Shopee", 150_000 + roll(6) * 50_000, .shopping, .out, 22)) }
            // About once a week, more likely at the weekend.
            if roll(weekday == 1 || weekday == 7 ? 3 : 9) == 0 {
                items.append(("Đi ăn với ny", 100_000, .food, .out, 19.5))
            } else {
                let d = meal(dinners)
                items.append((d.0, d.1, .food, .out, 19))
            }
            let minutes = items.map { _ in Double(roll(20)) * 60 }
            if i == 0 { items = items.filter { midnight.addingTimeInterval($0.hour * 3600) <= now } }
            guard !items.isEmpty else { continue }

            let noteId = id("note-\(i)")
            let source = items.map { "\($0.title) \(k($0.amount))" }.joined(separator: ", ")
            for (j, it) in items.enumerated() {
                entries.append(Entry(
                    id: id("e-\(i)-\(j)"), date: date, title: it.title, amount: it.amount, flow: it.flow,
                    category: it.category, noteId: noteId, source: source,
                    createdAt: midnight.addingTimeInterval(it.hour * 3600 + minutes[j]),
                    sample: true))
            }
            if i < 2 {
                notes.append(DayNote(date: date, lines: items.map { "\($0.title) \(k($0.amount))" },
                                     updatedAt: midnight.addingTimeInterval((items.last?.hour ?? 12) * 3600), sample: true))
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

        // A paid bill shows as a "Bills" spend on its due day, like ticking it in Due does.
        let from = Day.addDays(today, -91)
        for bill in bills {
            let dueDay = Day.parts(bill.start).d
            var records = bill.paid
            for (month, record) in records.sorted(by: { $0.key < $1.key }) {
                let (y, m, _) = Day.parts(month + "-01")
                let date = String(format: "%@-%02d", month, min(dueDay, Day.daysIn(year: y, month: m)))
                guard date >= from, date <= today else { continue }
                let entry = Entry(
                    id: id("bill-\(bill.id)-\(month)"), date: date, title: bill.name, amount: record.amount, flow: .out,
                    category: .bills, noteId: "bill-\(bill.id)-\(month)", source: "Checked off “\(bill.name)” in Due",
                    createdAt: record.at, billId: bill.id, sample: true)
                entries.append(entry)
                records[month]?.entryId = entry.id
            }
            bill.paid = records
        }

        // Assets like a real sheet: what was put in over the last months, then what each is worth
        // now (gold and the fund up, stocks down, cash and savings as they were). Each one keeps
        // its moves, so Total Asset can show put in, now and the gain or loss.
        let holdings: [(key: String, name: String, kind: AssetKind, icon: AssetIcon, ins: [(Int, Int)], now: Int)] = [
            ("vnd", "VND", .available, .cash, [(4_000_000, -20)], 4_000_000),
            ("usd", "USD", .available, .usd, [(20_100_000, -75)], 20_000_000),
            ("saving", "Saving", .aside, .bank, [(1_000_000, -88)], 1_000_000),
            ("gold", "Gold", .growing, .gold, [(18_000_000, -88), (12_000_000, -40)], 65_000_000),
            ("fund", "Fund", .growing, .fund, [(50_000_000, -88), (20_000_000, -60), (17_750_000, -30)], 110_000_000),
            ("stock", "Stock", .growing, .stock, [(60_000_000, -85), (48_300_000, -45)], 75_000_000),
            ("coin", "Coin", .growing, .coin, [(200_000, -10)], 200_000),
            ("lent", "Lent to Minh", .owed, .lent, [(12_265_000, -40)], 12_265_000),
        ]
        var assets: [Asset] = []
        var moves: [AssetMove] = []
        for h in holdings {
            let assetId = id(h.key)
            let put = h.ins.reduce(0) { $0 + $1.0 }
            let valued = h.now != put ? Day.addDays(today, -3) : Day.addDays(today, h.ins.map(\.1).max() ?? 0)
            assets.append(Asset(id: assetId, name: h.name, kind: h.kind, icon: h.icon, amount: h.now, updated: valued, sample: true))
            for (k, (amount, ago)) in h.ins.enumerated() {
                moves.append(AssetMove(id: id("m-\(h.key)-\(k)"), title: h.name, icon: h.icon, amount: amount,
                                       date: Day.addDays(today, ago), sample: true, assetId: assetId, kind: .putIn))
            }
            if h.now != put {
                moves.append(AssetMove(id: id("m-\(h.key)-value"), title: h.name, icon: h.icon, amount: h.now - put,
                                       date: valued, sample: true, assetId: assetId, kind: .value))
            }
        }

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

        // Family loans at 6% a year: money from Mom and Grandma, and interest paid to Mom.
        let loans: [FamilyLoan] = [
            ("Mom", "Mẹ gửi", LoanMove.received, 20_000_000, -425), ("Grand", "Bà Ngoại gửi", .received, 25_000_000, -311),
            ("Grand", "Bà Ngoại - Feb", .received, 5_000_000, -291), ("Mom", "Mẹ gửi - Feb", .received, 10_000_000, -286),
            ("Mom", "Mẹ gửi - Mar", .received, 10_000_000, -259), ("Grand", "Bà Ngoại gửi", .received, 5_000_000, -254),
            ("Mom", "Lãi cho Mom", .interest, 1_200_000, -60),
        ].enumerated().map { k, l in
            FamilyLoan(id: id("loan-\(k)"), who: l.0, title: l.1, kind: l.2, amount: l.3, date: Day.addDays(today, l.4), sample: true)
        }

        return Bundle(entries: entries, notes: notes, bills: bills, assets: assets, moves: moves, care: care, loans: loans,
                      worth: worth, birthYear: ty - 27)
    }
}
