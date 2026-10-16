#if DEBUG
import XCTest

final class V1RevisionUITests: StayGrubbyUITestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor private func launch(_ count: Int, large: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--score-unlock-fixture", "\(count)", "--test-dark", "--test-reduce-motion"]
        if large { app.launchArguments.append("--test-large-type") }
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 20)); return app
    }
    @MainActor private func tap(_ element: XCUIElement, _ app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 15))
        for _ in 0..<10 { if element.isHittable { element.tap(); return }; app.swipeUp() }
        XCTFail("Unreachable \(element)")
    }
    @MainActor private func transition(_ control: XCUIElement, to next: XCUIElement, _ app: XCUIApplication) {
        tap(control, app)
        if !next.waitForExistence(timeout: 5), control.exists && control.isHittable { app.activate(); control.tap() }
        XCTAssertTrue(next.waitForExistence(timeout: 15))
    }
    @MainActor private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name
        attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor private func firstRow(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-'")).firstMatch
    }
    @MainActor func testCenteredDetailActionsInLightAndDarkKeepEditAndNewVersionRoutes() {
        for appearance in ["--test-light", "--test-dark"] {
            let app = XCUIApplication()
            app.launchArguments = ["--ui-test-store", UUID().uuidString, "--score-unlock-fixture", "12", appearance]
            app.launchWithReviewOptions()
            XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 20))
            transition(firstRow(app), to: app.navigationBars["Dish Details"], app)
            let edit = app.buttons["detail-edit-cook"], rerank = app.buttons["detail-rerank"], share = app.buttons["detail-share-dish"]
            XCTAssertEqual(edit.frame.midY, rerank.frame.midY, accuracy: 2)
            XCTAssertEqual(edit.frame.height, share.frame.height, accuracy: 2)
            XCTAssertGreaterThanOrEqual(edit.frame.height, 44 - 0.01) // XCTest frame rounding.
            capture("Centered pencil \(appearance)", app)
            transition(edit, to: app.textFields["version-title"], app)
            tap(app.buttons["Cancel"], app)
            XCTAssertTrue(edit.waitForExistence(timeout: 15))
            let version = app.buttons["detail-new-version"]
            for _ in 0..<10 { if version.exists && version.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(version.exists && version.isHittable)
            XCTAssertGreaterThanOrEqual(version.frame.height, 44 - 0.01)
            capture("Centered plus \(appearance)", app)
            transition(version, to: app.buttons["Continue"], app)
            tap(app.buttons["Cancel"], app)
            XCTAssertTrue(app.navigationBars["Dish Details"].waitForExistence(timeout: 15))
            app.terminate()
        }
    }
    @MainActor func testDisplayModesKeepGlobalRanksAndPersistWithoutChangingUnlockProgress() {
        let app = launch(9)
        XCTAssertTrue(app.buttons["Top Version"].isSelected)
        let hidden = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label BEGINSWITH 'Rank 2,'")).firstMatch
        XCTAssertFalse(hidden.exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label BEGINSWITH 'Rank 3,'")).firstMatch.exists)
        let banner = app.descendants(matching: .any)["score-unlock-banner"]
        XCTAssertTrue(banner.label.contains("9 / 10")); capture("Top Version red locked dark", app)
        transition(app.buttons["All Versions"], to: hidden, app)
        XCTAssertTrue(hidden.label.contains("Version 1") && hidden.label.contains("score locked"))
        XCTAssertTrue(banner.label.contains("9 / 10")); capture("All Versions true global ranks", app)
        app.terminate(); app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["All Versions"].isSelected && hidden.exists)
        tap(app.buttons["Top Version"], app)
        XCTAssertFalse(hidden.exists)
    }
    @MainActor func testFreshRerankReactionControlsAutomaticResultAndProfileTopThree() {
        let app = launch(12)
        transition(firstRow(app), to: app.navigationBars["Dish Details"], app)
        let edit = app.buttons["detail-edit-cook"], rerank = app.buttons["detail-rerank"], share = app.buttons["detail-share-dish"]
        XCTAssertTrue(edit.exists && rerank.exists && share.exists)
        XCTAssertEqual(edit.frame.minY, rerank.frame.minY, accuracy: 2)
        XCTAssertEqual(edit.frame.minY, share.frame.minY, accuracy: 2)
        XCTAssertEqual(edit.frame.height, share.frame.height, accuracy: 2)
        capture("One-row Detail actions red", app)
        transition(rerank, to: app.buttons["Liked it"], app)
        XCTAssertTrue(app.buttons["It was fine"].exists && app.buttons["Didn't like it"].exists)
        capture("Fresh Re-rank initial reaction", app)
        transition(app.buttons["It was fine"], to: app.buttons["Skip"], app)
        tap(app.buttons["Skip"], app)
        XCTAssertTrue(app.buttons["Undo"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Undo"].isEnabled)
        tap(app.buttons["Undo"], app)
        XCTAssertFalse(app.buttons["Undo"].isEnabled)
        tap(app.buttons["Too Tough"], app)
        for _ in 0..<30 {
            if app.buttons["ranking-result-close"].waitForExistence(timeout: 1) { break }
            tap(app.buttons["comparison-choice-new"], app)
        }
        XCTAssertTrue(app.staticTexts["Your dish is ranked!"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["result-score"].exists && app.buttons["result-share-dish"].exists)
        XCTAssertFalse(app.buttons["Save Answers"].exists || app.buttons["Save Score"].exists)
        capture("Automatic Re-rank result", app)
        tap(app.buttons["ranking-result-close"], app)
        XCTAssertTrue(edit.waitForExistence(timeout: 15))
        tap(app.navigationBars.buttons.firstMatch, app)
        tap(app.buttons["Profile"], app)
        let top = app.buttons["profile-share-top-three"]
        XCTAssertTrue(top.waitForExistence(timeout: 15) && top.isEnabled)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "profile-entry-count").firstMatch.label,
                       "12 ranked entries", "Re-rank must not count as another entry in Profile")
        tap(top, app)
        XCTAssertTrue(app.cells.matching(identifier: "actionGroupCell").matching(NSPredicate(format: "label == 'Copy'")).firstMatch.waitForExistence(timeout: 15))
        capture("Profile current Top 3 native share", app)
    }
    @MainActor func testLockedLargeTypeRerankCancellationAndVersionThresholdCrossing() {
        let app = launch(9, large: true)
        transition(firstRow(app), to: app.navigationBars["Dish Details"], app)
        XCTAssertTrue(app.descendants(matching: .any)["dish-sharing-locked"].exists)
        let rerank = app.buttons["detail-rerank"]
        transition(rerank, to: app.buttons["Liked it"], app)
        tap(app.buttons["Cancel"], app)
        XCTAssertTrue(rerank.waitForExistence(timeout: 15))
        capture("Accessible locked action stack", app)
        transition(rerank, to: app.buttons["Liked it"], app)
        transition(app.buttons["Liked it"], to: app.buttons["Skip"], app)
        tap(app.buttons["Cancel"], app)
        XCTAssertTrue(rerank.waitForExistence(timeout: 15))
        tap(app.navigationBars.buttons.firstMatch, app)
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any)["score-unlock-banner"].label.contains("9 / 10"))
        tap(app.buttons["Profile"], app)
        XCTAssertFalse(app.buttons["profile-share-top-three"].isEnabled)
        let dishCountBefore = app.descendants(matching: .any).matching(identifier: "profile-dish-count").firstMatch.label
        tap(app.buttons["Rankings"], app)
        app.revealCreation(); tap(app.buttons["new-version"], app)
        let dish = app.buttons["choose-dish-Matzo Ball Soup"]
        transition(dish, to: app.buttons["Continue"], app)
        transition(app.buttons["Continue"], to: app.buttons["Liked it"], app)
        tap(app.buttons["Liked it"], app)
        for _ in 0..<30 {
            if app.buttons["ranking-result-close"].waitForExistence(timeout: 1) { break }
            tap(app.buttons["comparison-choice-new"], app)
        }
        XCTAssertTrue(app.staticTexts["Your scores are unlocked!"].waitForExistence(timeout: 15))
        capture("Second version crosses entry threshold large text", app)
        tap(app.buttons["ranking-result-close"], app)
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        tap(app.tabBars.buttons["Profile"], app)
        let entries = app.descendants(matching: .any).matching(identifier: "profile-entry-count").firstMatch
        XCTAssertTrue(entries.waitForExistence(timeout: 15))
        XCTAssertEqual(entries.label, "10 ranked entries")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "profile-dish-count").firstMatch.label,
                       dishCountBefore, "The tenth independently ranked version is not a new Dish")
        XCTAssertTrue(app.buttons["profile-share-top-three"].isEnabled)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "score-unlock-banner").firstMatch.exists)
        for rank in 1...3 {
            let food = app.descendants(matching: .any).matching(identifier: "profile-top-food-\(rank)").firstMatch
            XCTAssertTrue(food.exists)
            XCTAssertNotNil(food.label.range(of: "score [0-9]+\\.[0-9]", options: .regularExpression))
        }
        capture("Version unlock reaches integrated Profile", app)
    }
    @MainActor func testSearchAndDietaryFilterCanFindLowerMatchingVersionInEitherMode() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--discovery-fixture", "--test-light"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 20))
        let golden = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Golden sear'")).firstMatch
        XCTAssertFalse(golden.exists)
        transition(app.buttons["ranking-filter-dietary"], to: app.buttons["filters-done"], app)
        let kosher = app.buttons["filter-dietary-kosher"]
        tap(kosher, app)
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'Selected'"), object: kosher)
        if XCTWaiter.wait(for: [selected], timeout: 3) != .completed, kosher.value as? String != "Selected" {
            app.activate(); kosher.tap()
        }
        let confirmed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'Selected'"), object: kosher)
        XCTAssertEqual(XCTWaiter.wait(for: [confirmed], timeout: 10), .completed)
        tap(app.buttons["filters-done"], app)
        XCTAssertTrue(golden.waitForExistence(timeout: 10))
        XCTAssertTrue(golden.label.hasPrefix("Rank 2,") && golden.label.contains("score locked"))
        app.showAllVersions()
        XCTAssertTrue(golden.exists)
        tap(app.buttons["clear-filters"], app)
        tap(app.buttons["Top Version"], app)
        XCTAssertFalse(golden.exists)
        app.revealSearch()
        let field = app.rankingSearchField
        tap(field, app); field.typeText("Golden\n")
        XCTAssertTrue(golden.waitForExistence(timeout: 10))
        XCTAssertTrue(golden.label.hasPrefix("Rank 2,"))
        app.showAllVersions()
        XCTAssertTrue(golden.exists)
        capture("Lower matching version retains global rank in search", app)
    }

    @MainActor func testGenuineRerankLeaderKeepsIndividualPrimaryAndOffersUpdatedTopThree() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--sharing-fixture", "new-leader", "--test-light"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.staticTexts["Your dish is ranked!"].waitForExistence(timeout: 20))
        let preview = app.images["ranking-share-preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 15))
        XCTAssertTrue(preview.label.contains("NEW #1 DISH"))
        let individual = app.buttons["result-share-dish"], updated = app.buttons["result-share-updated-top-three"]
        XCTAssertTrue(individual.exists && updated.exists)
        XCTAssertLessThan(individual.frame.minY, updated.frame.minY)
        capture("Genuine Re-rank new leader with optional Top 3", app)
        tap(updated, app)
        XCTAssertTrue(app.cells.matching(identifier: "actionGroupCell").matching(NSPredicate(format: "label == 'Copy'")).firstMatch.waitForExistence(timeout: 15))
        capture("Updated normal Top 3 native image sheet", app)
    }

}
#endif
