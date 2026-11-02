import XCTest
@testable import FinancialNote

@MainActor
final class DueTests: XCTestCase {
    private func bill(_ kind: BillKind = .recurring, start: String = "2026-01-15", amount: Int = 100_000,
                      payments: Int? = nil, paid: [String: PaidRecord] = [:]) -> Bill {
        Bill(kind: kind, name: "Water", icon: .drop, amount: amount, start: start, payments: payments, paid: paid)
    }

    func testLabels() {
        XCTAssertEqual(DueText.monthLabel("2026-08"), "August, 2026")
        XCTAssertEqual(DueText.dueLabel("2026-09-05"), "Sep 5")
        XCTAssertEqual(DueText.ddmmyyyy("2026-09-05"), "05/09/2026")
        XCTAssertEqual(DueText.short(420_000), "420,000")
        XCTAssertEqual(DueText.short(2_500_000), "2.5 M")
        XCTAssertEqual(DueText.short(5_034_000), "5.034 M")
    }

    /// Product rule: no "overdue" — a past date reads "Was due Oct 15", never an alarm.
    func testPastDueReadsWasDue() {
        let b = bill()
        XCTAssertEqual(DueText.status(b, month: "2026-10", today: "2026-10-20"), "Was due Oct 15")
        XCTAssertEqual(DueText.status(b, month: "2026-10", today: "2026-10-10"), "Due Oct 15")
        XCTAssertEqual(DueText.listDate("2026-10-15", paid: false, today: "2026-10-20"), "Was due Oct 15")
        XCTAssertEqual(DueText.listDate("2026-10-15", paid: true, today: "2026-10-20"), "Oct 15")
        for s in [DueText.status(b, month: "2026-10", today: "2026-12-31")] {
            XCTAssertFalse(s.lowercased().contains("overdue"))
            XCTAssertFalse(s.lowercased().contains("late"))
        }
    }

    func testStatusDoneAndNotDue() {
        let b = bill(.oneoff, start: "2026-10-15", paid: ["2026-10": PaidRecord(amount: 1, at: .now)])
        XCTAssertEqual(DueText.status(b, month: "2026-10", today: "2026-10-20"), "Done")
        XCTAssertEqual(DueText.status(b, month: "2026-11", today: "2026-10-20"), "Not due this month")
    }

    func testNextDueSkipsPaidMonths() {
        let b = bill(paid: ["2026-10": PaidRecord(amount: 1, at: .now)])
        XCTAssertEqual(DueText.nextDue(b, today: "2026-10-20"), "2026-11-15")
        XCTAssertNil(DueText.nextDue(bill(.installment, start: "2025-01-15", payments: 3), today: "2026-10-20"))
    }

    func testInstallmentLine() {
        let paid = ["2026-08": PaidRecord(amount: 1, at: .now), "2026-09": PaidRecord(amount: 1, at: .now)]
        XCTAssertEqual(DueText.installmentLine(bill(.installment, start: "2026-08-15", payments: 3, paid: paid), month: "2026-10"),
                       "Last one — done this month")
        XCTAssertEqual(DueText.installmentLine(bill(.installment, start: "2026-08-15", payments: 6), month: "2026-10"),
                       "6 left · ends 15/01/2027")
    }

    func testMonthTotalUsesWhatWasPaid() {
        let paid = bill(amount: 120_000, paid: ["2026-10": PaidRecord(amount: 118_000, at: .now)])
        let open = bill(amount: 220_000)
        XCTAssertEqual(DueText.monthTotal([paid, open], month: "2026-10"), 338_000)
    }

    func testAddBillDraft() {
        var d = BillDraft(month: "2026-10", today: "2026-10-28")
        XCTAssertEqual(d.due, "2026-10-28")
        XCTAssertEqual(BillDraft(month: "2026-12", today: "2026-10-28").due, "2026-12-15")
        XCTAssertNil(d.makeBill(), "no kind yet")

        d.kind = .installment
        d.name = "  MacBook M5  "
        d.principal = 12_000_000
        d.payments = 12
        d.rate = 1.5
        XCTAssertEqual(d.each, 1_180_000)
        let b = d.makeBill()
        XCTAssertEqual(b?.name, "MacBook M5")
        XCTAssertEqual(b?.icon, .monitor)
        XCTAssertEqual(b?.amount, 1_180_000)
        XCTAssertEqual(b?.payments, 12)
        XCTAssertFalse(b?.varies ?? true)

        var r = BillDraft(month: "2026-10", today: "2026-10-28", kind: .recurring)
        r.name = "Tiền điện"
        r.varies = true
        XCTAssertNil(r.makeBill(), "needs an amount")
        r.amount = 420_000
        XCTAssertEqual(r.makeBill()?.icon, .lightning)
        XCTAssertTrue(r.makeBill()?.varies ?? false)
        XCTAssertNil(r.makeBill()?.principal)
    }
}
