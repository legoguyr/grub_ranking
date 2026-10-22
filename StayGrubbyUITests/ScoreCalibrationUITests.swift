import XCTest

final class ScoreCalibrationUITests: StayGrubbyUITestCase {
    @MainActor private func shot(_ name: String, _ app: XCUIApplication) {
        let value = XCTAttachment(screenshot: app.screenshot()); value.name = name; value.lifetime = .keepAlways; add(value)
    }
    @MainActor func testSemanticScorePaletteInBothAppearances() {
        continueAfterFailure = false
        for appearance in ["--test-light", "--test-dark"] {
            let app = XCUIApplication()
            app.launchArguments = ["--ui-test-store", UUID().uuidString, "--score-unlock-fixture", "10", "--score-calibration-review", appearance]
            app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 20)); app.showAllVersions()
            let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-'"))
            XCTAssertGreaterThanOrEqual(rows.count, 3)
            for n in 0..<3 {
                XCTAssertNotNil(rows.element(boundBy: n).label.range(of: "score [0-9]+\\.[0-9]", options: .regularExpression))
            }
            shot("Calibrated Liked Fine Disliked scores \(appearance)", app)
            let lowerLabel = rows.element(boundBy: 2).label
            let lowerScore = lowerLabel.components(separatedBy: "score ").last!.components(separatedBy: ",").first!
            let lowerID = rows.element(boundBy: 2).identifier
            let lower = app.buttons[lowerID]
            let ceiling = app.scrollViews["filter-strip"].frame.maxY + 8
            let floor = app.tabBars.firstMatch.frame.minY - 8
            for _ in 0..<8 {
                if lower.isHittable && lower.frame.minY >= ceiling && lower.frame.maxY <= floor { break }
                let delta = max(-150.0, min(150.0, (ceiling + floor) / 2 - lower.frame.midY))
                let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.58))
                start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: delta)), withVelocity: .slow, thenHoldForDuration: 0.2)
            }
            XCTAssertGreaterThanOrEqual(lower.frame.minY, ceiling)
            XCTAssertLessThanOrEqual(lower.frame.maxY, floor)
            shot("Calibrated lower score visible \(appearance)", app)
            lower.tap(); XCTAssertTrue(app.buttons["detail-edit-cook"].waitForExistence(timeout: 8))
            XCTAssertTrue(app.staticTexts["Score " + lowerScore].waitForExistence(timeout: 8))
            shot("Calibrated score Dish Detail \(appearance)", app)
            app.terminate()
        }
    }

}
