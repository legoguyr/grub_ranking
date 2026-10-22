import XCTest

#if DEBUG

final class ProfileUITests: StayGrubbyUITestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(_ count: Int, appearance: String = "--test-light", large: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--score-unlock-fixture", "\(count == 2 ? 1 : count)", appearance, "--test-reduce-motion"]
        if large { app.launchArguments.append("--test-large-type") }
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 20))
        if count == 2 {
            // The shared fixture supports 0, 1, 9, 10 and 12. Create the second
            // entry through the real flow rather than changing shared fixtures.
            app.revealCreation()
            app.buttons["new-dish"].tap()
            let name = app.textFields["dish-name"]
            XCTAssertTrue(name.waitForExistence(timeout: 15))
            name.tap(); name.typeText("Roasted carrots\n")
            app.buttons["Continue"].tap()
            let liked = app.buttons["Liked it"]
            XCTAssertTrue(liked.waitForExistence(timeout: 15)); liked.tap()
            for _ in 0..<20 {
                if app.buttons["ranking-result-close"].waitForExistence(timeout: 1) { break }
                let choice = app.buttons["comparison-choice-new"]
                XCTAssertTrue(choice.waitForExistence(timeout: 10)); choice.tap()
            }
            let close = app.buttons["ranking-result-close"]
            XCTAssertTrue(close.waitForExistence(timeout: 15)); close.tap()
            XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        }
        openProfile(in: app)
        return app
    }

    @MainActor private func openProfile(in app: XCUIApplication) {
        let tab = app.tabBars.buttons["My Kitchen"]
        let identity = app.staticTexts["Your Kitchen"]
        tab.tap()
        // XCTest can miss a synthesized tab tap. Retry once only when the
        // Profile tab is demonstrably still unselected; require the destination.
        if !identity.waitForExistence(timeout: 5), !tab.isSelected {
            capture("Retry missed Profile tab tap", app: app)
            app.activate(); tab.tap()
        }
        XCTAssertTrue(identity.waitForExistence(timeout: 10))
    }

    @MainActor private func accountSettings(_ app: XCUIApplication) {
        app.buttons["settings-open"].tap()
        XCTAssertTrue(app.buttons["settings-sync"].waitForExistence(timeout: 8)); app.buttons["settings-sync"].tap()
        XCTAssertTrue(app.navigationBars["Account & Sync"].waitForExistence(timeout: 8))
    }
    @MainActor private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor private func countLabel(_ id: String, in app: XCUIApplication) -> String {
        let control = element(id, in: app)
        for _ in 0..<12 { if control.exists { break }; app.swipeUp() }
        XCTAssertTrue(control.exists)
        let value = control.label
        // Food leads My Kitchen now; counts remain available below it.
        for _ in 0..<12 { if app.staticTexts["Your Kitchen"].isHittable { break }; app.swipeDown() }
        return value
    }

    @MainActor private func reach(_ control: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(control.waitForExistence(timeout: 10))
        for _ in 0..<12 {
            if control.isHittable { return }
            app.swipeUp()
        }
        XCTFail("Unreachable Profile control: \(control.identifier)")
    }

    @MainActor private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    @MainActor func testEmptyProfileHasIntentionalContentLockedShareAndDevelopmentExit() {
        let app = launch(0)
        XCTAssertEqual(countLabel("profile-entry-count", in: app), "0 ranked entries")
        XCTAssertEqual(countLabel("profile-dish-count", in: app), "0 dishes ranked")
        XCTAssertTrue(element("profile-empty", in: app).exists)
        XCTAssertFalse(element("profile-top-food-1", in: app).exists)
        XCTAssertFalse(app.buttons["account-sign-out"].exists)
        XCTAssertFalse(app.buttons["development-verify-fresh-restore"].exists)
        capture("Profile empty light", app: app)
        let share = app.buttons["profile-share-top-three"]
        XCTAssertTrue(share.exists && !share.isEnabled)
        reach(share, in: app)
        capture("Profile empty sharing progress", app: app)
        let exit = app.buttons["development-exit"]
        reach(exit, in: app); exit.tap()
        XCTAssertTrue(app.buttons["account-sign-in-apple"].waitForExistence(timeout: 15))
    }

    @MainActor func testOneAndTwoEntriesNeedNoPhotosOrPlaceholderFoods() {
        for count in [1, 2] {
            let app = launch(count)
            XCTAssertEqual(countLabel("profile-entry-count", in: app), "\(count) ranked entries")
            XCTAssertTrue(element("profile-building-top-three", in: app).exists)
            for rank in 1...count {
                let row = element("profile-top-food-\(rank)", in: app)
                XCTAssertTrue(row.exists && row.label.contains("score locked"))
            }
            XCTAssertFalse(element("profile-top-food-\(count + 1)", in: app).exists)
            XCTAssertFalse(app.buttons["profile-share-top-three"].isEnabled)
            capture("Profile \(count) entries", app: app)
            app.terminate()
        }
    }

    @MainActor func testLockedDarkAccessibilityProfileCountsVersionsWithoutScoreLeaks() {
        let app = launch(9, appearance: "--test-dark", large: true)
        XCTAssertEqual(countLabel("profile-entry-count", in: app), "9 ranked entries")
        XCTAssertEqual(countLabel("profile-dish-count", in: app), "8 dishes ranked")
        capture("Profile dark accessibility identity", app: app)
        for rank in 1...3 {
            let row = element("profile-top-food-\(rank)", in: app)
            XCTAssertTrue(row.exists && row.label.contains("score locked"))
            reach(row, in: app)
            capture("Profile dark accessibility rank \(rank)", app: app)
        }
        let share = app.buttons["profile-share-top-three"]
        reach(share, in: app)
        XCTAssertFalse(share.isEnabled)
        XCTAssertTrue(element("score-unlock-banner", in: app).label.contains("9 / 10"))
        capture("Profile dark accessibility locked sharing", app: app)
    }

    @MainActor func testUnlockedProfileKeepsPermanentNativeTopThreeSharing() {
        let app = launch(10, appearance: "--test-dark")
        XCTAssertEqual(countLabel("profile-entry-count", in: app), "10 ranked entries")
        XCTAssertEqual(countLabel("profile-dish-count", in: app), "9 dishes ranked")
        for rank in 1...3 {
            let label = element("profile-top-food-\(rank)", in: app).label
            XCTAssertFalse(label.contains("score locked"))
            XCTAssertNotNil(label.range(of: "score [0-9]+\\.[0-9]", options: .regularExpression))
        }
        capture("Profile unlocked dark", app: app)
        XCTAssertFalse(element("score-unlock-banner", in: app).exists)
        let share = app.buttons["profile-share-top-three"]
        reach(share, in: app); XCTAssertTrue(share.isEnabled)
        capture("Profile unlocked permanent share", app: app)
        share.tap()
        XCTAssertTrue(app.cells.matching(identifier: "actionGroupCell")
            .matching(NSPredicate(format: "label == 'Copy'")).firstMatch.waitForExistence(timeout: 15))
        capture("Profile native Top 3 share sheet", app: app)
    }

    @MainActor func testAccountDisclosureSyncRetrySafeRestoreAndSignOut() {
        for pending in [true, false] {
            let app = XCUIApplication()
            app.launchArguments = ["--ui-test-store", UUID().uuidString, "--profile-account-review",
                                   pending ? "--profile-sync-pending" : "--profile-sync-current",
                                   pending ? "--test-light" : "--test-dark", "--test-reduce-motion"]
            if !pending { app.launchArguments.append("--test-large-type") }
            app.launchWithReviewOptions()
            XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 20))
            openProfile(in: app); accountSettings(app)
            let signOut = app.buttons["account-sign-out"]
            XCTAssertTrue(signOut.waitForExistence(timeout: 10))
            let account = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Account ID: '")).firstMatch
            XCTAssertTrue(account.exists)
            let accountID = String(account.label.dropFirst("Account ID: ".count))
            XCTAssertNotNil(UUID(uuidString: accountID))
            XCTAssertTrue(app.navigationBars["Account & Sync"].exists)
            if pending {
                let retry = app.buttons["Retry sync"]
                reach(retry, in: app)
                XCTAssertGreaterThanOrEqual(retry.frame.height, 43.9)
                XCTAssertTrue(app.staticTexts["Saved on this device · Sync pending"].exists)
                let status = app.staticTexts["profile-review-status"]
                let before = status.label
                retry.tap()
                let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", before), object: status)
                XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 10), .completed)
            } else {
                XCTAssertTrue(app.staticTexts["Cooking data up to date"].waitForExistence(timeout: 10))
                XCTAssertFalse(app.buttons["Retry sync"].exists)
            }
            let restore = app.buttons["development-verify-fresh-restore"]
            reach(restore, in: app)
            XCTAssertGreaterThanOrEqual(restore.frame.height, 43.9)
            capture("Profile account expanded \(pending ? "light" : "dark")", app: app)
            restore.tap()
            XCTAssertTrue(app.staticTexts["Couldn't verify fresh restore. Your main local store was not changed."].waitForExistence(timeout: 10))
            reach(signOut, in: app)
            XCTAssertGreaterThanOrEqual(signOut.frame.height, 43.9)
            signOut.tap()
            XCTAssertTrue(app.staticTexts["Review signed out"].waitForExistence(timeout: 10))
            XCTAssertFalse(app.buttons["account-sign-out"].exists)
            app.terminate()
        }
    }

    @MainActor func testPrivacyAndAccountDeletionRequireDeliberateConfirmation() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--profile-account-review",
                               "--profile-sync-current", "--test-light", "--test-reduce-motion"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 20)); openProfile(in: app); accountSettings(app)
        let privacy = app.buttons["privacy-policy-open"]
        reach(privacy, in: app); privacy.tap()
        XCTAssertTrue(app.navigationBars["Privacy Policy"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["privacy-policy-public-link"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'private cooking journal' ")).firstMatch.exists)
        app.buttons["Done"].tap()

        let start = app.buttons["account-delete-start"]
        reach(start, in: app); start.tap()
        XCTAssertTrue(app.alerts["Permanently delete your account?"].waitForExistence(timeout: 10))
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Account & Sync"].exists)

        start.tap(); app.alerts.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Permanently delete account"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["account-delete-apple"].exists)
        app.buttons["account-delete-cancel"].tap()
        XCTAssertTrue(app.navigationBars["Account & Sync"].waitForExistence(timeout: 10))
    }

}
#endif

#if !DEBUG
final class ProfileReleaseIsolationUITests: StayGrubbyUITestCase {
    @MainActor func testProfileAccountReviewFlagsCannotBypassReleaseGate() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--profile-account-review",
                               "--profile-sync-pending", "--score-unlock-fixture", "10"]
        app.launch()
        XCTAssertTrue(app.buttons["account-sign-in-apple"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.tabBars.buttons["My Kitchen"].exists)
        XCTAssertFalse(app.staticTexts["profile-review-status"].exists)
        XCTAssertFalse(app.buttons["development-exit"].exists)
        XCTAssertFalse(app.buttons["development-verify-fresh-restore"].exists)
    }
}
#endif
