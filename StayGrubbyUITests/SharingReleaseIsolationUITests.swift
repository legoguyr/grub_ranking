#if !DEBUG
import XCTest

final class SharingReleaseIsolationUITests: StayGrubbyUITestCase {
    @MainActor func testReleaseCannotActivateSharingFaultReview() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--sharing-fixture", "result",
            "--sharing-preview-fails-once", "--sharing-save-failure-review"]
        app.launch()
        XCTAssertTrue(app.buttons["account-sign-in-apple"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.buttons["review-save-failure"].exists)
        XCTAssertFalse(app.buttons["share-preview-retry"].exists)
        XCTAssertFalse(app.staticTexts["result-dish-title"].exists)
        XCTAssertFalse(app.images["ranking-share-preview"].exists)
        XCTAssertFalse(app.rankingHeader.exists)
    }
}
#endif
