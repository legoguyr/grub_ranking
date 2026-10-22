import XCTest

final class ProductStructureUITests: StayGrubbyUITestCase {
    @MainActor func testFourTabsKitchenFriendsHitAreaAndSingleProfileEditor() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--recipes-review", "--product-review-grid", "--test-light"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 20))
        XCTAssertTrue(app.tabBars.buttons["Grub Rank"].isSelected)
        XCTAssertEqual(app.tabBars.buttons.count, 4); XCTAssertFalse(app.tabBars.buttons["Tickets"].exists)
        app.tabBars.buttons["Food Bible"].tap()
        XCTAssertTrue(app.segmentedControls.buttons["Recipes"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Lemon Soup Recipe"].waitForExistence(timeout: 8))
        shot("Food Bible Recipes Light", app)
        app.segmentedControls.buttons["Tickets"].tap()
        XCTAssertTrue(app.staticTexts["No Tickets yet. Save a recipe you want to cook."].waitForExistence(timeout: 8))
        shot("Food Bible Tickets Empty Light", app)
        app.tabBars.buttons["My Kitchen"].tap()
        XCTAssertTrue(app.staticTexts["@review_cook"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["recipes-open"].exists)
        shot("Kitchen identity and own post grid Light", app)
        let friends = app.buttons["friends-open"]
        XCTAssertTrue(friends.waitForExistence(timeout: 8))
        XCTAssertGreaterThan(friends.frame.width, 280); XCTAssertGreaterThanOrEqual(friends.frame.height, 44)
        // Tap the padded right edge, away from the text. The whole visible row must navigate.
        friends.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
        XCTAssertTrue(app.segmentedControls.buttons["Find Sous Chefs"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["friend-person-friend_cook"].waitForExistence(timeout: 8))
        shot("Sous Chefs connections Light", app)
        app.segmentedControls.buttons["Find Sous Chefs"].tap(); XCTAssertTrue(app.textFields["friends-search"].waitForExistence(timeout: 8))
        app.segmentedControls.buttons["Requests"].tap(); XCTAssertTrue(app.buttons["friend-person-incoming_cook"].waitForExistence(timeout: 8))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["settings-open"].tap()
        XCTAssertTrue(app.buttons["settings-account"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Discoverability & profile privacy"].exists)
        shot("Full-width Settings Light", app)
        app.buttons["settings-account"].tap()
        XCTAssertTrue(app.textFields["social-display-name"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["social-identity-edit"].exists)
        XCTAssertTrue(app.switches["social-discoverable"].exists)
        XCTAssertFalse(app.switches["social-sharing-default"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Single full-width Profile editor"; shot.lifetime = .keepAlways; add(shot)
    }
    @MainActor private func shot(_ name: String, _ app: XCUIApplication) {
        let value = XCTAttachment(screenshot: app.screenshot()); value.name = name; value.lifetime = .keepAlways; add(value)
    }
    @MainActor func testProfileGridOpensDetailAndDescriptionOverflowAtLargeText() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--product-review-grid", "--social-review-feed", "--test-dark", "--test-large-type", "--test-reduce-motion"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 20))
        app.tabBars.buttons["My Kitchen"].tap()
        let post = app.buttons["profile-post-70000000-0000-0000-0000-000000000001"]
        for _ in 0..<7 { if post.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(post.exists)
        for _ in 0..<5 { if post.frame.maxY < app.tabBars.firstMatch.frame.minY { break }; app.swipeUp() }
        shot("Kitchen post grid Dark accessibility reduced motion", app); post.tap()
        let title = app.staticTexts["Lemon Soup"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["post-description-70000000-0000-0000-0000-000000000001"].exists)
        XCTAssertFalse(app.buttons["feed-delete-70000000-0000-0000-0000-000000000001"].exists)
        shot("Owned Post Detail Dark description", app)
        app.buttons["post-actions-70000000-0000-0000-0000-000000000001"].tap()
        XCTAssertTrue(app.buttons["post-edit-70000000-0000-0000-0000-000000000001"].waitForExistence(timeout: 5))
        shot("Owned Post Overflow Dark", app)
        app.buttons["post-edit-70000000-0000-0000-0000-000000000001"].tap()
        let description = app.textFields["post-description-input"]
        XCTAssertTrue(description.waitForExistence(timeout: 8)); description.tap(); description.typeText(" A new shared thought.")
        app.buttons["post-edit-save"].tap()
        let caption = app.staticTexts["post-description-70000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(caption.waitForExistence(timeout: 8)); XCTAssertTrue(caption.label.contains("A new shared thought."))
        XCTAssertFalse(app.staticTexts["Personal Notes"].exists)
        app.tabBars.buttons["Grub List"].tap()
        let preview = app.buttons["post-open-20000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(preview.waitForExistence(timeout: 8)); shot("Grub List preview Dark accessibility", app); preview.tap()
        XCTAssertTrue(app.navigationBars["Post"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["View Friendly Cook’s profile"].exists)
    }

}
