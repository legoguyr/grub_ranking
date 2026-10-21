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
}
