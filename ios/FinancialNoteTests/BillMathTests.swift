import XCTest
@testable import FinancialNote

@MainActor
final class BillMathTests: XCTestCase {
    func testRecurringBillIsDueEveryMonthOnTheSameDay() {
        let rent = Bill(kind: .recurring, name: "Rent", icon: .house, amount: 2_500_000, start: "2026-03-05")
        XCTAssertNil(BillMath.dueIn(rent, month: "2026-02"))
        XCTAssertEqual(BillMath.dueIn(rent, month: "2026-03"), "2026-03-05")
        XCTAssertEqual(BillMath.dueIn(rent, month: "2027-01"), "2027-01-05")
    }

    func testDayIsCappedAtTheEndOfShortMonths() {
        let bill = Bill(kind: .recurring, name: "Phone", icon: .phone, amount: 100_000, start: "2026-01-31")
        XCTAssertEqual(BillMath.dueIn(bill, month: "2026-02"), "2026-02-28")
        XCTAssertEqual(BillMath.dueIn(bill, month: "2028-02"), "2028-02-29")
        XCTAssertEqual(BillMath.dueIn(bill, month: "2026-04"), "2026-04-30")
    }

    func testOneOffIsDueOnlyOnce() {
        let bill = Bill(kind: .oneoff, name: "Visa", icon: .bell, amount: 500_000, start: "2026-10-20")
        XCTAssertEqual(BillMath.dueIn(bill, month: "2026-10"), "2026-10-20")
        XCTAssertNil(BillMath.dueIn(bill, month: "2026-11"))
    }

    func testInstallmentStopsAfterTheLastPayment() {
        let bill = Bill(kind: .installment, name: "iPhone", icon: .phone, amount: 1_100_000, start: "2026-08-25", payments: 3)
        XCTAssertEqual(BillMath.dueIn(bill, month: "2026-10"), "2026-10-25")
        XCTAssertNil(BillMath.dueIn(bill, month: "2026-11"))
        XCTAssertEqual(BillMath.lastDue(bill), "2026-10-25")
    }

    func testInstallmentStep() {
        let paid = ["2026-08": PaidRecord(amount: 1_100_000, at: .now)]
        let bill = Bill(kind: .installment, name: "iPhone", icon: .phone, amount: 1_100_000, start: "2026-08-25", payments: 12, paid: paid)
        XCTAssertEqual(BillMath.installmentStep(bill, month: "2026-10"), .init(index: 3, total: 12, paidCount: 1, left: 11))
    }

    func testInstallmentPayment() {
        XCTAssertEqual(BillMath.installmentPayment(principal: 12_000_000, payments: 12, ratePct: 0), 1_000_000)
        XCTAssertEqual(BillMath.installmentPayment(principal: 12_000_000, payments: 12, ratePct: 1.5), 1_180_000)
        XCTAssertEqual(BillMath.installmentPayment(principal: 0, payments: 12, ratePct: 1), 0)
    }

    func testMonthSummary() {
        let rent = Bill(kind: .recurring, name: "Rent", icon: .house, amount: 2_500_000, start: "2026-01-05",
                        paid: ["2026-10": PaidRecord(amount: 2_500_000, at: .now)])
        let power = Bill(kind: .recurring, name: "Electricity", icon: .lightning, amount: 420_000, start: "2026-01-12")
        let phone = Bill(kind: .installment, name: "iPhone", icon: .phone, amount: 1_000_000, start: "2026-09-25", payments: 4,
                         paid: ["2026-09": PaidRecord(amount: 1_000_000, at: .now)])
        let s = BillMath.monthSummary([phone, power, rent], month: "2026-10")
        XCTAssertEqual(s.due.map(\.bill.name), ["Rent", "Electricity", "iPhone"])
        XCTAssertEqual(s.still.map(\.bill.name), ["Electricity", "iPhone"])
        XCTAssertEqual(s.done.map(\.bill.name), ["Rent"])
        XCTAssertEqual(s.paid, 2_500_000)
        XCTAssertEqual(s.remaining, 1_420_000)
        // Plus the two iPhone payments still to come in Nov and Dec.
        XCTAssertEqual(s.totalRemaining, 3_420_000)
    }

    func testGuessIcon() {
        XCTAssertEqual(BillMath.guessIcon("Tiền nhà", kind: .recurring), .house)
        XCTAssertEqual(BillMath.guessIcon("Điện EVN", kind: .recurring), .lightning)
        XCTAssertEqual(BillMath.guessIcon("English course", kind: .installment), .student)
        XCTAssertEqual(BillMath.guessIcon("Something", kind: .installment), .phone)
        XCTAssertEqual(BillMath.guessIcon("Something", kind: .recurring), .bell)
    }

    func testMonthMaths() {
        XCTAssertEqual(Month.add("2026-11", 2), "2027-01")
        XCTAssertEqual(Month.add("2026-01", -1), "2025-12")
        XCTAssertEqual(Month.between("2025-11", "2026-02"), 3)
        XCTAssertEqual(Day.addDays("2026-03-01", -1), "2026-02-28")
        XCTAssertEqual(Day.long("2026-08-07"), "August 07, 2026")
        XCTAssertEqual(Day.short("2026-08-07"), "07 Aug")
        XCTAssertEqual(Money.format(1_234_000), "1,234,000")
    }
}
