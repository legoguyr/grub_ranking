import XCTest

final class SocialPostUITests: StayGrubbyUITestCase {
    @MainActor func testCookingStaysPrivateUntilExplicitPublishAndLockedScoreIsOmitted() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--test-dark"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15)); app.revealCreation(); app.buttons["new-dish"].tap()
        let name = app.textFields["dish-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Private Social Soup")
        app.buttons["Continue"].tap(); app.buttons["Liked it"].tap()
        let share = app.buttons["share-with-friends"]
        XCTAssertTrue(share.waitForExistence(timeout: 15))
        XCTAssertFalse(app.alerts["Shared with Friends"].exists)
        share.tap()
        XCTAssertTrue(app.staticTexts["social-share-score-locked"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["social-share-publish"].exists)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(share.waitForExistence(timeout: 5)); share.tap()
        let publish = app.buttons["social-share-publish"]
        XCTAssertTrue(publish.waitForExistence(timeout: 5)); publish.tap()
        XCTAssertTrue(app.alerts["Shared with Friends"].waitForExistence(timeout: 10)); app.alerts.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["ranking-result-close"].waitForExistence(timeout: 5)); app.buttons["ranking-result-close"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Private Social Soup'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5)); XCTAssertTrue(row.label.contains("score locked"))
    }
}
