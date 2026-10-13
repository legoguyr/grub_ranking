#if !DEBUG
import XCTest

/// Runs against the actual Release binary, whose development code is absent.
final class ReleaseAuthenticationGateUITests: StayGrubbyUITestCase {
    @MainActor func testReleaseIgnoresDevelopmentArgumentsAndHasNoPersonalOrBypassAccess() {
        let app = XCUIApplication()
        for arguments in [[], ["--development-library", "--ui-test-store", UUID().uuidString, "--discovery-fixture", "--comparison-fixture", "11"]] {
            app.launchArguments = arguments
            app.launch()
            XCTAssertTrue(app.buttons["account-sign-in-apple"].waitForExistence(timeout: 20))
            XCTAssertTrue(app.staticTexts["onboarding-brand"].exists)
            XCTAssertFalse(app.rankingHeader.exists)
            XCTAssertFalse(app.tabBars.buttons["Rankings"].exists)
            XCTAssertFalse(app.buttons["new-dish"].exists)
            XCTAssertFalse(app.buttons["account-continue-guest"].exists)
            XCTAssertFalse(app.buttons["development-library-open"].exists)
            app.terminate()
        }
    }
}
#endif
