import XCTest

final class DishSourceUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testOptionalSourceEntrySwitchAndRemoval() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString]
        app.launch()

        func tapWhenVisible(_ element: XCUIElement) {
            for _ in 0..<6 {
                if element.exists && element.isHittable { element.tap(); return }
                app.swipeUp()
            }
            XCTFail("Could not reach \(element)")
        }
        func fill(_ field: XCUIElement, _ value: String) {
            tapWhenVisible(field)
            field.typeText(value)
        }
        func chooseSource(_ name: String) {
            tapWhenVisible(app.buttons["dish-source-type"])
            let option = app.buttons[name]
            XCTAssertTrue(option.waitForExistence(timeout: 5), "Missing source option \(name): \(app.debugDescription)")
            option.tap()
        }
        tapWhenVisible(app.buttons["my-cooking"])
        tapWhenVisible(app.buttons["new-dish"])
        fill(app.textFields["dish-name"], "Pasta")
        chooseSource("Cookbook")
        fill(app.textFields["source-cookbook-title"], "Zahav")
        fill(app.textFields["Author(s)"], "Michael Solomonov")
        fill(app.textFields["Recipe / dish name"], "Hummus")
        fill(app.textFields["Page (optional)"], "43")
        tapWhenVisible(app.buttons["Continue"])
        tapWhenVisible(app.buttons["Liked it"])
        tapWhenVisible(app.buttons["Save Cook"])
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", ", Pasta — Version 1, score ")).firstMatch
        tapWhenVisible(row)
        XCTAssertTrue(app.staticTexts["Cookbook · Zahav"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Michael Solomonov")).firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "43")).firstMatch.exists)

        tapWhenVisible(app.buttons["Edit Cook"])
        chooseSource("Restaurant")
        fill(app.textFields["source-restaurant-name"], "Carbone")
        fill(app.textFields["Original dish name"], "Spicy Rigatoni")
        tapWhenVisible(app.buttons["save-cook-metadata"])
        XCTAssertTrue(app.staticTexts["Restaurant · Carbone"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Cookbook · Zahav"].exists)

        tapWhenVisible(app.buttons["Edit Cook"])
        chooseSource("No source")
        tapWhenVisible(app.buttons["save-cook-metadata"])
        XCTAssertTrue(app.buttons["Edit Cook"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Restaurant · Carbone"].exists)
        app.terminate(); app.launch()
        tapWhenVisible(app.buttons["my-cooking"])
        tapWhenVisible(row)
        XCTAssertFalse(app.staticTexts["Restaurant · Carbone"].exists)
    }
}
