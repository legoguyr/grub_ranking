import XCTest

final class CookingDiscoveryUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(largeType: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--discovery-fixture",
                               largeType ? "--test-light" : "--test-dark"]
        if largeType { app.launchArguments.append("--test-large-type") }
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        return app
    }

    @MainActor private func wait(_ predicate: String, on element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)],
                      timeout: timeout) == .completed
    }

    @MainActor private func reach(_ element: XCUIElement, in app: XCUIApplication, scrollDown: Bool = false) {
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            if scrollDown { app.swipeDown() } else { app.swipeUp() }
        }
        XCTFail("Could not reach \(element)")
    }

    @MainActor private func transition(_ button: XCUIElement, to next: XCUIElement, in app: XCUIApplication) {
        reach(button, in: app)
        for _ in 0..<3 {
            button.tap()
            if next.waitForExistence(timeout: 5) { return }
        }
        XCTFail("Transition did not reach \(next)")
    }

    @MainActor private func search(_ query: String, in app: XCUIApplication) {
        app.revealSearch()
        let field = app.rankingSearchField
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        XCTAssertTrue(wait("hasKeyboardFocus == true", on: field))
        let current = field.value as? String ?? ""
        if current != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(query + "\n")
        XCTAssertTrue(wait("value == '\(query)'", on: field))
    }

    @MainActor private func row(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS %@", name)).firstMatch
    }

    @MainActor private func select(_ option: XCUIElement, in app: XCUIApplication) {
        reach(option, in: app)
        if option.value as? String == "Selected" { return }
        option.tap()
        XCTAssertTrue(wait("value == 'Selected'", on: option))
    }

    @MainActor private func filters(_ group: String, in app: XCUIApplication) {
        let button = app.buttons["ranking-filter-\(group)"]
        for _ in 0..<4 {
            if button.exists && button.isHittable { break }
            app.scrollViews["filter-strip"].swipeLeft()
        }
        transition(button, to: app.buttons["filters-done"], in: app)
    }

    @MainActor private func doneFilters(in app: XCUIApplication) {
        app.buttons["filters-done"].tap()
        XCTAssertTrue(app.buttons["ranking-filter-course"].waitForExistence(timeout: 10))
    }

    @MainActor private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    @MainActor
    func testSearchCombinedFiltersClearAndDetailNavigation() throws {
        let app = launch()
        capture("Full ranking Dark", app: app)
        search("chicken", in: app)
        XCTAssertTrue(row("Golden sear", in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(row("Smoky Sunday", in: app).exists)
        XCTAssertFalse(row("Sea Bass", in: app).exists)
        capture("Search results Dark", app: app)

        filters("course", in: app)
        select(app.buttons["filter-course-main"], in: app); doneFilters(in: app)
        filters("dietary", in: app)
        select(app.buttons["filter-dietary-kosher"], in: app); doneFilters(in: app)
        filters("avoid", in: app)
        select(app.buttons["filter-avoid-sesame"], in: app)
        capture("Combined filters Dark", app: app); doneFilters(in: app)
        let golden = row("Golden sear", in: app)
        XCTAssertTrue(golden.waitForExistence(timeout: 10))
        XCTAssertTrue(golden.label.hasPrefix("Rank 2,"))
        XCTAssertFalse(row("Smoky Sunday", in: app).exists)
        XCTAssertTrue(app.buttons["ranking-filter-course"].label.contains("1 active"))
        XCTAssertTrue(app.buttons["ranking-filter-dietary"].label.contains("1 active"))
        XCTAssertTrue(app.buttons["ranking-filter-avoid"].label.contains("1 active"))
        capture("Combined result Dark", app: app)

        transition(golden, to: app.navigationBars["Dish Details"], in: app)
        XCTAssertTrue(app.staticTexts["Golden sear"].exists)
        transition(app.navigationBars.buttons.firstMatch, to: app.rankingSearchField, in: app)
        XCTAssertEqual(app.rankingSearchField.value as? String, "chicken")
        XCTAssertTrue(app.buttons["clear-filters"].exists)
        XCTAssertFalse(row("Smoky Sunday", in: app).exists)

        search("ramen", in: app)
        XCTAssertTrue(app.staticTexts["No filter matches"].waitForExistence(timeout: 10))
        transition(app.buttons["clear-filters"], to: app.staticTexts["No search results"], in: app)
        capture("No search results Dark", app: app)
        transition(app.buttons["clear-search"], to: row("Apple Cake", in: app), in: app)
        XCTAssertTrue(row("Smoky Sunday", in: app).exists)
        XCTAssertFalse(app.buttons["clear-filters"].exists)
    }

    @MainActor
    func testLargeTypeLightFiltersAndIndividualClearing() throws {
        let app = launch(largeType: true)
        capture("Full ranking Light Large Type", app: app)
        filters("dietary", in: app)
        select(app.buttons["filter-dietary-kosher"], in: app)
        select(app.buttons["filter-dietary-vegan"], in: app); doneFilters(in: app)
        filters("avoid", in: app)
        select(app.buttons["filter-avoid-sesame"], in: app)
        capture("Filters Light Large Type", app: app); doneFilters(in: app)
        XCTAssertTrue(row("Golden sear", in: app).exists)
        reach(row("Lemon Pasta", in: app), in: app)
        XCTAssertTrue(row("Lemon Pasta", in: app).exists)
        XCTAssertFalse(row("Smoky Sunday", in: app).exists)
        capture("Filtered ranking Light Large Type", app: app)
        filters("dietary", in: app)
        let kosher = app.buttons["filter-dietary-kosher"]
        XCTAssertEqual(kosher.value as? String, "Selected")
        kosher.tap(); XCTAssertTrue(wait("value == 'Not selected'", on: kosher))
        doneFilters(in: app)
        reach(row("Lemon Pasta", in: app), in: app)
        XCTAssertTrue(row("Lemon Pasta", in: app).waitForExistence(timeout: 10))
        XCTAssertFalse(row("Golden sear", in: app).exists)
        reach(app.buttons["clear-filters"], in: app, scrollDown: true)
        transition(app.buttons["clear-filters"], to: row("Smoky Sunday", in: app), in: app)
        XCTAssertFalse(app.buttons["clear-filters"].exists)
    }

    @MainActor
    func testEditingFromSearchUpdatesResultsWhilePreservingFiltersAndScore() throws {
        let app = launch()
        filters("dietary", in: app)
        select(app.buttons["filter-dietary-kosher"], in: app); doneFilters(in: app)
        search("Golden", in: app)
        let golden = row("Golden sear", in: app)
        XCTAssertTrue(golden.waitForExistence(timeout: 10))
        let oldID = golden.identifier
        let oldScore = String(golden.label.split(separator: ",").last ?? "")
        transition(golden, to: app.navigationBars["Dish Details"], in: app)
        transition(app.buttons["Edit Cook"], to: app.textFields["version-title"], in: app)
        let title = app.textFields["version-title"]
        reach(title, in: app); title.tap()
        XCTAssertTrue(wait("hasKeyboardFocus == true", on: title))
        title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Golden sear".count) + "Crispy\n")
        transition(app.buttons["save-cook-metadata"], to: app.staticTexts["Crispy"], in: app)
        reach(app.staticTexts["Cookbook · Zahav"], in: app)
        XCTAssertTrue(app.staticTexts["Cookbook · Zahav"].exists)
        transition(app.navigationBars.buttons.firstMatch, to: app.rankingSearchField, in: app)
        XCTAssertEqual(app.rankingSearchField.value as? String, "Golden")
        XCTAssertTrue(app.staticTexts["No filter matches"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["ranking-filter-dietary"].label.contains("1 active"))
        transition(app.buttons["clear-search"], to: app.buttons[oldID], in: app)
        let updated = app.buttons[oldID]
        XCTAssertTrue(updated.label.contains("Crispy"))
        XCTAssertEqual(String(updated.label.split(separator: ",").last ?? ""), oldScore)
        XCTAssertTrue(app.buttons["clear-filters"].exists)
    }

    @MainActor
    func testIndividualFilterGroupsAndCreationNavigation() throws {
        let app = launch()
        filters("course", in: app)
        select(app.buttons["filter-course-dessert"], in: app); doneFilters(in: app)
        XCTAssertTrue(row("Apple Cake", in: app).label.hasPrefix("Rank 5,"))
        XCTAssertFalse(row("Golden sear", in: app).exists)
        capture("Course only", app: app)

        app.revealCreation()
        capture("Creation expanded", app: app)
        transition(app.buttons["new-dish"], to: app.textFields["dish-name"], in: app)
        capture("New Dish with existing filtered ranking", app: app)
        transition(app.buttons["Cancel"], to: row("Apple Cake", in: app), in: app)
        XCTAssertTrue(app.buttons["ranking-filter-course"].label.contains("1 active"))
        app.revealCreation()
        transition(app.buttons["new-version"], to: app.buttons["choose-dish-Harissa Chicken"], in: app)
        transition(app.buttons["choose-dish-Harissa Chicken"], to: app.staticTexts["inherited-dish-name"], in: app)
        XCTAssertEqual(app.staticTexts["inherited-dish-name"].label, "Harissa Chicken")
        capture("New Version from filtered ranking", app: app)
        transition(app.buttons["Cancel"], to: row("Apple Cake", in: app), in: app)

        transition(app.buttons["clear-filters"], to: row("Smoky Sunday", in: app), in: app)
        filters("dietary", in: app)
        select(app.buttons["filter-dietary-kosher"], in: app); doneFilters(in: app)
        XCTAssertTrue(row("Golden sear", in: app).exists)
        XCTAssertFalse(row("Smoky Sunday", in: app).exists)
        capture("Dietary only", app: app)

        transition(app.buttons["clear-filters"], to: row("Smoky Sunday", in: app), in: app)
        filters("avoid", in: app)
        select(app.buttons["filter-avoid-sesame"], in: app); doneFilters(in: app)
        XCTAssertTrue(row("Golden sear", in: app).exists)
        XCTAssertFalse(row("Sea Bass", in: app).exists)
        capture("Avoid only", app: app)
        search("chicken", in: app)
        XCTAssertTrue(row("Golden sear", in: app).waitForExistence(timeout: 10))
        XCTAssertFalse(row("Lemon Pasta", in: app).exists)
        search("ramen", in: app)
        XCTAssertTrue(app.staticTexts["No filter matches"].waitForExistence(timeout: 10))
        capture("No combined matches", app: app)
        transition(app.buttons["empty-clear-filters"], to: app.staticTexts["No search results"], in: app)
        XCTAssertEqual(app.rankingSearchField.value as? String, "ramen")
        transition(app.buttons["clear-search"], to: row("Apple Cake", in: app), in: app)
        XCTAssertFalse(app.buttons["clear-filters"].exists)
    }
}
