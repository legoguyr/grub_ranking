import XCTest

final class SocialFeedUITests: StayGrubbyUITestCase {
    @MainActor private func launch(_ args: [String]) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready"] + args
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15)); app.tabBars.buttons["Grub List"].tap()
        return app
    }
    @MainActor func testFeedErrorRetryAndBlockRevokesVisiblePosts() throws {
        let app = launch(["--test-dark", "--social-review-feed", "--social-review-feed-error"])
        XCTAssertTrue(app.staticTexts["feed-error"].waitForExistence(timeout: 8), app.debugDescription); app.buttons["feed-retry"].tap()
        XCTAssertTrue(app.staticTexts["Harissa Chicken with Roasted Peppers"].waitForExistence(timeout: 8))
        app.buttons["View Friendly Cook’s profile"].tap()
        XCTAssertTrue(app.buttons["Block"].waitForExistence(timeout: 5)); app.buttons["Block"].tap(); app.buttons["Block Person"].tap()
        XCTAssertTrue(app.buttons["feed-find-friends"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Harissa Chicken with Roasted Peppers"].exists)
    }
    @MainActor func testFeedLightAccessibilityAndOwnEmptyState() throws {
        let app = launch(["--test-light", "--test-large-type", "--social-review-feed"])
        XCTAssertTrue(app.staticTexts["Harissa Chicken with Roasted Peppers"].waitForExistence(timeout: 8))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Feed light accessibility"; shot.lifetime = .keepAlways; add(shot)
        app.segmentedControls["feed-scope"].buttons["Shared by me"].tap()
        XCTAssertTrue(app.staticTexts["Nothing shared yet"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Grub Rank"].tap(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 5))
    }
}
