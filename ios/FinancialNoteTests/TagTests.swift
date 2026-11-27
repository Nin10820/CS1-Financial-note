import XCTest
@testable import FinancialNote

@MainActor
final class TagTests: XCTestCase {
    func testSuggestedTags() {
        XCTAssertEqual(Tags.suggest(title: "Cafe with the team", category: .food), "Drinks")
        XCTAssertEqual(Tags.suggest(title: "Trà sữa", category: .food), "Drinks")
        XCTAssertEqual(Tags.suggest(title: "Cơm tấm", category: .food), "Food")
        XCTAssertEqual(Tags.suggest(title: "Snack", category: .food), "Snacks")
        XCTAssertEqual(Tags.suggest(title: "Bus card top-up", category: .transport), "Public Transit")
        XCTAssertNil(Tags.suggest(title: "Grab to work", category: .transport))
        XCTAssertEqual(Tags.suggest(title: "Petrol", category: .transport), "Gas")
        XCTAssertEqual(Tags.suggest(title: "T-shirt", category: .shopping), "Clothing")
        XCTAssertEqual(Tags.suggest(title: "Internet", category: .bills), "Internet & Phone")
        XCTAssertEqual(Tags.suggest(title: "Rent", category: .bills), "Housing")
        XCTAssertNil(Tags.suggest(title: "Salary", category: .received))
        // Every suggestion is one of the default tags.
        for name in ["Drinks", "Food", "Snacks", "Public Transit", "Gas", "Clothing", "Internet & Phone", "Housing"] {
            XCTAssertNotNil(Tags.info(name), name)
        }
    }

    func testParserReadsHowItWasPaid() {
        let d = NoteParser.parse("Milk tea 35k · cash, petrol 100k · transfer, cơm 30k", day: "2026-10-29")
        XCTAssertEqual(d.map(\.paidFrom), ["Cash", "Transfer", nil])
        XCTAssertEqual(d.map(\.title), ["Milk tea", "Petrol", "Cơm"])
        XCTAssertEqual(NoteParser.parse("xăng 100k tiền mặt", day: "2026-10-29").first?.paidFrom, "Cash")
        XCTAssertEqual(NoteParser.parse("áo 199k chuyển khoản", day: "2026-10-29").first?.paidFrom, "Transfer")
    }
}
