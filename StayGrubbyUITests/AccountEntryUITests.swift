import XCTest

final class AccountEntryUITests: StayGrubbyUITestCase {
    @MainActor func testLoggedOutRootHasNativeAppleAndNoPersonalApplication() {
        let app=XCUIApplication();app.launchArguments=[];app.launch()
        XCTAssertTrue(app.buttons["account-sign-in-apple"].waitForExistence(timeout:15))
        XCTAssertTrue(app.staticTexts["onboarding-brand"].exists)
        XCTAssertFalse(app.rankingHeader.exists)
        XCTAssertFalse(app.tabBars.buttons["Rankings"].exists)
        XCTAssertFalse(app.buttons["new-dish"].exists)
        XCTAssertFalse(app.buttons["new-version"].exists)
        XCTAssertFalse(app.buttons["comparison-new"].exists)
        XCTAssertFalse(app.buttons["account-continue-guest"].exists)
    }
    @MainActor func testIsolatedDevelopmentEmptyRankingAndExitReturnToGate() {
        let app=XCUIApplication()
        app.launchArguments=["--ui-test-store",UUID().uuidString];app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout:15))
        XCTAssertTrue(app.staticTexts["Your cooking, ranked"].exists)
        XCTAssertEqual(app.tabBars.buttons.count,2)
        XCTAssertTrue(app.tabBars.buttons["Rankings"].exists)
        XCTAssertTrue(app.tabBars.buttons["Profile"].exists)
        XCTAssertFalse(app.tabBars.buttons["Feed"].exists)
        app.tabBars.buttons["Profile"].tap()
        XCTAssertTrue(app.buttons["development-exit"].waitForExistence(timeout:10))
        XCTAssertFalse(app.buttons["account-sign-in-apple"].exists)
        app.buttons["development-exit"].tap()
        XCTAssertTrue(app.buttons["account-sign-in-apple"].waitForExistence(timeout:10))
        XCTAssertFalse(app.rankingHeader.exists)
    }
}
