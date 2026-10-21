import XCTest

final class SocialInteractionUITests: StayGrubbyUITestCase {
    @MainActor func testLikeUnlikeAndCommentCreationDeletion() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--social-review-trace", "--social-review-feed", "--test-dark"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15)); app.tabBars.buttons["Feed"].tap()
        let like = app.buttons["social-like-20000000-0000-0000-0000-000000000001"]
        for _ in 0..<3 { if like.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(like.waitForExistence(timeout: 8)); like.tap()
        let liked = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Unlike post' AND value == '1 likes'"), object: like)
        XCTAssertEqual(XCTWaiter.wait(for: [liked], timeout: 5), .completed)
        like.tap()
        let unliked = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Like post' AND value == '0 likes'"), object: like)
        XCTAssertEqual(XCTWaiter.wait(for: [unliked], timeout: 5), .completed)
        app.buttons["social-comments-20000000-0000-0000-0000-000000000001"].tap()
        let body = app.textFields["comment-body"]
        XCTAssertTrue(body.waitForExistence(timeout: 5)); body.tap(); body.typeText("Looks delicious!")
        let send = app.buttons["comment-send"]
        let deletion = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'comment-delete-'")).firstMatch
        if !send.isHittable { app.swipeUp() }; send.tap()
        XCTAssertTrue(deletion.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Looks delicious!"].exists)
        deletion.tap(); app.sheets["Delete this comment?"].buttons["Delete comment"].tap()
        app.swipeDown()
        XCTAssertTrue(app.staticTexts["No comments yet. Start a conversation."].waitForExistence(timeout: 5), app.debugDescription)
        app.navigationBars["Comments"].buttons["Done"].tap()
        XCTAssertTrue(like.waitForExistence(timeout: 5))
    }
}
