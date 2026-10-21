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
    @MainActor private func fill(_ field: XCUIElement, _ value: String) {
        for _ in 0..<3 {
            field.tap()
            let focus = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field)
            if XCTWaiter.wait(for: [focus], timeout: 3) == .completed { field.typeText(value); return }
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
