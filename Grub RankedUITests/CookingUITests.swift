import XCTest

final class CookingUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testCookingCreateVersionEditRerankDeleteAndRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString]
        app.launch()
        let cooking = app.buttons["my-cooking"]
        XCTAssertTrue(cooking.waitForExistence(timeout: 15)); cooking.tap()

        func tap(_ button: XCUIElement) {
            XCTAssertTrue(button.waitForExistence(timeout: 15))
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: button)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 15), .completed)
            button.tap()
        }
        func fill(_ field: XCUIElement, _ text: String) {
            XCTAssertTrue(field.waitForExistence(timeout: 15)); field.tap(); field.typeText(text)
        }
        func finishRank(_ name: String, comparisons: Bool) {
            tap(app.buttons["Continue"]); tap(app.buttons["Liked it"])
            if comparisons { tap(app.buttons["Prefer \(name)"]) }
            tap(app.buttons["Save Cook"])
            XCTAssertTrue(app.buttons["new-dish"].waitForExistence(timeout: 15))
        }
        func row(_ name: String) -> XCUIElement {
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", ", \(name), score ")).firstMatch
        }
        tap(app.buttons["new-dish"])
        fill(app.textFields["dish-name"], "Salmon")
        fill(app.textFields["version-title"], "First cook")
        finishRank("Salmon — First cook", comparisons: false)
        XCTAssertTrue(row("Salmon — First cook").waitForExistence(timeout: 15))

        tap(app.buttons["new-version"])
        tap(app.buttons["choose-dish-Salmon"])
        let inherited = app.textFields["dish-name"]
        XCTAssertTrue(inherited.waitForExistence(timeout: 15))
        XCTAssertEqual(inherited.value as? String, "Salmon")
        fill(app.textFields["version-title"], "Second cook")
        finishRank("Salmon — Second cook", comparisons: true)
        XCTAssertTrue(row("Salmon — First cook").exists)
        tap(row("Salmon — Second cook"))
        tap(app.buttons["Edit Cook"])
        let title = app.textFields["version-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 15)); title.tap()
        title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Second cook".count) + "Grilled\n")
        tap(app.buttons["save-cook-metadata"])
        XCTAssertTrue(app.staticTexts["Grilled"].waitForExistence(timeout: 15))

        tap(app.buttons["Re-rank"])
        tap(app.buttons["Too Tough"])
        tap(app.buttons["Undo last answer"])
        tap(app.buttons["Prefer Salmon — First cook"])
        tap(app.buttons["Save Answers"])
        XCTAssertTrue(app.buttons["Edit Cook"].waitForExistence(timeout: 15))

        app.terminate(); app.launch()
        tap(app.buttons["my-cooking"])
        tap(row("Salmon — Grilled"))
        tap(app.buttons["Delete Cook"])
        tap(app.sheets.buttons["Delete Cook"])
        XCTAssertTrue(row("Salmon — First cook").waitForExistence(timeout: 15))
        XCTAssertFalse(row("Salmon — Grilled").exists)
        app.terminate(); app.launch()
        tap(app.buttons["my-cooking"])
        XCTAssertTrue(row("Salmon — First cook").waitForExistence(timeout: 15))
        XCTAssertFalse(row("Salmon — Grilled").exists)
    }
}
