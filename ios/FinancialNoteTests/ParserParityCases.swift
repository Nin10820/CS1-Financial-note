// Generated from the web parser (src/lib/parse.ts) run under Node on 2026-10-28.
// Each case is what the web app reads today; the Swift port must read the same.
@testable import FinancialNote

enum ParserParityCases {
    static let day = "2026-10-28"
    static let all: [(text: String, expected: [Draft])] = [
        ("cơm tấm 35k, cafe 40k", [
            Draft(title: "Cơm tấm", amount: 35000, flow: .out, category: .food, date: "2026-10-28", assumedThousands: false),
            Draft(title: "Cafe", amount: 40000, flow: .out, category: .food, date: "2026-10-28", assumedThousands: false),
        ]),
        ("24k", [
            Draft(title: "Other", amount: 24000, flow: .out, category: .other, date: "2026-10-28", assumedThousands: false),
        ]),
        ("35.000", [
            Draft(title: "Other", amount: 35000, flow: .out, category: .other, date: "2026-10-28", assumedThousands: false),
        ]),
        ("35,000", [
            Draft(title: "Other", amount: 35000, flow: .out, category: .other, date: "2026-10-28", assumedThousands: false),
        ]),
        ("1tr2", [
            Draft(title: "Other", amount: 1200000, flow: .out, category: .other, date: "2026-10-28", assumedThousands: false),
        ]),
        ("2tr5", [
            Draft(title: "Other", amount: 2500000, flow: .out, category: .other, date: "2026-10-28", assumedThousands: false),
        ]),
        ("1.5tr", [
            Draft(title: "Other", amount: 1500000, flow: .out, category: .other, date: "2026-10-28", assumedThousands: false),
        ]),
        ("1,5tr", [
            Draft(title: "Other", amount: 1500000, flow: .out, category: .other, date: "2026-10-28", assumedThousands: false),
        ]),
        ("100k", [
            Draft(title: "Other", amount: 100000, flow: .out, category: .other, date: "2026-10-28", assumedThousands: false),
        ]),
        ("cafe 45", [
            Draft(title: "Cafe", amount: 45000, flow: .out, category: .food, date: "2026-10-28", assumedThousands: true),
        ]),
        ("hôm qua phở 50k", [
            Draft(title: "Phở", amount: 50000, flow: .out, category: .food, date: "2026-10-27", assumedThousands: false),
        ]),
        ("yesterday grab 60k", [
            Draft(title: "Grab", amount: 60000, flow: .out, category: .transport, date: "2026-10-27", assumedThousands: false),
        ]),
        ("hôm nay bánh mì 25k", [
            Draft(title: "Bánh mì", amount: 25000, flow: .out, category: .food, date: "2026-10-28", assumedThousands: false),
        ]),
        ("Lunch, broken rice 40k", [
            Draft(title: "Lunch, broken rice", amount: 40000, flow: .out, category: .food, date: "2026-10-28", assumedThousands: false),
        ]),
        ("Milk tea 35k · cash", [
            Draft(title: "Milk tea", amount: 35000, flow: .out, category: .food, date: "2026-10-28", assumedThousands: false),
        ]),
        ("Petrol 100k · transfer", [
            Draft(title: "Petrol", amount: 100000, flow: .out, category: .transport, date: "2026-10-28", assumedThousands: false),
        ]),
        ("xăng 100k tiền mặt", [
            Draft(title: "Xăng", amount: 100000, flow: .out, category: .transport, date: "2026-10-28", assumedThousands: false),
        ]),
        ("Peter paid me back 45k", [
            Draft(title: "Peter paid me back", amount: 45000, flow: .`in`, category: .received, date: "2026-10-28", assumedThousands: false),
        ]),
        ("Minh trả lại 200k", [
            Draft(title: "Minh trả lại", amount: 200000, flow: .`in`, category: .received, date: "2026-10-28", assumedThousands: false),
        ]),
        ("lương 18tr5", [
            Draft(title: "Lương", amount: 18500000, flow: .`in`, category: .received, date: "2026-10-28", assumedThousands: false),
        ]),
        ("coffee 29k", [
            Draft(title: "Coffee", amount: 29000, flow: .out, category: .food, date: "2026-10-28", assumedThousands: false),
        ]),
        ("phí chuyển khoản 11k", [
            Draft(title: "Phí", amount: 11000, flow: .out, category: .bills, date: "2026-10-28", assumedThousands: false),
        ]),
        ("internet 220k", [
            Draft(title: "Internet", amount: 220000, flow: .out, category: .bills, date: "2026-10-28", assumedThousands: false),
        ]),
        ("rent 2.5tr", [
            Draft(title: "Rent", amount: 2500000, flow: .out, category: .bills, date: "2026-10-28", assumedThousands: false),
        ]),
        ("bills 420k", [
            Draft(title: "Bills", amount: 420000, flow: .out, category: .bills, date: "2026-10-28", assumedThousands: false),
        ]),
        ("cafe 30k và bánh mì 20k", [
            Draft(title: "Cafe", amount: 30000, flow: .out, category: .food, date: "2026-10-28", assumedThousands: false),
            Draft(title: "Bánh mì", amount: 20000, flow: .out, category: .food, date: "2026-10-28", assumedThousands: false),
        ]),
        ("grab 42k + cơm 35k", [
            Draft(title: "Grab", amount: 42000, flow: .out, category: .transport, date: "2026-10-28", assumedThousands: false),
            Draft(title: "Cơm", amount: 35000, flow: .out, category: .food, date: "2026-10-28", assumedThousands: false),
        ]),
        ("cơm 35k; phở 55k", [
            Draft(title: "Cơm", amount: 35000, flow: .out, category: .food, date: "2026-10-28", assumedThousands: false),
            Draft(title: "Phở", amount: 55000, flow: .out, category: .food, date: "2026-10-28", assumedThousands: false),
        ]),
        ("cơm 35k\nphở 55k", [
            Draft(title: "Cơm", amount: 35000, flow: .out, category: .food, date: "2026-10-28", assumedThousands: false),
            Draft(title: "Phở", amount: 55000, flow: .out, category: .food, date: "2026-10-28", assumedThousands: false),
        ]),
        ("shopee 199k", [
            Draft(title: "Shopee", amount: 199000, flow: .out, category: .shopping, date: "2026-10-28", assumedThousands: false),
        ]),
        ("haircut 80k", [
            Draft(title: "Haircut", amount: 80000, flow: .out, category: .other, date: "2026-10-28", assumedThousands: false),
        ]),
        ("cafe", [
            Draft(title: "Cafe", amount: nil, flow: .out, category: .food, date: "2026-10-28", assumedThousands: false),
        ]),
        ("50000", [
            Draft(title: "Other", amount: 50000, flow: .out, category: .other, date: "2026-10-28", assumedThousands: false),
        ]),
        ("120.000đ", [
            Draft(title: "Other", amount: 120000, flow: .out, category: .other, date: "2026-10-28", assumedThousands: false),
        ]),
        ("45 nghìn", [
            Draft(title: "Other", amount: 45000, flow: .out, category: .other, date: "2026-10-28", assumedThousands: false),
        ]),
        ("2 triệu", [
            Draft(title: "Other", amount: 2000000, flow: .out, category: .other, date: "2026-10-28", assumedThousands: false),
        ]),
        ("3m", [
            Draft(title: "Other", amount: 3000000, flow: .out, category: .other, date: "2026-10-28", assumedThousands: false),
        ]),
        ("250 vnd", [
            Draft(title: "Other", amount: 250, flow: .out, category: .other, date: "2026-10-28", assumedThousands: false),
        ]),
        ("bún chả 50k - cash", [
            Draft(title: "Bún chả", amount: 50000, flow: .out, category: .food, date: "2026-10-28", assumedThousands: false),
        ]),
        ("trà sữa 35k và", [
            Draft(title: "Trà sữa và", amount: 35000, flow: .out, category: .food, date: "2026-10-28", assumedThousands: false),
        ]),
        ("ăn sáng 30k, ck", [
            Draft(title: "Ăn sáng", amount: 30000, flow: .out, category: .food, date: "2026-10-28", assumedThousands: false),
            Draft(title: "Other", amount: nil, flow: .out, category: .other, date: "2026-10-28", assumedThousands: false),
        ]),
        ("Grab to work 42k", [
            Draft(title: "Grab to work", amount: 42000, flow: .out, category: .transport, date: "2026-10-28", assumedThousands: false),
        ]),
        ("tiền nhà 3tr", [
            Draft(title: "Tiền nhà", amount: 3000000, flow: .out, category: .bills, date: "2026-10-28", assumedThousands: false),
        ]),
        ("be 25k", [
            Draft(title: "Be", amount: 25000, flow: .out, category: .transport, date: "2026-10-28", assumedThousands: false),
        ]),
        ("gas 50k", [
            Draft(title: "Gas", amount: 50000, flow: .out, category: .transport, date: "2026-10-28", assumedThousands: false),
        ]),
        ("Parking 5k", [
            Draft(title: "Parking", amount: 5000, flow: .out, category: .transport, date: "2026-10-28", assumedThousands: false),
        ]),
        ("mua áo 199k", [
            Draft(title: "Mua áo", amount: 199000, flow: .out, category: .shopping, date: "2026-10-28", assumedThousands: false),
        ]),
        ("Coffee 29,5k", [
            Draft(title: "Coffee", amount: 29500, flow: .out, category: .food, date: "2026-10-28", assumedThousands: false),
        ]),
    ]
}
