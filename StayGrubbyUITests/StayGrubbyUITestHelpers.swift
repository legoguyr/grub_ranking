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
    /// Older version-specific regressions exercise the complete ranking view.
    /// Verify the actual local presentation preference before querying siblings.
    @MainActor func showAllVersions() {
        let control = buttons["All Versions"]
        XCTAssertTrue(control.waitForExistence(timeout: 15))
        for _ in 0..<2 {
            if control.isSelected { return }
            control.tap()
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: control)
            if XCTWaiter.wait(for: [selected], timeout: 3) == .completed { return }
            activate()
        }
        XCTAssertTrue(control.isSelected, "All Versions must actually be selected")
    }
    @MainActor func revealSearch() {
        if rankingSearchField.exists { return }
        buttons["ranking-search"].tap()
        XCTAssertTrue(rankingSearchField.waitForExistence(timeout: 10))
    }
}

extension XCUIApplication {
    @MainActor func openAccountProfileSettings() {
        for _ in 0..<3 {
            tabBars.buttons["Profile"].tap()
            if buttons["settings-open"].waitForExistence(timeout: 3) { break }
        }
        XCTAssertTrue(buttons["settings-open"].waitForExistence(timeout: 8), debugDescription)
        buttons["settings-open"].tap()
        XCTAssertTrue(buttons["settings-account"].waitForExistence(timeout: 8), debugDescription)
        buttons["settings-account"].tap()
        XCTAssertTrue(buttons["social-identity-edit"].waitForExistence(timeout: 8), debugDescription)
    }
}
