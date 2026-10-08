import XCTest

final class PolishUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor private func tap(_ element: XCUIElement, app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 10))
        for _ in 0..<12 {
            // XCTest can report a scrolled-off form row as hittable even when
            // its point is covered by the pinned Save/Continue action. Reveal
            // the actual row before tapping; never accidentally save the editor.
            let footer = app.buttons["save-cook-metadata"].exists ? app.buttons["save-cook-metadata"] : app.buttons["Continue"]
            let isFooter = element.identifier == "save-cook-metadata" || element.label == "Continue"
            let coveredByFooter = footer.exists && !isFooter && element.frame.maxY > footer.frame.minY
            if element.isHittable && !coveredByFooter { element.tap(); return }
            app.swipeUp()
        }
        XCTFail("Could not reach \(element)")
    }
    @MainActor private func transition(_ element: XCUIElement, to next: XCUIElement, app: XCUIApplication) {
        tap(element, app: app)
        if next.waitForExistence(timeout: 5) { return }
        if element.exists && element.isHittable { element.tap() }
        XCTAssertTrue(next.waitForExistence(timeout: 10))
    }
    @MainActor private func row(_ text: String, app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS %@", text)).firstMatch
    }
    @MainActor private func capture(_ title: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = title
        attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor func testAutomaticResultPersistsBeforeCloseAndCanceledDraftCreatesNothing() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); app.launchArguments = ["--ui-test-store", UUID().uuidString, "--test-reduce-motion"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.revealCreation(); tap(app.buttons["new-dish"], app: app)
        tap(app.textFields["dish-name"], app: app); app.textFields["dish-name"].typeText("Canceled Soup\n")
        tap(app.buttons["Continue"], app: app); tap(app.buttons["Cancel"], app: app)
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 10))
        XCTAssertFalse(row("Canceled Soup", app: app).exists)
        app.revealCreation(); tap(app.buttons["new-dish"], app: app)
        tap(app.textFields["dish-name"], app: app); app.textFields["dish-name"].typeText("Roasted Carrots\n")
        tap(app.buttons["Continue"], app: app); tap(app.buttons["Liked it"], app: app)
        XCTAssertTrue(app.buttons["ranking-result-close"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["Save Cook"].exists)
        XCTAssertEqual(app.staticTexts["result-rank"].label, "#1 overall")
        let score = app.staticTexts["result-score"].label
        XCTAssertTrue(score.hasPrefix("Score "))
        capture("Automatically saved ranking result", app: app)
        // Relaunch without closing proves the result is feedback for an already saved transaction.
        app.terminate(); app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        let saved = row("Roasted Carrots", app: app)
        XCTAssertTrue(saved.waitForExistence(timeout: 10))
        XCTAssertTrue(saved.label.hasPrefix("Rank 1,"))
        XCTAssertTrue(saved.label.hasSuffix(score.lowercased()))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Roasted Carrots'")).count, 1)
        XCTAssertFalse(row("Canceled Soup", app: app).exists)
    }
    @MainActor func testContainsEditPersistenceAndAvoidAnySelectionWithIndependentClear() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); app.launchArguments = ["--ui-test-store", UUID().uuidString, "--discovery-fixture"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        tap(row("Golden sear", app: app), app: app); transition(app.buttons["Edit Cook"], to: app.textFields["dish-name"], app: app)
        transition(app.buttons["cook-contains"], to: app.buttons["contains-done"], app: app)
        tap(app.buttons["contains-milk"], app: app); tap(app.buttons["contains-wheat"], app: app)
        tap(app.buttons["contains-done"], app: app); tap(app.buttons["save-cook-metadata"], app: app)
        XCTAssertTrue(app.staticTexts["detail-contains"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["detail-contains"].label.contains("Milk"))
        app.terminate(); app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        tap(row("Golden sear", app: app), app: app); transition(app.buttons["Edit Cook"], to: app.textFields["dish-name"], app: app)
        transition(app.buttons["cook-contains"], to: app.buttons["contains-done"], app: app)
        XCTAssertEqual(app.buttons["contains-milk"].value as? String, "Selected")
        XCTAssertEqual(app.buttons["contains-wheat"].value as? String, "Selected")
        tap(app.buttons["contains-done"], app: app); tap(app.buttons["Cancel"], app: app)
        tap(app.navigationBars.buttons.firstMatch, app: app)
        tap(app.buttons["ranking-filter-avoid"], app: app)
        XCTAssertTrue(app.staticTexts["allergen-safety"].exists)
        tap(app.buttons["filter-avoid-milk"], app: app); tap(app.buttons["filter-avoid-sesame"], app: app)
        tap(app.buttons["filters-done"], app: app)
        XCTAssertFalse(row("Golden sear", app: app).exists)
        XCTAssertFalse(row("Smoky Sunday", app: app).exists)
        XCTAssertFalse(row("Sea Bass", app: app).exists)
        XCTAssertTrue(row("Lemon Pasta", app: app).label.hasPrefix("Rank 4,"))
        XCTAssertTrue(row("Apple Cake", app: app).label.hasPrefix("Rank 5,"))
        tap(app.buttons["ranking-filter-course"], app: app); tap(app.buttons["filter-course-main"], app: app)
        tap(app.buttons["filters-done"], app: app)
        XCTAssertTrue(app.staticTexts["No filter matches"].exists)
        tap(app.buttons["ranking-filter-avoid"], app: app); tap(app.buttons["clear-avoid"], app: app)
        tap(app.buttons["filters-done"], app: app)
        XCTAssertTrue(app.buttons["ranking-filter-course"].label.contains("1 active"))
        XCTAssertTrue(row("Golden sear", app: app).label.hasPrefix("Rank 2,"))
        XCTAssertFalse(row("Apple Cake", app: app).exists)
    }
    @MainActor func testParentDishSearchEmptyClearAndHeroAppearances() throws {
        XCUIDevice.shared.orientation = .portrait
        for options in [["--test-light"], ["--test-dark"], ["--test-light", "--test-large-type"], ["--test-dark", "--test-large-type", "--test-reduce-motion"]] {
            let app = XCUIApplication(); app.launchArguments = ["--ui-test-store", UUID().uuidString, "--discovery-fixture"] + options
            app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
            tap(row("Smoky Sunday", app: app), app: app)
            XCTAssertTrue(app.descendants(matching: .any)["hero-photo"].waitForExistence(timeout: 10))
            capture("Hero photo \(options)", app: app)
            tap(app.navigationBars.buttons.firstMatch, app: app)
            tap(row("Golden sear", app: app), app: app)
            XCTAssertTrue(app.descendants(matching: .any)["hero-placeholder"].waitForExistence(timeout: 10))
            capture("Hero placeholder \(options)", app: app)
            tap(app.navigationBars.buttons.firstMatch, app: app)
            app.revealCreation(); tap(app.buttons["new-version"], app: app)
            let search = app.textFields["parent-dish-search"]
            XCTAssertTrue(search.waitForExistence(timeout: 10)); tap(search, app: app); search.typeText("nonexistent")
            XCTAssertFalse(app.buttons["choose-dish-Harissa Chicken"].exists)
            XCTAssertTrue(app.staticTexts["parent-dish-empty"].waitForExistence(timeout: 10))
            tap(app.buttons["parent-dish-search-clear"], app: app)
            tap(search, app: app); search.typeText("harissa")
            XCTAssertTrue(app.buttons["choose-dish-Harissa Chicken"].exists)
            XCTAssertFalse(app.buttons["choose-dish-Apple Cake"].exists)
            capture("Parent dish search \(options)", app: app)
            transition(app.buttons["choose-dish-Harissa Chicken"], to: app.staticTexts["inherited-dish-name"], app: app)
            XCTAssertTrue(app.staticTexts["inherited-dish-name"].waitForExistence(timeout: 10))
            XCTAssertEqual(app.staticTexts["inherited-dish-name"].label, "Harissa Chicken")
            tap(app.buttons["Cancel"], app: app)
            if options == ["--test-light"] {
                // Create from a nested version detail, then close all the way to Rankings.
                tap(row("Golden sear", app: app), app: app)
                let sibling = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'version-row-' AND label CONTAINS 'Smoky Sunday'")).firstMatch
                tap(sibling, app: app); tap(app.buttons["detail-new-version"], app: app)
                tap(app.buttons["Continue"], app: app); tap(app.buttons["Liked it"], app: app)
                for _ in 0..<12 {
                    if app.buttons["ranking-result-close"].waitForExistence(timeout: 1) { break }
                    tap(app.buttons["comparison-choice-new"], app: app)
                }
                XCTAssertTrue(app.buttons["ranking-result-close"].waitForExistence(timeout: 10))
                XCTAssertFalse(app.buttons["Save Cook"].exists)
                tap(app.buttons["ranking-result-close"], app: app)
                XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 10))
                XCTAssertTrue(row("Harissa Chicken — Version 3", app: app).exists)
            }
            app.terminate()
        }
    }
}
