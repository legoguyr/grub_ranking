#if DEBUG
import XCTest

final class SharingUITests: StayGrubbyUITestCase {
    @MainActor func testResultShowsOneCardPrivateRankAndDismissesOnce() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--sharing-fixture", "result", "--test-light"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.staticTexts["Your dish is ranked!"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.images["ranking-share-preview"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.images["ranking-share-preview"].label.contains("Smoky Sunday"))
        XCTAssertTrue(app.images["ranking-share-preview"].label.contains("BEST VERSION YET"))
        XCTAssertTrue(app.staticTexts["result-rank"].exists)
        XCTAssertTrue(app.staticTexts["result-rank"].isHittable)
        XCTAssertTrue(app.buttons["ranking-result-close"].isHittable)
        let share = app.buttons["result-share-dish"]
        for _ in 0..<6 {
            if share.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(share.isHittable)
        share.tap()
        let copy = app.cells.matching(identifier: "actionGroupCell")
            .matching(NSPredicate(format: "label == %@", "Copy")).firstMatch
        // Failure hierarchy retained the result and Share Dish, with no sheet
        // or render alert: the synthesized tap was missed. Retry once only
        // while that same control remains available, then require native UI.
        if !copy.waitForExistence(timeout: 5), share.exists && share.isHittable && app.alerts.count == 0 {
            app.activate(); share.tap()
        }
        XCTAssertTrue(copy.waitForExistence(timeout: 15))
        let closeShare = app.buttons["Close"]
        XCTAssertTrue(closeShare.exists); closeShare.tap()
        XCTAssertTrue(copy.waitForNonExistence(timeout: 10))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Ranking celebration"; attachment.lifetime = .keepAlways; add(attachment)
        let done = app.buttons["ranking-result-close"]
        for _ in 0..<4 { if done.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(done.isHittable); done.tap()
        XCTAssertTrue(app.staticTexts["review-result-dismissed"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Your dish is ranked!"].exists)
    }

    @MainActor func testPhotoAndCompactFallbackExportDimensionsInPortrait() {
        let app = XCUIApplication()
        for (mode, expected) in [("photo", "1080 × 1350"), ("fallback", "1080 × 1080"), ("plain", "1080 × 1350"), ("long", "1080 × 1350")] {
            app.launchArguments = ["--ui-test-store", UUID().uuidString, "--sharing-fixture", mode, "--test-dark"]
            app.launchWithReviewOptions()
            XCTAssertTrue(app.images["sharing-review-preview"].waitForExistence(timeout: 20))
            XCTAssertEqual(app.staticTexts["sharing-review-dimensions"].label, expected)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Share card \(mode)"; attachment.lifetime = .keepAlways; add(attachment)
            app.terminate()
        }
    }

    @MainActor func testDetailShareEntryAndLargeTypeResultControlsRemainReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--sharing-fixture", "detail", "--test-light"]
        app.launchWithReviewOptions()
        let share = app.buttons["detail-share-dish"]
        XCTAssertTrue(share.waitForExistence(timeout: 20))
        for _ in 0..<4 { if share.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(share.isHittable)
        share.tap()
        // iOS 26 exposes native share actions as actionGroupCell elements.
        // The failure hierarchy proved the sheet was already open; a Button
        // query cannot locate this system collection cell.
        let copy = app.cells.matching(identifier: "actionGroupCell")
            .matching(NSPredicate(format: "label == %@", "Copy")).firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 15))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Native image share sheet"; attachment.lifetime = .keepAlways; add(attachment)
        app.terminate()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--sharing-fixture", "result", "--test-dark", "--test-large-type", "--test-reduce-motion"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.staticTexts["Your dish is ranked!"].waitForExistence(timeout: 20))
        let done = app.buttons["ranking-result-close"]
        for _ in 0..<10 { if done.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(done.isHittable)
        let large = XCTAttachment(screenshot: app.screenshot())
        large.name = "Portrait accessible celebration"; large.lifetime = .keepAlways; add(large)
        done.tap()
        XCTAssertTrue(app.staticTexts["review-result-dismissed"].waitForExistence(timeout: 10))
    }
}
#endif
