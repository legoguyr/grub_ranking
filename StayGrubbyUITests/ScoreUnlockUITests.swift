#if DEBUG
import XCTest

final class ScoreUnlockUITests: StayGrubbyUITestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor private func row(_ name: String, _ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS %@", name)).firstMatch
    }
    @MainActor private func tap(_ element: XCUIElement, _ app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 15))
        for _ in 0..<10 { if element.isHittable { element.tap(); return }; app.swipeUp() }
        XCTFail("Unreachable control: \(element)")
    }
    @MainActor private func open(_ name: String, _ app: XCUIApplication) {
        for _ in 0..<3 {
            tap(row(name, app), app)
            if app.navigationBars["Dish Details"].waitForExistence(timeout: 5) { return }
            app.activate()
        }
        XCTFail("Missing Detail destination")
    }
    @MainActor private func capture(_ name: String, _ app: XCUIApplication) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }
    @MainActor private func add(_ name: String, _ app: XCUIApplication) {
        app.revealCreation()
        let create = app.buttons["new-dish"], field = app.textFields["dish-name"]
        tap(create, app)
        // The complete-suite failure hierarchy still showed the creation menu:
        // XCTest's synthesized tap had not opened the form. Retry only while
        // that same control remains available, and still require the form.
        if !field.waitForExistence(timeout: 5), create.exists && create.isHittable {
            capture("Retry missed New Dish transition", app)
            app.activate(); create.tap()
        }
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        tap(field, app); field.typeText(name + "\n")
        tap(app.buttons["Continue"], app); tap(app.buttons["Liked it"], app)
        for _ in 0..<20 {
            if app.buttons["ranking-result-close"].waitForExistence(timeout: 1) { break }
            tap(app.buttons["comparison-choice-new"], app)
        }
        XCTAssertTrue(app.buttons["ranking-result-close"].waitForExistence(timeout: 15))
    }

    @MainActor func testRepresentativeCountsAndAccessibleRows() {
        XCUIDevice.shared.orientation = .portrait
        for count in [0, 1, 9, 10, 12] {
            let app = XCUIApplication()
            app.launchArguments = ["--ui-test-store", UUID().uuidString, "--score-unlock-fixture", "\(count)", count.isMultiple(of: 2) ? "--test-light" : "--test-dark"]
            if count == 1 { app.launchArguments += ["--test-large-type", "--test-reduce-motion"] }
            app.launchWithReviewOptions()
            XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 20))
            let banner = app.descendants(matching: .any)["score-unlock-banner"]
            if count < 10 {
                XCTAssertTrue(banner.waitForExistence(timeout: 10))
                XCTAssertTrue(banner.label.contains("\(count) / 10 dishes & versions ranked"))
                XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Score '")).firstMatch.exists)
            } else { XCTAssertFalse(banner.exists) }
            if count > 0 {
                let ranked = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-'")).firstMatch
                XCTAssertTrue(ranked.exists)
                XCTAssertEqual(ranked.label.contains("score locked"), count < 10)
            }
            capture("Score visibility \(count)", app)
            if count == 9 {
                let before = banner.frame.minY
                app.swipeUp()
                XCTAssertLessThan(banner.frame.minY, before, "The progress banner must scroll with the ranking")
                XCTAssertTrue(app.rankingHeader.exists)
            }
            app.terminate()
        }
    }

    @MainActor func testLockedDetailAndCompletionExposePositionsWithoutScoresOrSharePreviews() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--score-unlock-fixture", "1", "--test-light"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 20))
        open("Matzo Ball Soup", app)
        XCTAssertTrue(app.images.matching(identifier: "score-locked").firstMatch.exists)
        XCTAssertFalse(app.buttons["detail-share-dish"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["dish-sharing-locked"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Score '")).firstMatch.exists)
        capture("Locked Detail and versions", app)
        tap(app.navigationBars.buttons.firstMatch, app)
        add("Locked baked good", app)
        XCTAssertTrue(app.staticTexts["Your dish is ranked!"].exists)
        XCTAssertTrue(app.staticTexts["result-rank"].exists)
        XCTAssertFalse(app.staticTexts["result-score"].exists)
        XCTAssertFalse(app.images["ranking-share-preview"].exists)
        XCTAssertFalse(app.buttons["result-share-dish"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Score '")).firstMatch.exists)
        capture("Locked completion", app)
    }

    @MainActor func testFirstUnlockNativeTopThreeRelaunchRelockAndNoRepeat() {
        let app = XCUIApplication(), store = UUID().uuidString
        app.launchArguments = ["--ui-test-store", store, "--score-unlock-fixture", "9", "--test-light"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 20))
        add("Unlock tenth dish", app)
        XCTAssertTrue(app.staticTexts["Your scores are unlocked!"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.images["top-three-preview"].waitForExistence(timeout: 15))
        capture("First score unlock milestone", app)
        tap(app.buttons["share-top-three"], app)
        let copy = app.cells.matching(identifier: "actionGroupCell").matching(NSPredicate(format: "label == 'Copy'")).firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 15)); capture("Native Top 3 image sharing", app)
        tap(app.buttons["Close"], app); XCTAssertTrue(copy.waitForNonExistence(timeout: 10))
        tap(app.buttons["ranking-result-close"], app)
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["score-unlock-banner"].exists)
        app.terminate(); app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 20))
        XCTAssertFalse(app.staticTexts["Your scores are unlocked!"].exists)
        open("Unlock tenth dish", app)
        XCTAssertTrue(app.buttons["detail-share-dish"].exists)
        tap(app.buttons["cook-more-actions"], app); tap(app.buttons["Delete Cook"], app)
        let confirm = app.alerts.buttons["Delete Cook"]
        tap(confirm, app)
        // The failure hierarchy/recording retained this exact confirmation
        // alert after the synthesized tap. Require dismissal, with one bounded
        // retry, before asserting relocking and persisted deletion.
        if !confirm.waitForNonExistence(timeout: 5), confirm.exists && confirm.isHittable {
            app.activate(); confirm.tap()
        }
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any)["score-unlock-banner"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["score-unlock-banner"].label.contains("9 / 10"))
        app.terminate(); app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 20))
        add("Return tenth dish", app)
        XCTAssertFalse(app.staticTexts["Your scores are unlocked!"].exists)
        XCTAssertTrue(app.staticTexts["Your dish is ranked!"].exists)
        XCTAssertTrue(app.staticTexts["result-score"].exists)
        XCTAssertTrue(app.buttons["result-share-dish"].exists)
        capture("Scores reveal again without repeating milestone", app)
    }

    @MainActor func testDarkLargeTypeMilestoneActionsRemainReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--score-unlock-fixture", "9",
                               "--test-dark", "--test-large-type", "--test-reduce-motion"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 20))
        add("Large text tenth dish", app)
        XCTAssertTrue(app.staticTexts["Your scores are unlocked!"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.images["top-three-preview"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["share-top-three"].isHittable)
        XCTAssertTrue(app.buttons["ranking-result-close"].isHittable)
        capture("Dark large-text milestone", app)
        tap(app.buttons["ranking-result-close"], app)
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        XCTAssertFalse(app.descendants(matching: .any)["score-unlock-banner"].exists)
    }
}
#endif
