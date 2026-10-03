import XCTest

final class Grub_RankedUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testCreateCompareUndoAndRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString]
        app.launch()
        let name = "Test \(UUID().uuidString.prefix(8))"
        app.buttons["New Ranking"].tap()
        // SwiftUI's native alert does not forward TextField accessibilityIdentifier
        // on this OS. Scope to the actual alert and use its native field.
        let field = app.alerts["New Ranking"].textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap(); field.typeText(name)
        app.buttons["Create"].tap()
        app.staticTexts[name].tap()
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 15))

        func add(_ name: String) {
            let addButton = app.buttons["add-item"]
            XCTAssertTrue(addButton.waitForExistence(timeout: 15))
            let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: addButton)
            XCTAssertEqual(XCTWaiter.wait(for: [hittable], timeout: 15), .completed)
            addButton.tap()
            let itemField = app.textFields["item-name"]
            XCTAssertTrue(itemField.waitForExistence(timeout: 15))
            itemField.tap(); itemField.typeText(name)
            app.buttons["Continue"].tap()
            app.buttons["Liked it"].tap()
        }
        add("Alpha")
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 15))
        add("Beta")
        XCTAssertTrue(app.buttons["Prefer Beta"].waitForExistence(timeout: 15))
        app.buttons["Prefer Beta"].tap()
        XCTAssertTrue(app.buttons["Undo last answer"].waitForExistence(timeout: 15))
        app.buttons["Undo last answer"].tap()
        XCTAssertTrue(app.buttons["Prefer Alpha"].waitForExistence(timeout: 15))
        app.buttons["Prefer Alpha"].tap()
        XCTAssertTrue(app.buttons["add-item"].waitForExistence(timeout: 15))
        let firstRank = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Rank 1, Alpha, score")).firstMatch
        XCTAssertTrue(firstRank.exists)
        app.terminate(); app.launch()
        app.staticTexts[name].tap()
        XCTAssertTrue(firstRank.waitForExistence(timeout: 15))
    }
}
