import XCTest

final class AccountEntryUITests: StayGrubbyUITestCase {
    @MainActor func testLoggedOutRootHasNativeAppleAndNoPersonalApplication() {
        let app=XCUIApplication();app.launchArguments=[];app.launch()
        XCTAssertTrue(app.buttons["account-sign-in-apple"].waitForExistence(timeout:15))
        XCTAssertTrue(app.staticTexts["onboarding-brand"].exists)
        XCTAssertFalse(app.rankingHeader.exists)
        XCTAssertFalse(app.tabBars.buttons["Grub Rank"].exists)
        XCTAssertFalse(app.buttons["new-dish"].exists)
        XCTAssertFalse(app.buttons["new-version"].exists)
        XCTAssertFalse(app.buttons["comparison-new"].exists)
        XCTAssertFalse(app.buttons["account-continue-guest"].exists)
    }
    @MainActor func testIsolatedDevelopmentEmptyRankingAndExitReturnToGate() {
        let app=XCUIApplication()
        app.launchArguments=["--ui-test-store",UUID().uuidString];app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout:15))
        XCTAssertTrue(app.staticTexts["Your taste. Your Grub Rank."].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.tabBars.buttons["Grub Rank"].isSelected, app.debugDescription)
        XCTAssertEqual(app.tabBars.buttons.count,5)
        XCTAssertTrue(app.tabBars.buttons["Food Bible"].exists)
        XCTAssertFalse(app.tabBars.buttons["Tickets"].exists)
        XCTAssertEqual(app.tabBars.buttons.count, 4)
        XCTAssertTrue(app.tabBars.buttons["Grub Rank"].exists)
        XCTAssertTrue(app.tabBars.buttons["My Kitchen"].exists)
        XCTAssertTrue(app.tabBars.buttons["Grub List"].exists)
        let profile = app.tabBars.buttons["My Kitchen"]
        for _ in 0..<3 {
            profile.tap()
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: profile)
            if XCTWaiter.wait(for: [selected], timeout: 3) == .completed { break }
        }
        XCTAssertTrue(profile.isSelected, app.debugDescription)
        XCTAssertTrue(app.buttons["development-exit"].waitForExistence(timeout:10))
        XCTAssertFalse(app.buttons["account-sign-in-apple"].exists)
        let exit = app.buttons["development-exit"]
        for _ in 0..<3 {
            if !exit.isHittable { app.swipeUp() }
            if exit.exists { exit.tap() }
            if app.buttons["account-sign-in-apple"].waitForExistence(timeout: 3) { break }
        }
        XCTAssertTrue(app.buttons["account-sign-in-apple"].waitForExistence(timeout:10), app.debugDescription)
        XCTAssertFalse(app.rankingHeader.exists)
    }
}
