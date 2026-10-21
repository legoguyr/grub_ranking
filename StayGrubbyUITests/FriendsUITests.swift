import XCTest

final class FriendsUITests: StayGrubbyUITestCase {
    @MainActor private func launch(_ extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready"] + extra
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15)); app.tabBars.buttons["Profile"].tap()
        let friends = app.buttons["friends-open"]
        XCTAssertTrue(friends.waitForExistence(timeout: 10)); friends.tap()
        XCTAssertTrue(app.navigationBars["Friends"].waitForExistence(timeout: 5))
        return app
    }
    @MainActor private func section(_ title: String, in app: XCUIApplication) {
        app.buttons["friends-section"].tap(); app.buttons[title].firstMatch.tap()
    }
    @MainActor func testFriendsRequestsAndBlockingUseMinimalProfiles() throws {
        let app = launch(["--test-dark"])
        let friend = app.buttons["friend-person-friend_cook"]
        XCTAssertTrue(friend.waitForExistence(timeout: 5)); friend.tap()
        XCTAssertTrue(app.staticTexts["@friend_cook"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Your Top 3"].exists)
        XCTAssertFalse(app.buttons["Edit Cook"].exists)
        app.buttons["Remove Friend"].tap(); app.buttons["Remove Friendship"].tap()
        XCTAssertTrue(app.navigationBars["Friends"].waitForExistence(timeout: 5))
        XCTAssertFalse(friend.exists)
        section("Incoming Requests", in: app)
        let incoming = app.buttons["friend-person-incoming_cook"]
        XCTAssertTrue(incoming.waitForExistence(timeout: 5)); incoming.tap()
        app.buttons["friend-action-accept"].tap()
        XCTAssertTrue(app.buttons["Remove Friend"].waitForExistence(timeout: 5))
        app.buttons["Block"].tap(); app.buttons["Block Person"].tap()
        XCTAssertTrue(app.navigationBars["Friends"].waitForExistence(timeout: 5))
        section("Blocked Users", in: app)
        let blocked = app.buttons["friend-person-incoming_cook"]
        XCTAssertTrue(blocked.waitForExistence(timeout: 5)); blocked.tap()
        app.buttons["friend-action-unblock"].tap()
        XCTAssertTrue(app.navigationBars["Friends"].waitForExistence(timeout: 5))
        XCTAssertFalse(blocked.exists)
        section("Outgoing Requests", in: app)
        let outgoing = app.buttons["friend-person-outgoing_cook"]
        XCTAssertTrue(outgoing.waitForExistence(timeout: 5)); outgoing.tap(); app.buttons["friend-action-cancel"].tap()
        XCTAssertTrue(app.navigationBars["Friends"].waitForExistence(timeout: 5)); XCTAssertFalse(outgoing.exists)
    }
    @MainActor func testSearchAtLightAccessibilitySize() throws {
        let app = launch(["--test-light", "--test-large-type"])
        section("Find Friends", in: app)
        let field = app.textFields["friends-search"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap()
        let focus = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field)
        XCTAssertEqual(XCTWaiter.wait(for: [focus], timeout: 5), .completed)
        field.typeText("new_cook\n")
        let person = app.buttons["friend-person-new_cook"]
        XCTAssertTrue(person.waitForExistence(timeout: 5)); person.tap()
        XCTAssertTrue(app.buttons["friend-action-request"].waitForExistence(timeout: 5)); app.buttons["friend-action-request"].tap()
        XCTAssertTrue(app.buttons["friend-action-cancel"].waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Friends light accessibility size"; shot.lifetime = .keepAlways; add(shot)
    }
    @MainActor func testPrivateProfileReportFlow() throws {
        let app = launch(["--test-dark"])
        let friend = app.buttons["friend-person-friend_cook"]
        XCTAssertTrue(friend.waitForExistence(timeout: 5)); friend.tap()
        let report = app.buttons["social-report-profile"]
        XCTAssertTrue(report.waitForExistence(timeout: 5)); report.tap()
        XCTAssertTrue(app.buttons["social-report-send"].waitForExistence(timeout: 5))
        app.buttons["social-report-send"].tap()
        XCTAssertTrue(app.alerts["Report sent"].waitForExistence(timeout: 5)); app.alerts.buttons["Done"].tap()
    }

}
