import SwiftUI
import UIKit
import XCTest
@testable import FinancialNote

@MainActor
final class TodayLogicTests: XCTestCase {
    func testMondayOfTheWeek() {
        XCTAssertEqual(Day.monday(of: "2026-10-28"), "2026-10-26") // Wednesday
        XCTAssertEqual(Day.monday(of: "2026-10-26"), "2026-10-26") // Monday itself
        XCTAssertEqual(Day.monday(of: "2026-11-01"), "2026-10-26") // Sunday belongs to the week before
    }

    func testRangeBounds() {
        XCTAssertEqual(DayRange.day.bounds(for: "2026-10-28").from, "2026-10-28")
        XCTAssertEqual(DayRange.week.bounds(for: "2026-10-28").to, "2026-11-01")
        XCTAssertEqual(DayRange.month.bounds(for: "2026-10-28").from, "2026-10-01")
    }

    func testPassingMidnightMovesTodayAlongOnlyWhenItWasShowingToday() {
        let app = AppState()
        app.today = "2026-10-28"
        app.day = "2026-10-28"
        app.dayChanged()
        XCTAssertEqual(app.day, Day.today())

        // Looking at an older day: stay there.
        app.today = "2026-10-28"
        app.day = "2026-10-20"
        app.dayChanged()
        XCTAssertEqual(app.day, "2026-10-20")
    }

    func testOpeningQuickNoteUsesThePickedDay() {
        let app = AppState()
        app.day = "2026-10-20"
        app.openQuickNote()
        XCTAssertEqual(app.quick?.date, "2026-10-20")
        XCTAssertNil(app.quick?.drafts)
    }
}

/// Crash fixed in milestone 2: SwiftUI resolves light/dark colours on its render thread.
final class ColorThreadTests: XCTestCase {
    func testLightDarkColourResolvesOffTheMainThread() async {
        let ok = await Task.detached {
            let c = UIColor(Color(light: 0xFFFFFF, dark: 0x000000))
            let dark = c.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
            var w: CGFloat = 1
            dark.getWhite(&w, alpha: nil)
            return w < 0.01
        }.value
        XCTAssertTrue(ok)
    }
}

final class DayHeadingTests: XCTestCase {
    func testDayHeadings() {
        XCTAssertEqual(Day.dayHeading("2026-10-29", today: "2026-10-29"), "Today")
        XCTAssertEqual(Day.dayHeading("2026-10-28", today: "2026-10-29"), "Yesterday")
        XCTAssertEqual(Day.dayHeading("2026-10-26", today: "2026-10-29"), "Mon 26 Oct")
    }
}
