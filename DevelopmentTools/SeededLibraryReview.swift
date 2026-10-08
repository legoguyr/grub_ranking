import XCTest

/// Manual review utility, outside all targets. Substitute a backed-up isolated
/// store clone token when temporarily copying this file into the UI-test target.
final class SeededLibraryReview: XCTestCase {
    private let cloneToken = "__CLONE_TOKEN__"
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func reach(_ element: XCUIElement, _ app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 15))
        for _ in 0..<14 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTFail("Unable to reach \(element)")
    }
    @MainActor private func tap(_ element: XCUIElement, _ app: XCUIApplication) { reach(element, app); element.tap() }
    @MainActor private func transition(_ element: XCUIElement, _ next: XCUIElement, _ app: XCUIApplication) {
        tap(element, app)
        if !next.waitForExistence(timeout: 5), element.exists && element.isHittable { element.tap() }
        XCTAssertTrue(next.waitForExistence(timeout: 15))
    }
    @MainActor private func capture(_ title: String, _ app: XCUIApplication) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = title; image.lifetime = .keepAlways; add(image)
    }
    @MainActor private func row(_ name: String, _ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS %@", name)).firstMatch
    }
    @MainActor private func search(_ text: String, _ app: XCUIApplication) {
        app.revealSearch(); tap(app.rankingSearchField, app)
        let focus = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: app.rankingSearchField)
        XCTAssertEqual(XCTWaiter.wait(for: [focus], timeout: 5), .completed)
        app.rankingSearchField.typeText(text + "\n")
    }
    @MainActor private func count(_ number: Int, _ app: XCUIApplication) {
        let expected = "\(number) of 15 ranked cooks · Global ranks"
        XCTAssertTrue(app.staticTexts[expected].waitForExistence(timeout: 10))
    }
    @MainActor func testSavedDevelopmentDiscoveryVersionsAndCanceledRerank() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); app.launchArguments = [] // Actual seeded development store.
        app.launch(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        capture("Seeded Rankings", app)
        search("harissa", app); count(2, app)
        XCTAssertTrue(row("Smoky Sunday", app).exists); XCTAssertTrue(row("Oven-Roasted Batch", app).exists)
        capture("Seeded Search", app)
        tap(app.buttons["header-clear-search"], app); tap(app.buttons["search-done"], app)
        for (group, option, expected) in [("course", "filter-course-soup", 1), ("dietary", "filter-dietary-vegan", 2), ("avoid", "filter-avoid-milk", 11)] {
            transition(app.buttons["ranking-filter-\(group)"], app.buttons["filters-done"], app)
            tap(app.buttons[option], app)
            XCTAssertEqual(app.buttons[option].value as? String, "Selected")
            tap(app.buttons["filters-done"], app); count(expected, app)
            capture("Seeded \(group) filter", app)
            tap(app.buttons["clear-filters"], app)
            XCTAssertFalse(app.buttons["clear-filters"].exists)
        }
        search("harissa", app)
        transition(row("Smoky Sunday", app), app.navigationBars["Dish Details"], app)
        capture("Seeded Detail", app)
        let sibling = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'version-row-' AND label CONTAINS 'Oven-Roasted Batch'")).firstMatch
        tap(sibling, app); XCTAssertTrue(app.staticTexts["Oven-Roasted Batch"].waitForExistence(timeout: 10))
        capture("Seeded Version Selection", app)
        transition(app.buttons["Re-rank"], app.buttons["comparison-choice-new"], app)
        XCTAssertTrue(app.buttons["comparison-choice-existing"].exists)
        XCTAssertFalse(app.scrollViews["comparison-content"].staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Score '")).firstMatch.exists)
        capture("Seeded Re-rank", app)
        tap(app.buttons["Too Tough"], app)
        XCTAssertTrue(app.staticTexts["1 new answers. Saved history is kept."].waitForExistence(timeout: 10))
        tap(app.buttons["Undo"].exists ? app.buttons["Undo"] : app.buttons["Undo last answer"], app)
        XCTAssertTrue(app.staticTexts["0 new answers. Saved history is kept."].exists)
        tap(app.buttons["Skip"], app)
        XCTAssertTrue(app.staticTexts["0 new answers. Saved history is kept."].exists)
        tap(app.buttons["Cancel"], app)
        XCTAssertTrue(app.navigationBars["Dish Details"].waitForExistence(timeout: 10))
        app.terminate(); app.launch()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        search("harissa", app); count(2, app)
        tap(app.buttons["header-clear-search"], app); tap(app.buttons["search-done"], app)
    }

    @MainActor func testCreationAndSavingRerankOnIsolatedSeededClone() throws {
        _ = try XCTUnwrap(UUID(uuidString: cloneToken))
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); app.launchArguments = ["--ui-test-store", cloneToken]
        app.launch(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        func fill(_ id: String, _ text: String) {
            let field = app.textFields[id]; tap(field, app)
            let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field)
            XCTAssertEqual(XCTWaiter.wait(for: [focused], timeout: 5), .completed)
            field.typeText(text + "\n")
        }
        func finish() {
            transition(app.buttons["Continue"], app.buttons["Liked it"], app)
            tap(app.buttons["Liked it"], app)
            for _ in 0..<20 {
                if app.buttons["ranking-result-close"].waitForExistence(timeout: 1) { break }
                tap(app.buttons["comparison-choice-new"], app)
            }
            transition(app.buttons["ranking-result-close"], app.rankingHeader, app)
        }
        app.revealCreation()
        transition(app.buttons["new-dish"], app.textFields["dish-name"], app)
        fill("dish-name", "Review-only Roasted Cauliflower"); fill("version-title", "Clone first cook")
        finish()
        XCTAssertTrue(row("Clone first cook", app).waitForExistence(timeout: 15))
        app.revealCreation()
        transition(app.buttons["new-version"], app.buttons["choose-dish-Review-only Roasted Cauliflower"], app)
        transition(app.buttons["choose-dish-Review-only Roasted Cauliflower"], app.staticTexts["inherited-dish-name"], app)
        XCTAssertEqual(app.staticTexts["inherited-dish-name"].label, "Review-only Roasted Cauliflower")
        fill("version-title", "Clone second cook"); finish()
        transition(row("Clone second cook", app), app.navigationBars["Dish Details"], app)
        transition(app.buttons["Re-rank"], app.buttons["comparison-choice-new"], app)
        tap(app.buttons["Too Tough"], app)
        XCTAssertTrue(app.staticTexts["1 new answers. Saved history is kept."].waitForExistence(timeout: 10))
        transition(app.buttons["Save Answers"], app.buttons["Edit Cook"], app)
        app.terminate(); app.launch()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        search("Review-only", app)
        XCTAssertTrue(app.staticTexts["2 of 17 ranked cooks · Global ranks"].waitForExistence(timeout: 10))
        XCTAssertTrue(row("Clone first cook", app).exists); XCTAssertTrue(row("Clone second cook", app).exists)
        capture("Isolated Clone Creation Persisted", app)
    }
}
