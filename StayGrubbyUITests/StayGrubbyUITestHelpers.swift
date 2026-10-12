import XCTest

/// Test presentation arguments live only as long as their test app process.
class StayGrubbyUITestCase: XCTestCase {
    override func tearDown() async throws {
        await MainActor.run { XCUIApplication().terminate() }
        try await super.tearDown()
    }
}

extension XCUIApplication {
    @MainActor var rankingHeader: XCUIElement {
        descendants(matching: .any).matching(identifier: "staygrubby-header-rankings").firstMatch
    }
    @MainActor var rankingSearchField: XCUIElement { textFields["ranking-search-field"] }
    @MainActor func launchWithReviewOptions() {
        guard let storeIndex = launchArguments.firstIndex(of: "--ui-test-store"),
              launchArguments.indices.contains(storeIndex + 1), UUID(uuidString: launchArguments[storeIndex + 1]) != nil else {
            XCTFail("Review presentation requires an isolated test-store UUID")
            return
        }
        // Rebuild this argument every launch, including when reusing an app proxy.
        // Appending only for large type left stale UIKit overrides in launchArguments.
        var cleaned: [String] = []
        var index = 0
        while index < launchArguments.count {
            if launchArguments[index] == "-UIPreferredContentSizeCategoryName" { index += 2 }
            else { cleaned.append(launchArguments[index]); index += 1 }
        }
        let category = cleaned.contains("--test-large-type") ?
            "UICTContentSizeCategoryAccessibilityLarge" : "UICTContentSizeCategoryL"
        launchArguments = cleaned + ["-UIPreferredContentSizeCategoryName", category]
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
