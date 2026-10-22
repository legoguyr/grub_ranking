import XCTest

final class DesignReviewUITests: StayGrubbyUITestCase {
    @MainActor private func launch(_ extra: [String]) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--discovery-fixture", "--social-review", "--social-review-ready", "--recipes-review", "--shared-review", "--social-review-feed"] + extra
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 20)); return app
    }
    @MainActor private func shot(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor private func tab(_ title: String, _ app: XCUIApplication) {
        let control = app.tabBars.buttons[title]
        for _ in 0..<3 { control.tap(); if control.isSelected { return } }
        XCTAssertTrue(control.isSelected, app.debugDescription)
    }
    @MainActor private func reach(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<9 { if element.isHittable { return }; app.swipeUp() }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }
    @MainActor func testRankHistoryKitchenAndFormsInBothAppearances() {
        for appearance in ["--test-light", "--test-dark"] {
        let app = launch([appearance])
        shot("01 Grub Rank \(appearance) Signature Dish", app)
        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-'")).firstMatch
        XCTAssertTrue(first.exists); first.tap(); XCTAssertTrue(app.buttons["detail-edit-cook"].waitForExistence(timeout: 8))
        shot("02 Dish Detail \(appearance)", app)
        reach(app.buttons["detail-edit-cook"], app); app.buttons["detail-edit-cook"].tap()
        XCTAssertTrue(app.textFields["dish-name"].waitForExistence(timeout: 8)); shot("03 Edit Cook \(appearance)", app)
        app.buttons["Cancel"].tap(); XCTAssertTrue(app.buttons["detail-new-version"].waitForExistence(timeout: 8))
        reach(app.buttons["detail-new-version"], app); app.buttons["detail-new-version"].tap()
        XCTAssertTrue(app.staticTexts["inherited-dish-name"].waitForExistence(timeout: 8)); shot("04 New Version \(appearance)", app); app.buttons["Cancel"].tap()
        tab("Food Bible", app); XCTAssertTrue(app.textFields["history-search"].waitForExistence(timeout: 8)); shot("05 Food Bible \(appearance)", app)
        app.buttons["New Dish"].tap(); XCTAssertTrue(app.textFields["dish-name"].waitForExistence(timeout: 8)); shot("24 New Dish \(appearance)", app); app.buttons["Cancel"].tap()
        tab("My Kitchen", app); XCTAssertTrue(app.buttons["settings-open"].waitForExistence(timeout: 8)); shot("06 My Kitchen \(appearance)", app)
        app.buttons["settings-open"].tap(); XCTAssertTrue(app.buttons["settings-account"].waitForExistence(timeout: 8)); shot("07 Settings \(appearance)", app)
        app.terminate()
        }
    }
    @MainActor func testSocialRecipeAndTicketsInBothAppearances() {
        for appearance in ["--test-light", "--test-dark"] {
        let app = launch([appearance])
        tab("Grub List", app); XCTAssertTrue(app.navigationBars["Grub List"].waitForExistence(timeout: 8)); shot("08 Grub List \(appearance)", app)
        let hands = app.buttons["social-like-20000000-0000-0000-0000-000000000001"]
        reach(hands, app); hands.tap()
        let liked = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1 Hands'"), object: hands)
        XCTAssertEqual(XCTWaiter.wait(for: [liked], timeout: 8), .completed); shot("09 Hands \(appearance)", app)
        reach(app.buttons["notifications-open"], app); app.buttons["notifications-open"].tap()
        XCTAssertTrue(app.navigationBars["Order Up!"].waitForExistence(timeout: 8)); shot("10 Order Up \(appearance)", app)
        tab("Tickets", app); XCTAssertTrue(app.buttons["recipe-create"].waitForExistence(timeout: 8)); shot("11 Tickets Empty \(appearance)", app)
        app.segmentedControls.buttons["My Recipes"].tap()
        let recipe = app.buttons["Lemon Soup Recipe"]; XCTAssertTrue(recipe.waitForExistence(timeout: 8)); recipe.tap()
        XCTAssertTrue(app.buttons["recipe-make"].waitForExistence(timeout: 8)); shot("12 Recipe \(appearance)", app)
        reach(app.buttons["recipe-ticket"], app); app.buttons["recipe-ticket"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap(); app.segmentedControls.buttons["Tickets 🎟️"].tap()
        XCTAssertTrue(app.buttons["Lemon Soup Recipe"].waitForExistence(timeout: 8)); shot("13 Tickets Saved \(appearance)", app)
        app.buttons["recipe-create"].tap(); XCTAssertTrue(app.textFields["recipe-edit-title"].waitForExistence(timeout: 8)); shot("25 Recipe Editor \(appearance)", app); app.buttons["Cancel"].tap()
        app.terminate()
        }
    }
    @MainActor func testAccessibilityReduceMotionSocialAndFormsVisualReview() {
        let app = launch(["--test-light", "--test-large-type", "--test-reduce-motion"])
        shot("14 Grub Rank Accessibility Reduced Motion", app)
        tab("My Kitchen", app); reach(app.buttons["friends-open"], app); app.buttons["friends-open"].tap()
        XCTAssertTrue(app.segmentedControls.buttons["Requests"].waitForExistence(timeout: 8)); shot("15 Sous Chefs Accessibility", app)
        app.segmentedControls.buttons["Requests"].tap(); XCTAssertTrue(app.buttons["friend-person-incoming_cook"].waitForExistence(timeout: 8)); shot("16 Requests Accessibility", app)
        tab("Grub Rank", app); app.revealCreation(); app.buttons["new-dish"].tap()
        XCTAssertTrue(app.textFields["dish-name"].waitForExistence(timeout: 8)); shot("17 New Dish Accessibility", app)
        let tag = app.buttons["cooked-with-10000000-0000-0000-0000-000000000001"]
        reach(tag, app)
        for _ in 0..<5 { if tag.frame.maxY < app.windows.firstMatch.frame.maxY - 140 { break }; app.swipeUp() }
        tag.tap(); XCTAssertEqual(tag.value as? String, "Selected"); shot("18 Tag a Sous Chef Accessibility", app)
        app.buttons["Cancel"].tap()
    }
    @MainActor func testComparisonCompletionAndEmptyHistoryVisualReview() {
        let app = launch(["--test-dark", "--test-reduce-motion"])
        app.showAllVersions()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Smoky Sunday'")).firstMatch
        reach(row, app); row.tap()
        reach(app.buttons["detail-rerank"], app); app.buttons["detail-rerank"].tap()
        XCTAssertTrue(app.buttons["It was fine"].waitForExistence(timeout: 8)); shot("19 First Impression Dark", app)
        app.buttons["It was fine"].tap()
        XCTAssertTrue(app.buttons["comparison-choice-new"].waitForExistence(timeout: 8)); shot("20 Comparison Dark", app)
        reach(app.buttons["Too Tough"], app); app.buttons["Too Tough"].tap()
        XCTAssertTrue(app.buttons["ranking-result-close"].waitForExistence(timeout: 15)); shot("21 Ranking Completion Dark Locked", app)
        app.terminate()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--test-light"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 20)); shot("22 Grub Rank Empty Light", app)
        tab("Food Bible", app); XCTAssertTrue(app.textFields["history-search"].waitForExistence(timeout: 8)); shot("23 Food Bible Empty Light", app)
    }

}
