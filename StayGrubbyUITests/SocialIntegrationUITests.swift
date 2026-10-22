import XCTest

final class SocialIntegrationUITests: StayGrubbyUITestCase {
    @MainActor func testExplicitPostDeletionPreservesPrivateCookAcrossRelaunch() throws {
        continueAfterFailure = false
        let app = XCUIApplication(), store = UUID().uuidString
        app.launchArguments = ["--ui-test-store", store, "--social-review", "--social-review-ready", "--test-light"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.revealCreation(); app.buttons["new-dish"].tap()
        let name = app.textFields["dish-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Integrated Private Soup")
        app.buttons["Continue"].tap(); app.buttons["Liked it"].tap()
        XCTAssertTrue(app.buttons["share-with-friends"].waitForExistence(timeout: 15)); app.buttons["share-with-friends"].tap()
        XCTAssertTrue(app.staticTexts["social-share-score-locked"].waitForExistence(timeout: 5))
        app.buttons["social-share-publish"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "social-share-success").firstMatch.waitForExistence(timeout: 8)); app.buttons["social-share-done"].tap()
        XCTAssertTrue(app.navigationBars["Share with Sous Chefs"].waitForNonExistence(timeout: 8), app.debugDescription)
        app.buttons["ranking-result-close"].tap()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 8))
        app.tabBars.buttons["My Kitchen"].tap()
        let post = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'profile-post-'")).firstMatch
        XCTAssertTrue(post.waitForExistence(timeout: 8)); post.tap()
        let actions = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'post-actions-'")).firstMatch
        XCTAssertTrue(actions.waitForExistence(timeout: 8)); actions.tap()
        let deletion = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'feed-delete-'")).firstMatch
        for _ in 0..<3 { if deletion.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(deletion.waitForExistence(timeout: 5)); deletion.tap()
        app.sheets["Delete shared post?"].buttons["Delete shared post"].tap()
        XCTAssertTrue(app.staticTexts["Post unavailable"].waitForExistence(timeout: 8), app.debugDescription)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["profile-posts-empty"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Grub Rank"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Integrated Private Soup'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5)); XCTAssertTrue(row.label.contains("score locked"))
        app.terminate(); app.launchWithReviewOptions()
        XCTAssertTrue(row.waitForExistence(timeout: 15)); XCTAssertTrue(row.label.contains("score locked"))
    }
    @MainActor func testCommentReportingAtLightAccessibilitySize() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--social-review-feed", "--social-review-comment", "--test-light", "--test-large-type"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15)); selectFeed(app)
        let comments = app.buttons["social-comments-20000000-0000-0000-0000-000000000001"]
        for _ in 0..<4 { if comments.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(comments.waitForExistence(timeout: 5)); comments.tap()
        let report = app.buttons["social-report-comment"]
        XCTAssertTrue(report.waitForExistence(timeout: 8)); report.tap()
        XCTAssertTrue(app.navigationBars["Report comment"].waitForExistence(timeout: 5), app.debugDescription)
        let send = app.buttons["social-report-send"]
        for _ in 0..<4 { if send.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(send.waitForExistence(timeout: 5), app.debugDescription); send.tap()
        XCTAssertTrue(app.alerts["Report sent"].waitForExistence(timeout: 5)); app.alerts.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Report comment"].waitForNonExistence(timeout: 8), app.debugDescription)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Feed after light accessibility comment report"; shot.lifetime = .keepAlways; add(shot)
        XCTAssertFalse(app.buttons["Edit Cook"].exists)
    }
    @MainActor private func selectFeed(_ app: XCUIApplication) {
        let feed = app.tabBars.buttons["Grub List"]
        for _ in 0..<3 {
            feed.tap()
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: feed)
            if XCTWaiter.wait(for: [selected], timeout: 3) == .completed { break }
        }
        XCTAssertTrue(feed.isSelected, app.debugDescription)
    }

}
