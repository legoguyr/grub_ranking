import XCTest

final class DishSourceUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testOptionalSourceEntrySwitchAndRemoval() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))

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
            if name == "No source" || name == "My Own" { return }
        }
        app.revealCreation()
        tapWhenVisible(app.buttons["new-dish"])
        fill(app.textFields["dish-name"], "Pasta")
        chooseSource("Cookbook")
        fill(app.textFields["source-cookbook-title"], "Zahav")
        XCTAssertFalse(app.textFields["Author(s)"].exists)
        XCTAssertFalse(app.textFields["Recipe / dish name"].exists)
        XCTAssertFalse(app.textFields["Page (optional)"].exists)
        tapWhenVisible(app.buttons["source-done"])
        tapWhenVisible(app.buttons["Continue"])
        tapWhenVisible(app.buttons["Liked it"])
        XCTAssertTrue(app.buttons["ranking-result-close"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["Save Cook"].exists)
        tapWhenVisible(app.buttons["ranking-result-close"])
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", ", Pasta — Version 1, score ")).firstMatch
        tapWhenVisible(row)
        XCTAssertTrue(app.staticTexts["Cookbook · Zahav"].waitForExistence(timeout: 15))


        tapWhenVisible(app.buttons["Edit Cook"])
        chooseSource("Restaurant")
        fill(app.textFields["source-restaurant-name"], "Carbone")
        XCTAssertFalse(app.textFields["Original dish name"].exists)
        tapWhenVisible(app.buttons["source-done"])
        tapWhenVisible(app.buttons["save-cook-metadata"])
        XCTAssertTrue(app.staticTexts["Restaurant · Carbone"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Cookbook · Zahav"].exists)

        tapWhenVisible(app.buttons["Edit Cook"])
        chooseSource("No source")
        tapWhenVisible(app.buttons["save-cook-metadata"])
        XCTAssertTrue(app.buttons["Edit Cook"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Restaurant · Carbone"].exists)
        app.terminate(); app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        tapWhenVisible(row)
        XCTAssertFalse(app.staticTexts["Restaurant · Carbone"].exists)
        tapWhenVisible(app.buttons["Edit Cook"])
        chooseSource("My Own")
        XCTAssertFalse(app.textFields["source-online-url"].exists)
        tapWhenVisible(app.buttons["save-cook-metadata"])
        XCTAssertTrue(app.staticTexts["My Own"].waitForExistence(timeout: 15))
        tapWhenVisible(app.buttons["Edit Cook"])
        chooseSource("Online")
        XCTAssertTrue(app.buttons["source-choice-myOwn"].exists)
        XCTAssertTrue(app.buttons["source-choice-cookbook"].exists)
        XCTAssertTrue(app.buttons["source-choice-restaurant"].exists)
        XCTAssertTrue(app.buttons["source-choice-friendFamily"].exists)
        XCTAssertTrue(app.buttons["source-choice-other"].exists)
        XCTAssertFalse(app.buttons["Online Recipe"].exists)
        XCTAssertFalse(app.buttons["Social Media"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Simplified Source choices"; attachment.lifetime = .keepAlways; add(attachment)
        let url = "https://example.com/pasta?x=1#steps"
        fill(app.textFields["source-online-url"], url)
        tapWhenVisible(app.buttons["source-done"])
        tapWhenVisible(app.buttons["save-cook-metadata"])
        let savedURL = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", url)).firstMatch
        for _ in 0..<5 { if savedURL.exists { break }; app.swipeUp() }
        XCTAssertTrue(savedURL.exists)
        app.terminate(); app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        tapWhenVisible(row)
        for _ in 0..<5 { if savedURL.exists { break }; app.swipeUp() }
        XCTAssertTrue(savedURL.exists)
    }
}
