import XCTest

final class OnboardingUITests: StayGrubbyUITestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(category: String = "UICTContentSizeCategoryL") -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", category]
        app.launch()
        XCTAssertTrue(app.buttons["account-sign-in-apple"].waitForExistence(timeout: 20))
        return app
    }

    @MainActor private func assertGated(_ app: XCUIApplication) {
        XCTAssertFalse(app.tabBars.buttons["Grub Rank"].exists)
        XCTAssertFalse(app.tabBars.buttons["My Kitchen"].exists)
        XCTAssertFalse(app.buttons["new-dish"].exists)
        XCTAssertFalse(app.buttons["account-continue-guest"].exists)
        XCTAssertFalse(app.buttons["Skip"].exists)
        XCTAssertFalse(app.buttons["Continue as guest"].exists)
        #if !DEBUG
        XCTAssertFalse(app.buttons["development-library-open"].exists)
        #endif
    }

    @MainActor private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor func testWelcomeExplainsComparisonAndKeepsNativeAppleInReach() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["onboarding-brand"].exists)
        XCTAssertTrue(app.staticTexts["Good food.\nYour signature."].exists)
        XCTAssertTrue(app.descendants(matching: .any)["onboarding-comparison-example"].exists)
        XCTAssertTrue(app.buttons["account-sign-in-apple"].isHittable)
        XCTAssertGreaterThanOrEqual(app.buttons["account-sign-in-apple"].frame.height, 44)
        assertGated(app)
        capture("Welcome · portrait", app: app)
    }

    @MainActor private func assertScrollableAuthentication(_ app: XCUIApplication) {
        let apple = app.buttons["account-sign-in-apple"]
        let gate = app.descendants(matching: .any).matching(identifier: "authentication-gate").firstMatch
        XCTAssertTrue(gate.exists)
        for _ in 0..<10 {
            if apple.exists && apple.isHittable && gate.frame.insetBy(dx: 0, dy: 8).contains(apple.frame) { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(apple.isHittable)
        XCTAssertGreaterThanOrEqual(apple.frame.height, 44)
        XCTAssertTrue(gate.frame.insetBy(dx: 0, dy: 8).contains(apple.frame), "The entire native Apple button must be visible.")
        assertGated(app)
    }

    @MainActor func testLargestTextCanScrollToNativeAuthentication() {
        let app = launch(category: "UICTContentSizeCategoryAccessibilityXXXL")
        assertScrollableAuthentication(app)
        capture("Welcome · maximum accessibility text", app: app)
    }

    @MainActor func testAccessibilityLargeTextCanScrollToNativeAuthentication() {
        let app = launch(category: "UICTContentSizeCategoryAccessibilityL")
        assertScrollableAuthentication(app)
        capture("Welcome · accessibility large text", app: app)
    }

    @MainActor func testRelaunchStillRequiresAuthentication() {
        let app = launch()
        assertGated(app)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["account-sign-in-apple"].waitForExistence(timeout: 20))
        assertGated(app)
    }
}
