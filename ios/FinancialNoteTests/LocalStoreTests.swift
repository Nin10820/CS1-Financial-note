import SwiftData
import UIKit
import XCTest
@testable import FinancialNote

@MainActor
final class LocalStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var store: LocalStore!
    private let today = "2026-10-28"

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Schema(AppSchema.models), configurations: config)
        store = LocalStore(context: container.mainContext)
    }

    func testFirstLaunchLoadsTheSampleOnce() {
        store.prepareOnLaunch(today: today)
        XCTAssertNotNil(store.profile)
        XCTAssertEqual(store.all(Entry.self).count, 22)
        XCTAssertEqual(store.all(Bill.self).count, 6)
        XCTAssertEqual(store.all(Asset.self).count, 5)
        XCTAssertEqual(store.all(DayNote.self).count, 2)
        XCTAssertTrue(store.hasSample)
        // Opening the app again doesn't add it twice.
        store.prepareOnLaunch(today: today)
        XCTAssertEqual(store.all(Entry.self).count, 22)
    }

    func testRemovingTheSampleKeepsTheUsersOwnData() {
        store.prepareOnLaunch(today: today)
        let drafts = NoteParser.parse("cơm tấm 35k, cafe 40k", day: today)
        store.addEntries(drafts.map {
            Entry(date: $0.date, title: $0.title, amount: $0.amount ?? 0, flow: $0.flow, category: $0.category,
                  noteId: "mine", source: "cơm tấm 35k, cafe 40k")
        })
        // The user writes in a day the sample had a note for: that note is now theirs.
        store.saveDayNote(date: today, lines: ["my own line"])

        store.clearSample()

        XCTAssertFalse(store.hasSample)
        XCTAssertEqual(store.all(Entry.self).map(\.title).sorted(), ["Cafe", "Cơm tấm"])
        XCTAssertEqual(store.all(DayNote.self).map(\.lines), [["my own line"]])
        XCTAssertTrue(store.all(Bill.self).isEmpty)
        XCTAssertTrue(store.all(WorthPoint.self).isEmpty)

        // Loading it again never doubles anything.
        store.loadSample(today: today)
        store.loadSample(today: today)
        XCTAssertEqual(store.all(Entry.self).count, 24)
        XCTAssertEqual(store.all(DayNote.self).count, 2)
    }

    func testCheckingOffABillRecordsSpendingAndUncheckingRemovesIt() {
        let bill = Bill(kind: .recurring, name: "Internet", icon: .phone, amount: 220_000, start: "2026-01-20")
        container.mainContext.insert(bill)

        store.setBillPaid(bill, month: "2026-10", paid: true, date: "2026-10-22")
        let recorded = store.all(Entry.self)
        XCTAssertEqual(recorded.count, 1)
        XCTAssertEqual(recorded.first?.category, .bills)
        XCTAssertEqual(recorded.first?.date, "2026-10-22")
        XCTAssertEqual(recorded.first?.amount, 220_000)
        XCTAssertEqual(bill.paid["2026-10"]?.entryId, recorded.first?.id)

        // Ticking twice doesn't record twice.
        store.setBillPaid(bill, month: "2026-10", paid: true, date: "2026-10-23")
        XCTAssertEqual(store.all(Entry.self).count, 1)

        store.setBillPaid(bill, month: "2026-10", paid: false, date: "2026-10-23")
        XCTAssertTrue(store.all(Entry.self).isEmpty)
        XCTAssertNil(bill.paid["2026-10"])
    }

    func testDeleteEverythingStartsClean() {
        store.prepareOnLaunch(today: today)
        store.clearAll(today: today)
        XCTAssertTrue(store.all(Entry.self).isEmpty)
        XCTAssertTrue(store.all(Bill.self).isEmpty)
        XCTAssertEqual(store.all(Profile.self).count, 1)
    }

    func testBundledFontsAreRegistered() {
        let families = Set(UIFont.familyNames)
        XCTAssertTrue(families.contains("Montserrat"), "Montserrat missing")
        XCTAssertTrue(families.contains("Merriweather"), "Merriweather missing")
        XCTAssertTrue(families.contains("Bricolage Grotesque"), "Bricolage Grotesque missing")
    }
}
