import XCTest

extension XCUIApplication {
    @MainActor var rankingHeader: XCUIElement {
        descendants(matching: .any).matching(identifier: "staygrubby-header-rankings").firstMatch
    }
    @MainActor var rankingSearchField: XCUIElement { textFields["ranking-search-field"] }
    @MainActor func launchWithReviewOptions() {
        if launchArguments.contains("--test-large-type") && !launchArguments.contains("-UIPreferredContentSizeCategoryName") {
            launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityLarge"]
        }
        launch()
    }
    @MainActor func revealCreation() {
        if buttons["new-dish"].exists { return }
        let toggle = buttons["creation-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        for _ in 0..<3 {
            toggle.tap()
            if buttons["new-dish"].waitForExistence(timeout: 3) { return }
        }
        XCTFail("Creation choices did not appear")
    }
    @MainActor func revealSearch() {
        if rankingSearchField.exists { return }
        buttons["ranking-search"].tap()
        XCTAssertTrue(rankingSearchField.waitForExistence(timeout: 10))
    }
}
