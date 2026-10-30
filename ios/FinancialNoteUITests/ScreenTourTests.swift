import XCTest

/// Walks through the Today screens and attaches a screenshot of each, for design review.
@MainActor
final class ScreenTourTests: XCTestCase {
    private func snap(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    func testTourOfTodayScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        XCTAssertTrue(app.buttons["Show Daily"].waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "01-today")

        // Entry sheet, tags, delete.
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Lunch, broken rice'")).firstMatch.tap()
        XCTAssertTrue(app.buttons["Add tags"].waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "02-entry")
        if app.buttons["Suggest tag"].exists { app.buttons["Suggest tag"].tap() }
        app.buttons["Add tags"].tap()
        XCTAssertTrue(app.navigationBars["Select tag"].waitForExistence(timeout: 5))
        app.buttons["Drinks"].tap()
        sleep(1)
        snap(app, "03-tags")
        app.buttons["Done"].tap()
        sleep(1)
        snap(app, "04-entry-tagged")
        app.buttons["Delete"].tap()
        sleep(1)
        snap(app, "05-delete")
        app.buttons["Close"].firstMatch.tap()
        if app.buttons["Close"].waitForExistence(timeout: 1) { app.buttons["Close"].firstMatch.tap() }
        sleep(1)

        // Day picker.
        app.buttons["October 2026. Pick a day"].tap()
        sleep(1)
        snap(app, "06-day")
        app.buttons["Done"].tap()
        sleep(1)

        // Assistant: write, read, confirm, history.
        app.buttons["Write"].tap()
        let input = app.textFields["Write what you spent"].exists ? app.textFields["Write what you spent"] : app.textViews["Write what you spent"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "07-assistant")
        input.tap()
        input.typeText("trà sữa 35k, grab 42k · cash, bánh mì\n")
        sleep(1)
        snap(app, "08-assistant-read")
        app.buttons["Chat history"].tap()
        sleep(1)
        snap(app, "09-history")
    }
}
