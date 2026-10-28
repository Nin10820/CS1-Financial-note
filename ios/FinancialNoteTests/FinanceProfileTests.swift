import SwiftData
import XCTest
@testable import FinancialNote

@MainActor
final class FinanceProfileTests: XCTestCase {
    func testLabels() {
        XCTAssertEqual(FinanceText.dayLabel("2026-08-21"), "21 Aug 2026")
        XCTAssertEqual(FinanceText.monthLabel("2026-09"), "Sep 2026")
    }

    func testGrowthNeedsAYearOfPoints() {
        let short = (1...12).map { (String(format: "2026-%02d", $0), 100) }
        XCTAssertNil(FinanceText.growth(short))
        var year = (1...12).map { (String(format: "2025-%02d", $0), 100) }
        year.append(("2026-01", 112))
        XCTAssertEqual(FinanceText.growth(year), 12)
    }

    func testSinceText() {
        let dates = ["2023-05-01", "2026-01-01"]
        XCTAssertEqual(FinanceText.since(careDates: dates, birthYear: 2000, today: "2026-10-29"),
                       "You have carried this since you were 23.")
        XCTAssertEqual(FinanceText.since(careDates: dates, birthYear: nil, today: "2026-10-29"),
                       "You have carried this since May 2023.")
    }

    func testCadence() {
        XCTAssertEqual(FinanceText.cadence(who: "Parents", firstTitle: "Parents support", count: 46), "every month, 46 times")
        XCTAssertEqual(FinanceText.cadence(who: "Young brother", firstTitle: "Sibling tuition", count: 4), "4 terms of tuition")
        XCTAssertEqual(FinanceText.cadence(who: "Household", firstTitle: "Household", count: 24), "24 bills")
    }

    func testFamilyShareIsOnlyTheLast30Days() {
        let share = FinanceText.familyShare(
            incoming: [("2026-10-20", 10_000_000), ("2026-08-01", 50_000_000)],
            care: [("2026-10-23", 1_500_000), ("2026-07-01", 9_000_000)],
            today: "2026-10-29")
        XCTAssertEqual(share, 15)
        XCTAssertNil(FinanceText.familyShare(incoming: [], care: [("2026-10-23", 1)], today: "2026-10-29"))
    }

    func testDebtCountsOnlyWhatIsLeft() {
        let paid = ["2026-08": PaidRecord(amount: 1, at: .now), "2026-09": PaidRecord(amount: 1, at: .now)]
        let phone = Bill(kind: .installment, name: "iPhone", icon: .phone, amount: 1_000_000, start: "2026-08-25", payments: 4, paid: paid)
        let done = Bill(kind: .installment, name: "Old", icon: .phone, amount: 500_000, start: "2025-01-01", payments: 1,
                        paid: ["2025-01": PaidRecord(amount: 1, at: .now)])
        let rent = Bill(kind: .recurring, name: "Rent", icon: .house, amount: 2_500_000, start: "2026-01-05")
        let d = FinanceText.debt([phone, done, rent])
        XCTAssertEqual(d.rows.map(\.bill.name), ["iPhone"])
        XCTAssertEqual(d.total, 2_000_000)
    }

    func testDeleteNeedsTheWordDelete() {
        XCTAssertTrue(DeleteAllView.confirms("DELETE"))
        XCTAssertTrue(DeleteAllView.confirms(" delete "))
        XCTAssertFalse(DeleteAllView.confirms("DEL"))
        XCTAssertFalse(DeleteAllView.confirms(""))
    }

    func testExportHoldsEverythingAndReadsBack() throws {
        let container = try ModelContainer(for: Schema(AppSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = LocalStore(context: container.mainContext)
        store.prepareOnLaunch(today: "2026-10-29")
        let file = ExportFile(store: store)
        XCTAssertEqual(file.entries.count, 22)
        XCTAssertEqual(file.bills.count, 6)
        XCTAssertEqual(file.assets.count, 5)
        XCTAssertEqual(file.notes.count, 2)
        XCTAssertEqual(file.prefs.joined, "2026-10-29")
        let data = try file.data()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let back = try decoder.decode(ExportFile.self, from: data)
        XCTAssertEqual(back.entries.map(\.id), file.entries.map(\.id))
        XCTAssertEqual(back.bills.first { $0.id == "sample-rent" }?.paid.count, 9)
        // Dates stay as plain "YYYY-MM-DD" text, like the web app's export.
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"date\" : \"2026-10-29\""))
    }

    func testAddingAnAssetWritesItsFirstHistoryLine() throws {
        let container = try ModelContainer(for: Schema(AppSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = LocalStore(context: container.mainContext)
        store.addAsset(Asset(name: "Vàng", kind: .growing, icon: .gold, amount: 5_000_000, updated: "2026-10-29"))
        XCTAssertEqual(store.all(AssetMove.self).map(\.amount), [5_000_000])
        XCTAssertEqual(store.all(AssetMove.self).first?.date, "2026-10-29")
    }
}
