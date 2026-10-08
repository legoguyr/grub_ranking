import XCTest

final class CookingUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testCookingCreateVersionEditRerankDeleteAndRelaunch() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString]
        let environment = ProcessInfo.processInfo.environment
        if let appearance = environment["TEST_RUNNER_STAYGRUBBY_APPEARANCE"] ?? environment["STAYGRUBBY_APPEARANCE"] {
            app.launchArguments.append(appearance == "light" ? "--test-light" : "--test-dark")
        }
        if (environment["TEST_RUNNER_STAYGRUBBY_LARGE_TYPE"] ?? environment["STAYGRUBBY_LARGE_TYPE"]) == "1" {
            app.launchArguments.append("--test-large-type")
        }
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))

        func tap(_ button: XCUIElement) {
            XCTAssertTrue(button.waitForExistence(timeout: 15))
            for _ in 0..<6 {
                if button.isHittable {
                    button.tap()
                    return
                }
                app.swipeUp()
            }
            XCTFail("Could not reach \(button)")
        }
        func fill(_ field: XCUIElement, _ text: String) {
            XCTAssertTrue(field.waitForExistence(timeout: 15))
            for _ in 0..<12 {
                if field.isHittable {
                    for _ in 0..<3 {
                        field.tap()
                        let focused = XCTNSPredicateExpectation(
                            predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field)
                        if XCTWaiter.wait(for: [focused], timeout: 3) == .completed {
                            field.typeText(text)
                            let returnKey = app.keyboards.buttons["return"]
                            if returnKey.exists { returnKey.tap() }
                            return
                        }
                    }
                    XCTFail("Could not focus \(field)")
                    return
                }
                app.swipeUp()
            }
            XCTFail("Could not reach \(field)")
        }
        func capture(_ name: String) {
            Thread.sleep(forTimeInterval: 0.8)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        }
        func transition(_ button: XCUIElement, to next: XCUIElement) {
            tap(button)
            if !next.waitForExistence(timeout: 5), button.exists && button.isHittable {
                button.tap()
            }
            XCTAssertTrue(next.waitForExistence(timeout: 15))
        }
        func finishRank(_ name: String, comparisons: Bool) {
            let liked = app.buttons["Liked it"]
            transition(app.buttons["Continue"], to: liked)
            let next = comparisons ? app.buttons["Prefer \(name)"] : app.buttons["ranking-result-close"]
            transition(liked, to: next)
            if comparisons { transition(next, to: app.buttons["ranking-result-close"]) }
            XCTAssertFalse(app.buttons["Save Cook"].exists)
            XCTAssertTrue(app.staticTexts["result-score"].exists)
            XCTAssertTrue(app.staticTexts["result-rank"].exists)
            tap(app.buttons["ranking-result-close"])
            XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        }
        func row(_ name: String) -> XCUIElement {
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", ", \(name), score ")).firstMatch
        }
        func openRow(_ name: String) {
            let rankedRow = row(name)
            for _ in 0..<3 {
                tap(rankedRow)
                if app.navigationBars["Dish Details"].waitForExistence(timeout: 5) { return }
            }
            XCTFail("Could not open \(name)")
        }
        app.revealCreation()
        tap(app.buttons["new-dish"])
        capture("Add Dish")
        fill(app.textFields["dish-name"], "Salmon")
        fill(app.textFields["version-title"], "First cook")
        finishRank("Salmon — First cook", comparisons: false)
        capture("Rankings")
        XCTAssertTrue(row("Salmon — First cook").waitForExistence(timeout: 15))

        app.revealCreation()
        tap(app.buttons["new-version"])
        let parentSearch = app.textFields["parent-dish-search"]
        XCTAssertTrue(parentSearch.waitForExistence(timeout: 10))
        fill(parentSearch, "salmon")
        tap(app.buttons["choose-dish-Salmon"])
        let inherited = app.staticTexts["inherited-dish-name"]
        XCTAssertTrue(inherited.waitForExistence(timeout: 15))
        XCTAssertEqual(inherited.label, "Salmon")
        fill(app.textFields["version-title"], "Second cook")
        transition(app.buttons["Continue"], to: app.buttons["Liked it"])
        transition(app.buttons["Liked it"], to: app.buttons["Prefer Salmon — Second cook"])
        capture("Comparison")
        let preferSecond = app.buttons["Prefer Salmon — Second cook"]
        let resultClose = app.buttons["ranking-result-close"]
        transition(preferSecond, to: resultClose)
        XCTAssertFalse(app.buttons["Save Cook"].exists)
        XCTAssertEqual(app.staticTexts["result-rank"].label, "#1 overall")
        tap(resultClose)
        XCTAssertTrue(row("Salmon — First cook").exists)
        openRow("Salmon — Second cook")
        capture("Dish Detail")
        tap(app.buttons["Edit Cook"])
        let title = app.textFields["version-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 15)); title.tap()
        title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Second cook".count) + "Grilled\n")
        tap(app.buttons["save-cook-metadata"])
        XCTAssertTrue(app.staticTexts["Grilled"].waitForExistence(timeout: 15))

        tap(app.buttons["Re-rank"])
        tap(app.buttons["Too Tough"])
        tap(app.buttons["Undo last answer"])
        tap(app.buttons["Prefer Salmon — First cook"])
        tap(app.buttons["Save Answers"])
        XCTAssertTrue(app.buttons["Edit Cook"].waitForExistence(timeout: 15))

        app.terminate(); app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        openRow("Salmon — Grilled")
        app.buttons["cook-more-actions"].tap()
        XCTAssertTrue(app.buttons["Delete Cook"].waitForExistence(timeout: 10))
        app.buttons["Delete Cook"].tap()
        XCTAssertTrue(app.alerts["Delete this cook?"].buttons["Cancel"].waitForExistence(timeout: 10))
        app.alerts["Delete this cook?"].buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Edit Cook"].exists)
        app.buttons["cook-more-actions"].tap()
        XCTAssertTrue(app.buttons["Delete Cook"].waitForExistence(timeout: 10))
        app.buttons["Delete Cook"].tap()
        let confirmDelete = app.alerts["Delete this cook?"].buttons["Delete Cook"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 15))
        Thread.sleep(forTimeInterval: 0.6)
        confirmDelete.tap()
        if !confirmDelete.waitForNonExistence(timeout: 5), confirmDelete.isHittable {
            confirmDelete.tap()
        }
        XCTAssertTrue(confirmDelete.waitForNonExistence(timeout: 15))
        XCTAssertTrue(row("Salmon — First cook").waitForExistence(timeout: 15))
        XCTAssertFalse(row("Salmon — Grilled").exists)
        app.terminate(); app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        XCTAssertTrue(row("Salmon — First cook").waitForExistence(timeout: 15))
        XCTAssertFalse(row("Salmon — Grilled").exists)
    }
}
