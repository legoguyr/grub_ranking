import XCTest

final class SocialInteractionUITests: StayGrubbyUITestCase {
    @MainActor func testLikeUnlikeAndCommentCreationDeletion() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--social-review-trace", "--social-review-feed", "--test-dark"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15)); app.tabBars.buttons["Grub List"].tap()
        let like = app.buttons["social-like-20000000-0000-0000-0000-000000000001"]
        for _ in 0..<3 { if like.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(like.waitForExistence(timeout: 8)); like.tap()
        let liked = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Remove Hands, unlike post' AND value == '1 Hands'"), object: like)
        XCTAssertEqual(XCTWaiter.wait(for: [liked], timeout: 5), .completed)
        like.tap()
        let unliked = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Give Hands, like this cook' AND value == '0 Hands'"), object: like)
        XCTAssertEqual(XCTWaiter.wait(for: [unliked], timeout: 5), .completed)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Friends Feed dark"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["social-comments-20000000-0000-0000-0000-000000000001"].tap()
        let body = app.textFields["comment-body"]
        XCTAssertTrue(body.waitForExistence(timeout: 5)); body.tap(); body.typeText("Looks delicious!")
        let send = app.buttons["comment-send"]
        let deletion = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'comment-delete-'")).firstMatch
        if !send.isHittable { app.swipeUp() }; send.tap()
        XCTAssertTrue(deletion.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Looks delicious!"].exists)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        deletion.tap()
        let confirm = app.sheets["Delete this comment?"].buttons["Delete comment"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.press(forDuration: 0.2)
        XCTAssertTrue(app.staticTexts["No comments yet. Start a conversation."].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(deletion.waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Looks delicious!"].exists)
        app.navigationBars["Comments"].buttons["Done"].tap()
        XCTAssertTrue(like.waitForExistence(timeout: 5))
        let comments = app.buttons["social-comments-20000000-0000-0000-0000-000000000001"]
        let emptyCount = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '0 comments'"), object: comments)
        XCTAssertEqual(XCTWaiter.wait(for: [emptyCount], timeout: 5), .completed)
        comments.tap()
        XCTAssertTrue(app.staticTexts["No comments yet. Start a conversation."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Looks delicious!"].exists)
    }
}
