import XCTest

final class CuisineUITests: StayGrubbyUITestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func reach(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<7 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTFail("Cuisine control could not be reached: \(element)")
    }
    @MainActor private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        reach(element, in: app); element.tap()
    }
    @MainActor private func select(_ text: String, id: String, in app: XCUIApplication) {
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText(text)
        let option = app.buttons[id]
        XCTAssertTrue(option.waitForExistence(timeout: 5)); option.tap()
    }
    @MainActor private func saveEdit(in app: XCUIApplication) {
        let save = app.buttons["save-cook-metadata"]
        for _ in 0..<2 {
            tap(save, in: app)
            if app.buttons["Edit Cook"].waitForExistence(timeout: 5) { return }
        }
        XCTFail("Edit did not save")
    }
    @MainActor func testNewEditCustomRemovalPersistenceAndRankingFilter() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--test-dark"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.revealCreation(); app.buttons["new-dish"].tap()
        let name = app.textFields["dish-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Cuisine Soup")
        tap(app.buttons["dish-cuisine"], in: app)
        select(" italian ", id: "cuisine-option-italian", in: app)
        XCTAssertTrue(app.buttons["dish-cuisine"].label.contains("Italian"))
        tap(app.buttons["Continue"], in: app); tap(app.buttons["Liked it"], in: app)
        XCTAssertTrue(app.buttons["ranking-result-close"].waitForExistence(timeout: 15))
        app.buttons["ranking-result-close"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Cuisine Soup'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        let globalLabel = row.label
        app.buttons["ranking-filter-cuisine"].tap()
        select("Italian", id: "cuisine-option-italian", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5)); XCTAssertEqual(row.label, globalLabel)
        app.buttons["clear-filters"].tap()
        tap(row, in: app); tap(app.buttons["Edit Cook"], in: app)
        tap(app.buttons["dish-cuisine"], in: app)
        select("Basque Home Cooking", id: "cuisine-add", in: app)
        XCTAssertTrue(app.buttons["dish-cuisine"].label.contains("Basque Home Cooking"))
        saveEdit(in: app)
        app.terminate(); app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.buttons["ranking-filter-cuisine"].tap()
        select("Basque", id: "cuisine-option-custom:basque home cooking", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5)); XCTAssertEqual(row.label, globalLabel)
        app.buttons["clear-filters"].tap()
        app.buttons["ranking-filter-cuisine"].tap()
        select("Italian", id: "cuisine-option-italian", in: app)
        XCTAssertTrue(app.staticTexts["No filter matches"].waitForExistence(timeout: 5))
        XCTAssertFalse(row.exists)
        app.buttons["clear-filters"].tap()
        tap(row, in: app); tap(app.buttons["Edit Cook"], in: app)
        tap(app.buttons["dish-cuisine"], in: app)
        let search = app.searchFields.firstMatch
        search.tap(); search.typeText(" BASQUE   HOME-COOKING ")
        XCTAssertTrue(app.buttons["cuisine-option-custom:basque home cooking"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["cuisine-add"].exists)
        app.buttons["cuisine-clear"].tap()
        saveEdit(in: app)
        tap(app.buttons["Edit Cook"], in: app)
        XCTAssertTrue(app.buttons["dish-cuisine"].label.contains("Optional"))
        app.buttons["Cancel"].tap()
    }

    @MainActor func testLightLargeTypePickerSelectionAndCancelAreOptional() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--test-light", "--test-large-type"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.revealCreation(); app.buttons["new-dish"].tap()
        tap(app.buttons["dish-cuisine"], in: app)
        XCTAssertTrue(app.buttons["cuisine-option-american"].waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Cuisine light accessibility size"; shot.lifetime = .keepAlways; add(shot)
        select("Mediterranian", id: "cuisine-option-mediterranean", in: app)
        XCTAssertTrue(app.buttons["dish-cuisine"].label.contains("Mediterranean"))
        tap(app.buttons["dish-cuisine"], in: app)
        app.buttons["cuisine-clear"].tap()
        XCTAssertTrue(app.buttons["dish-cuisine"].label.contains("Optional"))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Your cooking, ranked"].waitForExistence(timeout: 5))
    }
}
