#if DEBUG
import XCTest

final class SharingPresentationUITests: StayGrubbyUITestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func tap(_ element: XCUIElement, _ app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 15))
        for _ in 0..<10 {
            if element.isHittable { element.tap(); return }
            app.swipeUp()
        }
        XCTFail("Unreachable sharing control: \(element.identifier)")
    }

    @MainActor func testResultIdentityAchievementAndPreviewPrivacyInBothAppearances() {
        for appearance in ["--test-light", "--test-dark"] {
            let app = XCUIApplication()
            app.launchArguments = ["--ui-test-store", UUID().uuidString, "--sharing-fixture", "result", appearance,
                "--test-large-type", "--test-reduce-motion"]
            app.launchWithReviewOptions()
            XCTAssertTrue(app.staticTexts["result-dish-title"].waitForExistence(timeout: 20))
            XCTAssertFalse(app.staticTexts["result-dish-title"].label.isEmpty)
            XCTAssertTrue(app.staticTexts["result-version"].label.contains("Smoky Sunday"))
            XCTAssertTrue(app.descendants(matching: .any)["result-achievement"].exists)
            XCTAssertTrue(app.staticTexts["result-rank-privacy"].label.contains("stay in the app"))
            let preview = app.images["ranking-share-preview"]
            XCTAssertTrue(preview.waitForExistence(timeout: 15))
            XCTAssertTrue(preview.label.contains("BEST VERSION YET"))
            XCTAssertFalse(preview.label.contains("overall") || preview.label.contains("spots"))
            XCTAssertTrue(app.buttons["result-share-dish"].isHittable)
            XCTAssertTrue(app.buttons["ranking-result-close"].isHittable)
            XCTAssertFalse(app.buttons["result-share-updated-top-three"].exists)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Sharing result accessible \(appearance)"; screenshot.lifetime = .keepAlways; add(screenshot)
            tap(app.buttons["ranking-result-close"], app)
            XCTAssertTrue(app.staticTexts["review-result-dismissed"].waitForExistence(timeout: 10))
            app.terminate()
        }
    }

    @MainActor func testNativeSaveImageShowsFeedbackAndCancellationStaysQuiet() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--sharing-fixture", "result", "--test-light"]
        app.launchWithReviewOptions()
        tap(app.buttons["result-share-dish"], app)
        let save = app.cells.matching(identifier: "actionGroupCell")
            .matching(NSPredicate(format: "label == 'Save Image'")).firstMatch
        tap(save, app)
        // iOS owns add-only authorization; the app makes no Photos API request.
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = system.alerts.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Allow' OR label == 'OK'")).firstMatch
        if allow.waitForExistence(timeout: 3) { allow.tap() }
        XCTAssertTrue(app.alerts["Image saved"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.alerts.staticTexts["Your #stayGRUBBY card was saved to Photos."].exists)
        tap(app.alerts.buttons["OK"], app)
        tap(app.buttons["result-share-dish"], app)
        tap(app.buttons["Close"], app)
        XCTAssertTrue(app.buttons["result-share-dish"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.alerts.count, 0)
        XCTAssertFalse(app.staticTexts["review-result-dismissed"].exists)
    }

    @MainActor func testPreviewFailureRetryPreservesSavedScoreAndPosition() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--sharing-fixture", "result",
            "--sharing-preview-fails-once", "--test-dark", "--test-large-type", "--test-reduce-motion"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.staticTexts["result-score"].waitForExistence(timeout: 20))
        let score = app.staticTexts["result-score"].label, rank = app.staticTexts["result-rank"].label
        let retry = app.buttons["share-preview-retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 15))
        XCTAssertFalse(app.images["ranking-share-preview"].exists)
        // iOS can report this offscreen button as hittable behind the pinned
        // actions. Require its full frame above Share Dish before tapping.
        for _ in 0..<8 {
            if retry.isHittable && retry.frame.maxY < app.buttons["result-share-dish"].frame.minY { break }
            app.swipeUp()
        }
        XCTAssertTrue(retry.isHittable)
        XCTAssertLessThan(retry.frame.maxY, app.buttons["result-share-dish"].frame.minY)
        let failure = XCTAttachment(screenshot: app.screenshot())
        failure.name = "Recoverable share preview failure"; failure.lifetime = .keepAlways; add(failure)
        tap(retry, app)
        XCTAssertTrue(app.images["ranking-share-preview"].waitForExistence(timeout: 15))
        XCTAssertFalse(retry.exists)
        XCTAssertEqual(app.staticTexts["result-score"].label, score)
        XCTAssertEqual(app.staticTexts["result-rank"].label, rank)
        let preview = app.images["ranking-share-preview"]
        for _ in 0..<8 {
            if preview.frame.maxY < app.buttons["result-share-dish"].frame.minY { break }
            app.swipeUp()
        }
        XCTAssertLessThan(preview.frame.maxY, app.buttons["result-share-dish"].frame.minY)
        let recovered = XCTAttachment(screenshot: app.screenshot())
        recovered.name = "Share preview recovered without saving again"; recovered.lifetime = .keepAlways; add(recovered)
        XCTAssertTrue(app.buttons["result-share-dish"].isHittable)
        tap(app.buttons["ranking-result-close"], app)
        XCTAssertTrue(app.staticTexts["review-result-dismissed"].waitForExistence(timeout: 10))
    }

    @MainActor func testSaveFailureFeedbackNeverClaimsSuccess() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--sharing-fixture", "result",
            "--sharing-save-failure-review", "--test-light"]
        app.launchWithReviewOptions()
        tap(app.buttons["review-save-failure"], app)
        XCTAssertTrue(app.alerts["Couldn’t save image"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.alerts["Image saved"].exists)
        XCTAssertTrue(app.alerts.staticTexts["Your card wasn’t saved to Photos. Try Save Image again from the share sheet."].exists)
        let failure = XCTAttachment(screenshot: app.screenshot())
        failure.name = "Save Image failure feedback"; failure.lifetime = .keepAlways; add(failure)
        tap(app.alerts.buttons["OK"], app)
        XCTAssertTrue(app.buttons["review-save-failure"].exists)
    }

    @MainActor func testLockedRerankKeepsIdentityAndNormalCompletionWithoutNumericalLeakage() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--score-unlock-fixture", "1", "--test-dark",
            "--test-large-type", "--test-reduce-motion"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 20))
        tap(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-'")).firstMatch, app)
        tap(app.buttons["detail-rerank"], app)
        tap(app.buttons["Liked it"], app)
        XCTAssertTrue(app.staticTexts["Your dish is ranked!"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["result-dish-title"].label, "Matzo Ball Soup")
        XCTAssertTrue(app.staticTexts["result-rank"].exists)
        XCTAssertFalse(app.staticTexts["result-score"].exists)
        XCTAssertFalse(app.images["ranking-share-preview"].exists)
        XCTAssertFalse(app.buttons["result-share-dish"].exists)
        XCTAssertFalse(app.buttons["result-share-updated-top-three"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["dish-sharing-locked"].exists)
        XCTAssertFalse(app.buttons["Save Score"].exists || app.buttons["Save Answers"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Locked result identity and private position"; screenshot.lifetime = .keepAlways; add(screenshot)
        tap(app.buttons["ranking-result-close"], app)
        XCTAssertTrue(app.buttons["detail-rerank"].waitForExistence(timeout: 10))
    }
}
#endif
