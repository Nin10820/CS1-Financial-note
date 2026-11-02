import XCTest
@testable import FinancialNote

@MainActor
final class LocalAnswersTests: XCTestCase {
    private let today = "2026-10-30"

    private var lines: [LocalAnswers.Line] {
        [
            .init(date: "2026-10-30", title: "Cơm tấm", amount: 35_000, flow: .out, category: .food),
            .init(date: "2026-10-30", title: "Grab", amount: 42_000, flow: .out, category: .transport),
            .init(date: "2026-10-27", title: "Book", amount: 120_000, flow: .out, category: .shopping),
            .init(date: "2026-10-05", title: "Salary", amount: 18_500_000, flow: .in, category: .received),
            .init(date: "2026-09-20", title: "Phở", amount: 50_000, flow: .out, category: .food),
        ]
    }

    func testReadsQuestions() {
        XCTAssertEqual(LocalAnswers.ask(for: "What did I spend today?"), .today)
        XCTAssertEqual(LocalAnswers.ask(for: "hôm nay tiêu bao nhiêu"), .today)
        XCTAssertEqual(LocalAnswers.ask(for: "tuần này chi bao nhiêu?"), .week)
        XCTAssertEqual(LocalAnswers.ask(for: "Which bills are left?"), .bills)
        XCTAssertEqual(LocalAnswers.ask(for: "tháng trước thế nào"), .lastMonth)
        XCTAssertEqual(LocalAnswers.ask(for: "Where did this month go?"), .month)
        XCTAssertEqual(LocalAnswers.ask(for: "lương tháng này"), .received)
    }

    func testNotesAreNotQuestions() {
        XCTAssertNil(LocalAnswers.ask(for: "cơm tấm 35k, cafe 40k"))
        XCTAssertNil(LocalAnswers.ask(for: "hôm qua phở 50k"))
        XCTAssertNil(LocalAnswers.ask(for: "grab 42000"))
    }

    func testToday() {
        let r = LocalAnswers.report(.today, lines: lines, bills: [], today: today)
        XCTAssertEqual(r.summary, "You spent 77,000 đ today, 2 items.")
        XCTAssertEqual(r.rows.map(\.label), ["Transport", "Food"])
    }

    func testWeekAndMonth() {
        XCTAssertEqual(LocalAnswers.report(.week, lines: lines, bills: [], today: today).rows.first?.label, "Shopping")
        let m = LocalAnswers.report(.month, lines: lines, bills: [], today: today)
        XCTAssertEqual(m.summary, "You spent 197,000 đ in October, 3 items.")
        XCTAssertEqual(LocalAnswers.report(.lastMonth, lines: lines, bills: [], today: today).summary,
                       "You spent 50,000 đ in September, 1 item.")
    }

    func testReceivedAndBills() {
        XCTAssertEqual(LocalAnswers.report(.received, lines: lines, bills: [], today: today).summary,
                       "18,500,000 đ came in this month.")
        let rent = Bill(kind: .recurring, name: "Rent", icon: .house, amount: 2_500_000, start: "2026-01-05")
        let r = LocalAnswers.report(.bills, lines: [], bills: [rent], today: today)
        XCTAssertEqual(r.summary, "1 bill left, 2,500,000 đ in total.")
        XCTAssertEqual(r.rows.first?.detail, "Was due Oct 5")
    }

    /// Product rule: facts only, never a judgement on spending.
    func testNoAdviceWords() {
        for ask in LocalAnswers.Ask.allCases {
            let r = LocalAnswers.report(ask, lines: lines, bills: [], today: today)
            let text = (r.summary + r.rows.map(\.label).joined()).lowercased()
            for word in ["too much", "should", "overspend", "save more", "budget", "invest"] {
                XCTAssertFalse(text.contains(word), "\(ask): \(word)")
            }
        }
    }
}
