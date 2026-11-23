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

    /// Where a sample line was paid from (or received into), the same every load.
    private static func paidFrom(_ c: Category, _ flow: Flow, _ n: Int) -> String {
        if flow == .in { return ["Vietcombank", "Vietcombank", "MoMo", "TP Bank"][n % 4] }
        switch c {
        case .food: return ["Cash", "MoMo", "Cash", "ZaloPay"][n % 4]
        case .transport: return ["Cash", "MoMo"][n % 2]
        case .shopping: return ["Card", "TP Bank", "ShopeePay"][n % 3]
        case .bills: return "Vietcombank"
        default: return ["Vietcombank", "MoMo", "Card", "Cash"][n % 4]
        }
    }

    /// The rest of Due: more bills, installments from finance companies, and one-off payments —
    /// tuition, insurance, paying friends back (one already done last month).
    private static func moreBills(thisMonth: String, now: Date,
                                  paidMonths: (Int, Int, Int) -> [String: PaidRecord]) -> [Bill] {
        let last = Month.add(thisMonth, -1), next = Month.add(thisMonth, 1)
        func once(_ month: String, _ amount: Int, daysAgo: Double) -> [String: PaidRecord] {
            [month: PaidRecord(amount: amount, at: now.addingTimeInterval(-daysAgo * 86_400))]
        }
        return [
            Bill(id: id("building"), kind: .recurring, name: "Phí quản lý chung cư", icon: .house, amount: 350_000,
                 start: addMonthsIso("\(thisMonth)-01", -8), payWith: "Vietcombank", paid: paidMonths(0, 8, 350_000),
                 createdAt: now, sample: true),
            Bill(id: id("mobile"), kind: .recurring, name: "Gói cước Viettel", icon: .phone, amount: 150_000,
                 start: addMonthsIso("\(thisMonth)-28", -6), payWith: "MoMo", paid: paidMonths(1, 6, 150_000),
                 createdAt: now, sample: true),
            Bill(id: id("gas"), kind: .recurring, name: "Gas nấu ăn", icon: .gasPump, amount: 380_000, varies: true,
                 start: addMonthsIso("\(thisMonth)-26", -4), payWith: "Cash", paid: paidMonths(1, 4, 375_000),
                 createdAt: now, sample: true),
            Bill(id: id("laptop"), kind: .installment, name: "MacBook Air", icon: .monitor, amount: 2_150_000,
                 start: addMonthsIso("\(thisMonth)-08", -2), payWith: "Vietcombank", lender: "FE Credit",
                 principal: 24_000_000, payments: 12, rate: 1.2, fee: 0, paid: paidMonths(0, 2, 2_150_000),
                 createdAt: now, sample: true),
            Bill(id: id("bike"), kind: .installment, name: "Xe Vision", icon: .gasPump, amount: 1_850_000,
                 start: addMonthsIso("\(thisMonth)-22", -10), payWith: "MoMo", lender: "HD Saison",
                 principal: 31_000_000, payments: 18, rate: 0.9, fee: 0, paid: paidMonths(1, 10, 1_850_000),
                 createdAt: now, sample: true),
            Bill(id: id("tuition"), kind: .oneoff, name: "Học phí học kỳ 2", icon: .student, amount: 8_500_000,
                 start: "\(next)-10", payWith: "Vietcombank", createdAt: now, sample: true),
            Bill(id: id("insure"), kind: .oneoff, name: "Bảo hiểm xe máy", icon: .bell, amount: 66_000,
                 start: "\(thisMonth)-27", payWith: "Cash", createdAt: now, sample: true),
            Bill(id: id("minh"), kind: .oneoff, name: "Trả tiền vé concert", icon: .bell, amount: 2_000_000,
                 start: "\(thisMonth)-30", payWith: "MoMo", lender: "Minh", createdAt: now, sample: true),
            Bill(id: id("lan"), kind: .oneoff, name: "Trả tiền lẩu", icon: .bell, amount: 450_000,
                 start: "\(last)-20", payWith: "MoMo", lender: "Lan", paid: once(last, 450_000, daysAgo: 30),
                 createdAt: now, sample: true),
            Bill(id: id("wedding"), kind: .oneoff, name: "Mừng cưới Huy", icon: .bell, amount: 1_000_000,
                 start: "\(next)-14", payWith: "Cash", lender: "Huy", createdAt: now, sample: true),
        ]
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
                let e = Entry(
                    id: id("e-\(i)-\(j)"), date: date, title: it.title, amount: it.amount, flow: it.flow,
                    category: it.category, noteId: noteId, source: source,
                    createdAt: midnight.addingTimeInterval(it.hour * 3600 + minutes[j]),
                    sample: true)
                e.paidFrom = paidFrom(it.category, it.flow, i * 7 + j)
                entries.append(e)
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
                 start: addMonthsIso("\(thisMonth)-12", -8), code: "PE0400123456", payWith: "MoMo", paid: paidMonths(0, 8, 410_000), createdAt: now, sample: true),
            Bill(id: id("water"), kind: .recurring, name: "Water Bill", icon: .drop, amount: 120_000, varies: true,
                 start: addMonthsIso(day15, -8), code: "WT2451234151", payWith: "Vietcombank", paid: paidMonths(0, 8, 118_000), createdAt: now, sample: true),
            Bill(id: id("net"), kind: .recurring, name: "Internet", icon: .phone, amount: 220_000,
                 start: addMonthsIso("\(thisMonth)-20", -8), payWith: "Card", paid: paidMonths(0, 8, 220_000), createdAt: now, sample: true),
            Bill(id: id("iphone"), kind: .installment, name: "iPhone 15 Pro", icon: .phone, amount: 1_100_000,
                 start: addMonthsIso("\(thisMonth)-25", -3), payWith: "TP Bank", lender: "TP Bank", principal: 12_120_000,
                 payments: 12, rate: 0, fee: 1.5, paid: paidMonths(1, 3, 1_100_000), createdAt: now, sample: true),
            Bill(id: id("course"), kind: .installment, name: "English Course", icon: .student, amount: 367_000,
                 start: addMonthsIso("\(thisMonth)-18", -5), lender: "Home Credit", principal: 2_200_000,
                 payments: 6, rate: 0, fee: 0, paid: paidMonths(1, 5, 367_000), createdAt: now, sample: true),
        ] + moreBills(thisMonth: thisMonth, now: now, paidMonths: paidMonths)

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
                entry.paidFrom = bill.payWith
                entries.append(entry)
                records[month]?.entryId = entry.id
            }
            bill.paid = records
        }

        // Assets from Nin's Investment Diary: every time money went in (or came out), on its real
        // day, from the first fund in Oct 2021. Then what each is worth now (gold and the fund up,
        // stocks down, cash and savings as they were). Each one keeps its moves, so Total Asset can
        // show put in, now and the gain or loss, and the line has a dot for every deposit.
        let d = { (ago: Int) in Day.addDays(today, ago) }
        let fundIns: [(Int, String)] = [
            (5_300_000, "2021-10-21"), (4_000_000, "2021-10-22"), (5_000_000, "2021-11-23"), (5_200_000, "2021-11-26"),
            (5_000_000, "2021-12-22"), (10_000_000, "2021-12-24"),
            (5_000_000, "2022-01-20"), (2_000_000, "2022-01-21"), (2_000_000, "2022-02-22"),
            (750_000, "2023-01-30"), (3_000_000, "2023-02-23"), (100_000, "2023-11-24"),
            (2_000_000, "2024-01-23"), (4_000_000, "2024-02-22"), (2_000_000, "2024-02-22"), (500_000, "2024-02-22"),
            (1_000_000, "2024-03-04"), (2_000_000, "2024-03-21"), (2_000_000, "2024-03-21"), (500_000, "2024-04-23"),
            (1_000_000, "2024-05-23"), (2_000_000, "2024-05-23"), (3_000_000, "2024-06-21"), (2_500_000, "2024-08-08"),
            (200_000, "2024-08-29"), (3_000_000, "2024-09-05"), (500_000, "2024-09-24"), (1_500_000, "2024-11-21"),
            (2_000_000, "2024-12-12"),
            (5_000_000, "2025-03-21"), (1_000_000, "2025-04-14"), (1_000_000, "2025-04-23"), (1_500_000, "2025-05-19"),
            (700_000, "2025-06-22"), (500_000, "2025-07-22"), (1_000_000, "2025-07-30"),
        ]
        // Stock, with money from Mom and Grandma put straight in, and one 60M taken out.
        let stockIns: [(Int, String)] = [
            (5_500_000, "2025-04-08"), (4_500_000, "2025-04-11"), (10_000_000, "2025-04-22"), (3_000_000, "2025-05-13"),
            (5_000_000, "2025-05-16"), (2_000_000, "2025-06-19"), (6_500_000, "2025-07-18"), (6_300_000, "2025-07-29"),
            (1_300_000, "2025-09-19"), (20_000_000, "2025-09-20"), (10_000_000, "2025-10-11"), (-60_000_000, "2025-10-28"),
            (10_000_000, "2025-11-11"), (25_000_000, "2026-01-12"), (8_000_000, "2026-01-14"), (10_000_000, "2026-01-31"),
            (5_000_000, "2026-02-01"), (10_000_000, "2026-02-06"), (20_000_000, "2026-03-05"), (5_000_000, "2026-03-10"),
            (1_200_000, "2026-09-20"),
        ]
        typealias Holding = (key: String, name: String, kind: AssetKind, icon: AssetIcon, ins: [(Int, String)], now: Int)
        let goldIns: [(Int, String)] = Array(repeating: (5_575_000, "2022-08-10"), count: 4) + [(7_700_000, "2024-08-10")]
        let vndIns: [(Int, String)] = [(1_000_000, "2023-05-01"), (2_000_000, "2025-05-25"), (1_000_000, "2026-02-17")]
        let usdIns: [(Int, String)] = [(2_600_000, "2023-08-10"), (4_500_000, "2025-04-10"), (13_000_000, "2026-02-26")]
        let saveIns: [(Int, String)] = [(1_000_000, d(-88))]
        let coinIns: [(Int, String)] = [(200_000, "2026-02-20")]
        var holdings: [Holding] = []
        holdings.append(("vnd", "VND", .available, .cash, vndIns, 4_000_000))
        holdings.append(("usd", "USD", .available, .usd, usdIns, 20_000_000))
        holdings.append(("saving", "Saving", .aside, .bank, saveIns, 1_000_000))
        holdings.append(("gold", "Gold", .growing, .gold, goldIns, 65_000_000))
        holdings.append(("fund", "Fund", .growing, .fund, fundIns, 110_000_000))
        holdings.append(("stock", "Stock", .growing, .stock, stockIns, 75_000_000))
        holdings.append(("coin", "Coin", .growing, .coin, coinIns, 200_000))
        // Only what has happened by today, oldest first.
        for i in holdings.indices {
            holdings[i].ins = holdings[i].ins.filter { $0.1 <= today }.sorted { $0.1 < $1.1 }
        }
        var assets: [Asset] = []
        var moves: [AssetMove] = []
        for h in holdings {
            let assetId = id(h.key)
            let put = h.ins.reduce(0) { $0 + $1.0 }
            let valued = h.now != put ? d(-3) : (h.ins.map(\.1).max() ?? today)
            let asset = Asset(id: assetId, name: h.name, kind: h.kind, icon: h.icon, amount: h.now, updated: valued, sample: true)
            // Gold, dollars and coins are kept in their own unit; prices turn them into đồng.
            switch h.key {
            case "gold": (asset.quantity, asset.unit) = (6, .chi)
            case "usd": (asset.quantity, asset.unit) = (780, .usd)
            case "coin": (asset.quantity, asset.unit) = (0.00013, .btc)
            default: break
            }
            assets.append(asset)
            for (k, (amount, day)) in h.ins.enumerated() {
                moves.append(AssetMove(id: id("m-\(h.key)-\(k)"), title: h.name, icon: h.icon, amount: amount,
                                       date: day, sample: true, assetId: assetId, kind: amount < 0 ? .takeOut : .putIn))
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

        // Total assets month by month, from 0đ the month before the first deposit: what was put in
        // so far, with each asset's gain or loss growing in step until it reaches today's worth.
        let total = assets.reduce(0) { $0 + $1.amount }
        let (ty, _, _) = Day.parts(today)
        let nowMonth = Month.of(today)
        let firstMonth = Month.add(Month.of(holdings.flatMap(\.ins).map(\.1).min() ?? today), -1)
        var worth: [WorthPoint] = []
        var month = firstMonth
        while month <= nowMonth {
            var value = 0.0
            for h in holdings {
                let put = h.ins.filter { Month.of($0.1) <= month }.reduce(0) { $0 + $1.0 }
                let all = h.ins.reduce(0) { $0 + $1.0 }
                guard put > 0, all > 0, let first = h.ins.first.map({ Month.of($0.1) }) else { continue }
                let span = max(Month.between(first, nowMonth), 1)
                let f = min(max(Double(Month.between(first, month)) / Double(span), 0), 1)
                value += Double(put) * (1 + (Double(h.now) / Double(all) - 1) * f)
            }
            worth.append(WorthPoint(month: month, value: month == nowMonth ? total : Int(value.rounded()), sample: true))
            month = Month.add(month, 1)
        }

        // Family loans at 6% a year: money from Mom and Grandma, and interest paid to Mom.
        let loans: [FamilyLoan] = [
            ("Mom", "Mẹ gửi", LoanMove.received, 20_000_000, "2025-09-20"), ("Grand", "Bà Ngoại gửi", .received, 25_000_000, "2026-01-12"),
            ("Grand", "Bà Ngoại - Feb", .received, 5_000_000, "2026-02-01"), ("Mom", "Mẹ gửi - Feb", .received, 10_000_000, "2026-02-06"),
            ("Mom", "Mẹ gửi - Mar", .received, 20_000_000, "2026-03-05"), ("Grand", "Bà Ngoại gửi", .received, 5_000_000, "2026-03-10"),
            ("Mom", "Lãi cho Mom", .interest, 1_200_000, "2026-09-20"),
        ].filter { $0.4 <= today }.enumerated().map { k, l in
            FamilyLoan(id: id("loan-\(k)"), who: l.0, title: l.1, kind: l.2, amount: l.3, date: l.4, sample: true)
        }

        return Bundle(entries: entries, notes: notes, bills: bills, assets: assets, moves: moves, care: care, loans: loans,
                      worth: worth, birthYear: ty - 27)
    }
}
