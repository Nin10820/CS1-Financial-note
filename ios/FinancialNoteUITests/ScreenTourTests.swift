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

        // Scan has its own test (ScanFlowTests).
    }
}

/// A payment QR read by Scan opens a filled-in line. The camera can't run in the Simulator, so
/// the test hands Scan a VietQR payload through a debug-only launch argument.
@MainActor
final class ScanFlowTests: XCTestCase {
    private func tlv(_ id: String, _ value: String) -> String { id + String(format: "%02d", value.count) + value }

    func testScannedPaymentQRBecomesALine() {
        let bene = tlv("00", "970423") + tlv("01", "0123456789")
        let payload = tlv("00", "01") + tlv("01", "12") + tlv("38", tlv("00", "A000000727") + tlv("01", bene))
            + tlv("53", "704") + tlv("54", "65000") + tlv("58", "VN") + tlv("62", tlv("08", "Bun bo Hue")) + "6304ABCD"
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-scanPayload", payload]
        app.launch()
        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        app.buttons["Add"].tap()
        app.buttons["Scan"].tap()
        // Scan closes and the line opens, filled in from the code.
        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 6))
        XCTAssertEqual(name.value as? String, "Bun bo Hue")
        XCTAssertEqual(app.textFields["Amount in dong"].value as? String, "65,000")
        XCTAssertTrue(app.buttons["From, Transfer"].exists)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Bun bo Hue"].waitForExistence(timeout: 5), "saved line shows on Today")
    }
}

/// The AI page and Talk With AI, with screenshots for review.
@MainActor
final class AITourTests: XCTestCase {
    private func snap(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    func testAIPageAndVoice() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

        app.buttons["AI"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Shortcuts"].waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "a1-home")

        app.buttons["Which bills are left?"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'bill'")).firstMatch.waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "a2-answer")

        // Talk With AI from the + menu.
        app.buttons["Close"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        app.buttons["Add"].tap()
        app.buttons["Talk With AI"].tap()
        // Allow microphone / speech if iOS asks.
        for _ in 0..<3 {
            let allow = springboard.buttons["Allow"].exists ? springboard.buttons["Allow"] : springboard.buttons["OK"]
            if allow.waitForExistence(timeout: 3) { allow.tap() } else { break }
        }
        sleep(2)
        snap(app, "a3-voice")
        XCTAssertTrue(app.buttons["Cancel"].exists)
    }
}
