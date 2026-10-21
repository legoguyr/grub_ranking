import XCTest

final class SocialUXUITests: StayGrubbyUITestCase {
    @MainActor func testAvatarPreviewSaveAndRemovalInDarkProfile() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--social-review-avatar-selection", "--test-dark"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.tabBars.buttons["Profile"].tap()
        let edit = app.buttons["social-identity-edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 8)); edit.tap()
        let preview = app.descendants(matching: .any).matching(identifier: "avatar-preview").firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 5)); XCTAssertEqual(preview.label, "Selected profile photo preview")
        app.buttons["social-identity-save"].tap()
        XCTAssertTrue(app.navigationBars["Social identity"].waitForNonExistence(timeout: 8))
        edit.tap(); XCTAssertTrue(app.buttons["avatar-remove"].waitForExistence(timeout: 5)); app.buttons["avatar-remove"].tap()
        XCTAssertEqual(preview.label, "Profile photo initials fallback")
        XCTAssertTrue(app.buttons["social-identity-save"].isHittable, app.debugDescription)
        app.buttons["social-identity-save"].tap()
        XCTAssertTrue(app.navigationBars["Social identity"].waitForNonExistence(timeout: 8))
    }

    @MainActor func testSharingSettingPersistsWithoutPublishing() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--test-light"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.tabBars.buttons["Profile"].tap()
        let settings = app.buttons["social-settings-open"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8)); openSettings(app, link: settings)
        let toggle = app.switches["social-settings-default"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5)); XCTAssertEqual(toggle.value as? String, "0")
        let control = toggle.switches.firstMatch
        XCTAssertTrue(control.exists); control.tap()
        let chosen = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1'"), object: toggle)
        XCTAssertEqual(XCTWaiter.wait(for: [chosen], timeout: 5), .completed, app.debugDescription)
        XCTAssertTrue(app.buttons["social-settings-save"].isEnabled)
        app.buttons["social-settings-save"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "social-settings-saved").firstMatch.waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap(); openSettings(app, link: settings)
        XCTAssertTrue(toggle.waitForExistence(timeout: 5)); XCTAssertEqual(toggle.value as? String, "1")
    }
    @MainActor func testSocialSetupOffersOptionalPrivateDefaultAtLargeText() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--test-light", "--test-large-type"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.tabBars.buttons["Profile"].tap(); let edit = app.buttons["social-identity-edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 8)); edit.tap()
        let name = app.textFields["social-display-name"]
        for _ in 0..<4 { if name.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(name.waitForExistence(timeout: 5)); fill(name, "Social Cook")
        let username = app.textFields["social-username"]; fill(username, "social_cook")
        let toggle = app.switches["social-sharing-default"]
        for _ in 0..<5 { if toggle.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(toggle.waitForExistence(timeout: 5)); XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertTrue(toggle.switches.firstMatch.exists); toggle.switches.firstMatch.tap()
        let chosen = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1'"), object: toggle)
        XCTAssertEqual(XCTWaiter.wait(for: [chosen], timeout: 5), .completed)
        app.buttons["social-identity-save"].tap()
        XCTAssertTrue(app.navigationBars["Social identity"].waitForNonExistence(timeout: 8))
        XCTAssertTrue(app.buttons["social-settings-open"].waitForExistence(timeout: 5))
    }
    @MainActor func testDefaultOffCanShareCompletedCookWithLockedScore() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--test-dark"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.revealCreation(); app.buttons["new-dish"].tap()
        fill(app.textFields["dish-name"], "Shared Soup")
        let toggle = revealSharing(app)
        XCTAssertEqual(toggle.value as? String, "0"); setToggle(toggle, value: "1")
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.buttons["Liked it"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "automatic-share-success").firstMatch.exists)
        app.buttons["Liked it"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "automatic-share-success").firstMatch.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertEqual(app.staticTexts["result-dish-title"].label, "Shared Soup")
        XCTAssertFalse(app.staticTexts["result-score"].exists)
        app.buttons["ranking-result-close"].tap(); selectFeed(app)
        let scope = app.segmentedControls["feed-scope"]
        XCTAssertTrue(scope.waitForExistence(timeout: 5)); scope.buttons["Shared by me"].tap()
        XCTAssertTrue(app.staticTexts["Score locked"].waitForExistence(timeout: 8))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Dark shared cook with locked score and avatar"; shot.lifetime = .keepAlways; add(shot)
    }
    @MainActor func testDefaultOnOverrideOffAndNewVersionUsesCurrentDefault() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--social-review-share-default", "--test-light"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.revealCreation(); app.buttons["new-dish"].tap(); fill(app.textFields["dish-name"], "Version Soup")
        let toggle = revealSharing(app); waitToggle(toggle, value: "1"); setToggle(toggle, value: "0")
        app.buttons["Continue"].tap(); XCTAssertTrue(app.buttons["Liked it"].waitForExistence(timeout: 5)); app.buttons["Liked it"].tap()
        XCTAssertTrue(app.buttons["ranking-result-close"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["share-with-friends"].exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "automatic-share-success").firstMatch.exists)
        app.buttons["ranking-result-close"].tap(); selectFeed(app)
        let scope = app.segmentedControls["feed-scope"]
        XCTAssertTrue(scope.waitForExistence(timeout: 5)); scope.buttons["Shared by me"].tap()
        XCTAssertTrue(app.staticTexts["Nothing shared yet"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Rankings"].tap(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 5))
        app.revealCreation(); app.buttons["new-version"].tap()
        let dish = app.buttons["choose-dish-Version Soup"]
        XCTAssertTrue(dish.waitForExistence(timeout: 5)); dish.tap()
        let nextToggle = revealSharing(app); waitToggle(nextToggle, value: "1")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Light New Version sharing default"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["Continue"].tap(); XCTAssertTrue(app.buttons["Liked it"].waitForExistence(timeout: 5)); app.buttons["Liked it"].tap()
        let prefer = app.buttons["Prefer Version Soup — Version 2"]
        XCTAssertTrue(prefer.waitForExistence(timeout: 8), app.debugDescription); prefer.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "automatic-share-success").firstMatch.waitForExistence(timeout: 10), app.debugDescription)
    }
    @MainActor private func revealSharing(_ app: XCUIApplication) -> XCUIElement {
        let toggle = app.switches["cook-share-with-friends"]
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.scrollViews["cooking-form"].exists)
        for _ in 0..<8 {
            if toggle.switches.firstMatch.isHittable { break }
            if toggle.exists && toggle.frame.midY < app.navigationBars.firstMatch.frame.maxY + 30 {
                app.scrollViews["cooking-form"].swipeDown()
            } else { app.scrollViews["cooking-form"].swipeUp() }
        }
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(toggle.switches.firstMatch.isHittable, app.debugDescription)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: toggle)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        return toggle
    }
    @MainActor private func setToggle(_ toggle: XCUIElement, value: String) {
        let control = toggle.switches.firstMatch
        XCTAssertTrue(control.exists); XCTAssertTrue(control.isHittable); control.tap(); waitToggle(toggle, value: value)
    }
    @MainActor private func waitToggle(_ toggle: XCUIElement, value: String) {
        let chosen = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: toggle)
        XCTAssertEqual(XCTWaiter.wait(for: [chosen], timeout: 5), .completed, XCUIApplication().debugDescription)
    }
    @MainActor private func selectFeed(_ app: XCUIApplication) {
        let feed = app.tabBars.buttons["Feed"]
        for _ in 0..<3 {
            feed.tap()
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: feed)
            if XCTWaiter.wait(for: [selected], timeout: 3) == .completed { return }
        }
        XCTFail("Feed navigation did not complete")
    }
    @MainActor private func fill(_ field: XCUIElement, _ value: String) {
        for _ in 0..<3 {
            field.tap()
            let focus = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field)
            if XCTWaiter.wait(for: [focus], timeout: 3) == .completed {
                field.typeText(value)
                let key = XCUIApplication().keyboards.buttons["return"]
                if key.exists { key.tap() }
                return
            }
        }
        XCTFail("Text field did not acquire focus")
    }
    @MainActor private func openSettings(_ app: XCUIApplication, link: XCUIElement) {
        for _ in 0..<3 {
            link.tap()
            if app.navigationBars["Social settings"].waitForExistence(timeout: 3) { return }
        }
        XCTFail("Social settings navigation did not complete: \(app.debugDescription)")
    }
}
