import XCTest
@testable import FinancialNote

/// The note reader must read every note exactly like the web app (`src/lib/parse.ts`).
@MainActor
final class NoteParserTests: XCTestCase {
    private let day = "2026-10-28"

    private func one(_ text: String) -> Draft {
        let list = NoteParser.parse(text, day: day)
        XCTAssertEqual(list.count, 1, "“\(text)” should give one line")
        return list.first ?? Draft(title: "", amount: nil, flow: .out, category: .other, date: "")
    }

    // MARK: - Same result as the web app, case by case

    func testMatchesWebParserForEveryCase() {
        for (text, expected) in ParserParityCases.all {
            XCTAssertEqual(NoteParser.parse(text, day: ParserParityCases.day), expected, "“\(text)”")
        }
    }

    // MARK: - Examples written in parse.ts

    func testOneLineSplitsIntoEntries() {
        let list = NoteParser.parse("cơm tấm 35k, cafe 40k", day: day)
        XCTAssertEqual(list.map(\.title), ["Cơm tấm", "Cafe"])
        XCTAssertEqual(list.map(\.amount), [35_000, 40_000])
    }

    func testShorthandAmounts() {
        XCTAssertEqual(one("24k").amount, 24_000)
        XCTAssertEqual(one("100k").amount, 100_000)
        XCTAssertEqual(one("35.000").amount, 35_000)
        XCTAssertEqual(one("35,000").amount, 35_000)
        XCTAssertEqual(one("1tr2").amount, 1_200_000)
        XCTAssertEqual(one("2tr5").amount, 2_500_000)
        XCTAssertEqual(one("1.5tr").amount, 1_500_000)
        XCTAssertEqual(one("1,5tr").amount, 1_500_000)
        XCTAssertEqual(one("120.000đ").amount, 120_000)
        XCTAssertEqual(one("45 nghìn").amount, 45_000)
        XCTAssertEqual(one("2 triệu").amount, 2_000_000)
    }

    func testBareSmallNumberMeansThousands() {
        let d = one("cafe 45")
        XCTAssertEqual(d.amount, 45_000)
        XCTAssertTrue(d.assumedThousands)
        XCTAssertFalse(one("cafe 45k").assumedThousands)
    }

    func testNoAmountLeavesItEmpty() {
        XCTAssertNil(one("cafe").amount)
    }

    func testYesterdayMovesTheDate() {
        XCTAssertEqual(one("hôm qua phở 50k").date, "2026-10-27")
        XCTAssertEqual(one("hôm qua phở 50k").title, "Phở")
        XCTAssertEqual(one("yesterday grab 60k").date, "2026-10-27")
        XCTAssertEqual(one("hôm nay bánh mì 25k").date, day)
    }

    func testMoneyComingIn() {
        let back = one("Peter paid me back 45k")
        XCTAssertEqual(back.flow, .in)
        XCTAssertEqual(back.category, .received)
        XCTAssertEqual(one("Minh trả lại 200k").flow, .in)
        XCTAssertEqual(one("lương 18tr5").amount, 18_500_000)
    }

    func testSplitsOnAndPlusAndSemicolon() {
        XCTAssertEqual(NoteParser.parse("cafe 30k và bánh mì 20k", day: day).count, 2)
        XCTAssertEqual(NoteParser.parse("grab 42k + cơm 35k", day: day).count, 2)
        XCTAssertEqual(NoteParser.parse("cơm 35k; phở 55k", day: day).count, 2)
        XCTAssertEqual(NoteParser.parse("cơm 35k\nphở 55k", day: day).count, 2)
    }

    // MARK: - Bugs fixed in the web app's git history

    /// d42f14d: "coffee" used to match the bill word "fee".
    func testCoffeeIsNotABill() {
        XCTAssertEqual(one("coffee 29k").category, .food)
        XCTAssertEqual(one("phí chuyển khoản 11k").category, .bills)
        XCTAssertEqual(one("bills 420k").category, .bills)
        XCTAssertEqual(one("rent 2.5tr").category, .bills)
    }

    /// 0eef272: "Lunch, broken rice 40k" used to split into two lines.
    func testCommaWithoutAmountStaysOneThing() {
        let d = one("Lunch, broken rice 40k")
        XCTAssertEqual(d.title, "Lunch, broken rice")
        XCTAssertEqual(d.amount, 40_000)
    }

    /// 0eef272: "· cash" / "· transfer" used to stay in the name.
    func testHowItWasPaidIsDroppedFromTheName() {
        XCTAssertEqual(one("Milk tea 35k · cash").title, "Milk tea")
        XCTAssertEqual(one("Petrol 100k · transfer").title, "Petrol")
        XCTAssertEqual(one("xăng 100k tiền mặt").title, "Xăng")
        XCTAssertEqual(one("bún chả 50k - cash").title, "Bún chả")
    }

    /// 0eef272: "rice" wasn't a food word.
    func testRiceIsFood() {
        XCTAssertEqual(one("Lunch, broken rice 40k").category, .food)
    }

    /// JS `\b` is ASCII-only; the port keeps that, so "be" (the ride app) still reads as Transport.
    func testWordBoundariesBehaveLikeTheWeb() {
        XCTAssertEqual(one("be 25k").category, .transport)
        XCTAssertEqual(one("gas 50k").category, .transport)
    }
}
