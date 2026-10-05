import XCTest

final class Grub_RankedUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testLaunchesDirectlyIntoSingleCookingRanking() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString]
        app.launch()

        XCTAssertTrue(app.navigationBars["Rankings"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["new-dish"].exists)
        XCTAssertTrue(app.buttons["new-version"].exists)
        XCTAssertFalse(app.buttons["my-cooking"].exists)
        XCTAssertFalse(app.buttons["New Ranking"].exists)
        XCTAssertFalse(app.staticTexts["My Rankings"].exists)
    }

    @MainActor
    func testComparisonSquaresStaySymmetricalForEveryPhotoCombination() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString,
                               "--comparison-fixture", "11", "--test-dark"]
        app.launch()

        let next = app.buttons["comparison-fixture-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 15))
        for (index, mode) in ["11", "10", "01", "00"].enumerated() {
            let updated = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label CONTAINS %@", mode), object: next)
            XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 5), .completed)

            let left = app.buttons["comparison-choice-new"]
            let right = app.buttons["comparison-choice-existing"]
            XCTAssertTrue(left.exists, "Missing left choice for fixture \(mode)")
            XCTAssertTrue(right.exists, "Missing right choice for fixture \(mode)")
            XCTAssertEqual(left.frame.width, right.frame.width, accuracy: 1)
            XCTAssertEqual(left.value as? String, right.value as? String)
            XCTAssertTrue((left.value as? String)?.contains("Square photo area") == true)
            XCTAssertGreaterThanOrEqual(left.frame.minX, 0)
            XCTAssertLessThanOrEqual(right.frame.maxX, app.windows.firstMatch.frame.maxX)
            XCTAssertTrue(app.staticTexts["OR"].exists)

            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Comparison \(mode) Dark"
            attachment.lifetime = .keepAlways
            add(attachment)
            if index < 3 { next.tap() }
        }
    }
}
