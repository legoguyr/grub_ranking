import XCTest

final class Phase2CReviewUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func reach(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTFail("Could not reach \(element)")
    }
    @MainActor private func tap(_ element: XCUIElement, app: XCUIApplication) { reach(element, app: app); element.tap() }
    @MainActor private func capture(_ title: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = title; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor private func row(_ name: String, app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS %@", name)).firstMatch
    }

    @MainActor func testDetailVersionSelectionLongNamesAndLargeTypeForms() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); let token = UUID().uuidString
        app.launchArguments = ["--ui-test-store", token, "--discovery-fixture", "--test-dark"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        tap(row("Smoky Sunday", app: app), app: app)
        XCTAssertTrue(app.navigationBars["Dish Details"].waitForExistence(timeout: 10))
        capture("Detail with photo Dark", app: app)
        XCTAssertFalse(app.buttons["Delete Cook"].exists)
        let sibling = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'version-row-' AND label CONTAINS 'Golden sear'")).firstMatch
        tap(sibling, app: app)
        XCTAssertTrue(app.staticTexts["Golden sear"].waitForExistence(timeout: 10))
        // Bring the compact hero/header into view after opening a different version.
        capture("Detail without photo Dark", app: app)
        tap(app.buttons["Edit Cook"], app: app)
        XCTAssertTrue(app.textFields["dish-name"].waitForExistence(timeout: 10))
        let name = "Slow roasted harissa chicken with preserved lemon and garden vegetables"
        let version = "Sunday supper with a smoky finish and extra crispy edges"
        let nameField = app.textFields["dish-name"]
        tap(nameField, app: app)
        nameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Harissa Chicken".count) + name + "\n")
        let versionField = app.textFields["version-title"]
        tap(versionField, app: app)
        versionField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Golden sear".count) + version + "\n")
        capture("Edit cook", app: app)
        tap(app.buttons["save-cook-metadata"], app: app)
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 10))
        app.terminate()
        app.launchArguments += ["--test-light", "--test-large-type", "--test-reduce-motion"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        capture("Long names Light Accessibility", app: app)
        tap(row(version, app: app), app: app)
        XCTAssertTrue(app.navigationBars["Dish Details"].waitForExistence(timeout: 10))
        capture("Detail Light Accessibility", app: app)
        tap(app.buttons["detail-new-version"], app: app)
        XCTAssertTrue(app.staticTexts["inherited-dish-name"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["inherited-dish-name"].label, name)
        capture("New Version Light Accessibility", app: app)
        tap(app.buttons["Cancel"], app: app)
        XCTAssertTrue(app.navigationBars["Dish Details"].waitForExistence(timeout: 10))
    }

    @MainActor func testComparisonSkipUndoTooToughAndResponsiveReview() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--discovery-fixture", "--test-dark", "--test-reduce-motion"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        tap(row("Smoky Sunday", app: app), app: app)
        tap(app.buttons["Re-rank"], app: app)
        let choice = app.buttons["comparison-choice-existing"]
        XCTAssertTrue(choice.waitForExistence(timeout: 15))
        let opponent = choice.label
        XCTAssertTrue(app.scrollViews["comparison-content"].exists)
        XCTAssertFalse(app.scrollViews["comparison-content"].staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Score '")).firstMatch.exists)
        tap(app.buttons["Skip"], app: app)
        XCTAssertTrue(app.buttons["Undo"].isEnabled)
        XCTAssertTrue(app.staticTexts["0 new answers. Saved history is kept."].exists)
        tap(app.buttons["Undo"], app: app)
        XCTAssertEqual(choice.label, opponent)
        tap(app.buttons["Too Tough"], app: app)
        XCTAssertTrue(app.staticTexts["1 new answers. Saved history is kept."].waitForExistence(timeout: 10))
        if app.buttons["Undo"].exists { tap(app.buttons["Undo"], app: app) }
        else { tap(app.buttons["Undo last answer"], app: app) }
        XCTAssertTrue(app.staticTexts["0 new answers. Saved history is kept."].exists)
        XCTAssertEqual(choice.label, opponent)
        tap(app.buttons["Cancel"], app: app)

        app.terminate()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--comparison-fixture", "10", "--test-light", "--test-large-type", "--test-reduce-motion"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.buttons["comparison-choice-new"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.buttons["comparison-choice-new"].frame.width, app.buttons["comparison-choice-existing"].frame.width, accuracy: 1)
        capture("Comparison Light Accessibility Reduce Motion", app: app)
        app.swipeUp()
        XCTAssertTrue(app.buttons["Skip"].isHittable)
        app.terminate()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--comparison-fixture", "11", "--test-dark"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.buttons["comparison-choice-new"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.buttons["comparison-choice-new"].frame.width, app.buttons["comparison-choice-existing"].frame.width, accuracy: 1)
        // iPhone supports upright portrait only; review this layout in that pose.
        XCTAssertEqual(XCUIDevice.shared.orientation, .portrait)
        XCTAssertGreaterThan(app.windows.firstMatch.frame.height, app.windows.firstMatch.frame.width)
        reach(app.buttons["Too Tough"], app: app)
        XCTAssertTrue(app.buttons["Too Tough"].isHittable)
        capture("Comparison Dark Upright Portrait", app: app)
        XCUIDevice.shared.orientation = .portrait
    }
}
