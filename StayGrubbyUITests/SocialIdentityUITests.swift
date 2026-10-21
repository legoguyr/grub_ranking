import XCTest

final class SocialIdentityUITests: StayGrubbyUITestCase {
    @MainActor private func fill(_ field: XCUIElement, _ text: String) {
        for _ in 0..<3 {
            field.tap()
            let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field)
            if XCTWaiter.wait(for: [focused], timeout: 3) == .completed { field.typeText(text); return }
        }
        XCTFail("Text field did not acquire keyboard focus")
    }
    @MainActor func testOptionalSetupSaveRenameAndDiscoverability() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--test-dark"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.tabBars.buttons["Profile"].tap()
        let edit = app.buttons["social-identity-edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10)); edit.tap()
        let name = app.textFields["social-display-name"], username = app.textFields["social-username"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); fill(name, "Home Cook")
        fill(username, "home_cook")
        XCTAssertTrue(app.switches["social-discoverable"].exists)
        XCTAssertEqual(app.switches["social-discoverable"].value as? String, "0")
        app.buttons["social-identity-save"].tap()
        XCTAssertTrue(app.staticTexts["@home_cook"].waitForExistence(timeout: 5))
        edit.tap(); XCTAssertEqual(username.value as? String, "home_cook")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["social-identity-edit"].waitForExistence(timeout: 5))
    }
}
