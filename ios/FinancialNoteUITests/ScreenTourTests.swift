import XCTest

/// Walks through the screens from the Figma update and saves a screenshot of each for review.
@MainActor
final class ScreenTourTests: XCTestCase {
    private func snap(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    func testTour() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        XCTAssertTrue(app.buttons["Go to today"].waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "01-today")

        // + → Template: a blank line filled from one typed sentence.
        app.buttons["Add"].tap()
        XCTAssertTrue(app.buttons["Template"].waitForExistence(timeout: 3))
        snap(app, "02-plus")
        app.buttons["Template"].tap()
        let fillField = app.textFields["Fill from a line"].exists ? app.textFields["Fill from a line"] : app.textViews["Fill from a line"]
        XCTAssertTrue(fillField.waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "03-template-empty")
        fillField.typeText("trà sữa 35k · cash\n")
        sleep(1)
        snap(app, "04-template-filled")
        app.buttons["Add tags"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Select tag"].waitForExistence(timeout: 5))
        app.buttons["Health"].tap()
        sleep(1)
        snap(app, "05-tags")
        app.buttons["Done"].tap()
        sleep(1)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Date,'")).firstMatch.tap()
        sleep(1)
        snap(app, "06-date")
        app.buttons["Close"].firstMatch.tap()
        sleep(1)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Trà sữa"].waitForExistence(timeout: 5), "saved from Template")

        // AI tab: write, read, confirm; Chat History drawer.
        app.buttons["AI"].tap()
        let input = app.textFields["Write what you spent"].exists ? app.textFields["Write what you spent"] : app.textViews["Write what you spent"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "07-ai")
        input.tap()
        input.typeText("cơm tấm 35k, grab 42k · cash, bánh mì\n")
        sleep(1)
        snap(app, "08-ai-read")
        app.buttons["Chat history"].tap()
        sleep(1)
        snap(app, "09-history")
        app.navigationBars.buttons["Close chat history"].firstMatch.tap()
        sleep(1)

        // Scan, from the composer's + menu.
        app.buttons["More"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Scan"].waitForExistence(timeout: 3))
        app.buttons["Scan"].tap()
        sleep(1)
        snap(app, "10-scan")
    }
}
