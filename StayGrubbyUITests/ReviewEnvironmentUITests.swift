import XCTest

final class ReviewEnvironmentUITests: StayGrubbyUITestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func avoidLabelHeight(_ app: XCUIApplication) -> CGFloat {
        let button = app.buttons["ranking-filter-avoid"]
        for _ in 0..<4 {
            if button.exists && button.isHittable && app.windows.firstMatch.frame.contains(button.frame) { break }
            app.scrollViews["filter-strip"].swipeLeft()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
        if !app.buttons["filters-done"].waitForExistence(timeout: 3), button.isHittable { button.tap() }
        XCTAssertTrue(app.buttons["filters-done"].waitForExistence(timeout: 10))
        let milk = app.buttons["filter-avoid-milk"]
        XCTAssertTrue(milk.waitForExistence(timeout: 10))
        let label = milk.staticTexts.firstMatch
        XCTAssertTrue(label.exists)
        let height = label.frame.height
        app.buttons["filters-done"].tap()
        return height
    }

    @MainActor func testAccessibilityReviewScalesRootAndSheetThenReturnsToDefaultOnSameProxy() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--discovery-fixture"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        let defaultHeader = app.rankingHeader.frame.height
        let defaultMilk = avoidLabelHeight(app)
        app.terminate()
        app.launchArguments.append("--test-large-type")
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        XCTAssertGreaterThan(app.rankingHeader.frame.height, defaultHeader * 1.3)
        XCTAssertGreaterThan(avoidLabelHeight(app), defaultMilk * 1.3)
        app.terminate()
        // Leave the old UIKit pair in place to exercise normalization of a reused proxy.
        app.launchArguments.removeAll { $0 == "--test-large-type" }
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        XCTAssertEqual(app.rankingHeader.frame.height, defaultHeader, accuracy: 1)
        XCTAssertEqual(avoidLabelHeight(app), defaultMilk, accuracy: 1)
    }

    @MainActor func testBareReviewFlagsDoNotScaleNormalGuestAndFreshLaunchDoesNotInheritTestSize() {
        let app = XCUIApplication()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        let normal = app.rankingHeader.frame.height
        app.terminate()
        app.launchArguments = ["--test-large-type", "--test-light", "--test-reduce-motion"]
        app.launch()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        XCTAssertEqual(app.rankingHeader.frame.height, normal, accuracy: 1)
        app.terminate()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--discovery-fixture", "--test-large-type"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        XCTAssertGreaterThan(app.rankingHeader.frame.height, normal * 1.3)
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        XCTAssertEqual(app.rankingHeader.frame.height, normal, accuracy: 1)
    }
}
