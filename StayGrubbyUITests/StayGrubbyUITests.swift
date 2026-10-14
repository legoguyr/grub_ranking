import XCTest

final class StayGrubbyUITests: StayGrubbyUITestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testLaunchesDirectlyIntoSingleCookingRanking() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString]
        app.launchWithReviewOptions()

        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["creation-toggle"].exists)
        XCTAssertFalse(app.buttons["new-dish"].exists)
        app.revealCreation()
        XCTAssertTrue(app.buttons["new-dish"].exists)
        XCTAssertTrue(app.buttons["new-version"].exists)
        XCTAssertFalse(app.buttons["my-cooking"].exists)
        XCTAssertFalse(app.buttons["New Ranking"].exists)
        XCTAssertFalse(app.staticTexts["My Rankings"].exists)
    }

    @MainActor
    func testComparisonSquaresStaySymmetricalForEveryPhotoCombination() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString,
                               "--comparison-fixture", "11", "--test-dark"]
        app.launchWithReviewOptions()

        let next = app.buttons["comparison-fixture-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 15))
        func advanceFixture(to mode: String) {
            // The failed recording retained fixture 11 after the next tap.
            // Retry only while the expected fixture has not arrived, so every
            // photo combination still receives all original geometry checks.
            for _ in 0..<3 {
                if next.label.contains("current \(mode)") { return }
                app.activate()
                XCTAssertTrue(next.isHittable)
                next.tap()
                let updated = XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "label CONTAINS %@", "current \(mode)"), object: next)
                if XCTWaiter.wait(for: [updated], timeout: 5) == .completed { return }
            }
            XCTFail("Could not advance to comparison fixture \(mode): \(app.debugDescription)")
        }
        for (index, mode) in ["11", "10", "01", "00"].enumerated() {
            if index > 0 { advanceFixture(to: mode) }
            let updated = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label CONTAINS %@", mode), object: next)
            XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 5), .completed)

            let left = app.buttons["comparison-choice-new"]
            let right = app.buttons["comparison-choice-existing"]
            XCTAssertTrue(left.exists, "Missing left choice for fixture \(mode)")
            XCTAssertTrue(right.exists, "Missing right choice for fixture \(mode)")
            XCTAssertEqual(left.frame.width, right.frame.width, accuracy: 1)
            XCTAssertEqual(left.value as? String, right.value as? String)
            XCTAssertTrue((left.value as? String)?.contains("Square photo area") == true)
            XCTAssertGreaterThanOrEqual(left.frame.minX, 0)
            XCTAssertLessThanOrEqual(right.frame.maxX, app.windows.firstMatch.frame.maxX)
            let separator = app.staticTexts["comparison-or"]
            XCTAssertTrue(separator.exists)
            XCTAssertGreaterThan(separator.frame.midX, left.frame.maxX)
            XCTAssertLessThan(separator.frame.midX, right.frame.minX)
            XCTAssertTrue(left.label.contains("Smoky Sunday version"))
            XCTAssertTrue(right.label.contains("Version 2"))
            XCTAssertTrue(app.scrollViews["comparison-content"].exists)
        XCTAssertFalse(app.scrollViews["comparison-content"].staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Score '")).firstMatch.exists)

            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Comparison \(mode) Dark"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
