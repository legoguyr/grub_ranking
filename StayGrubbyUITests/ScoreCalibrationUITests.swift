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
            rows.firstMatch.tap(); XCTAssertTrue(app.buttons["detail-edit-cook"].waitForExistence(timeout: 8))
            shot("Calibrated score Dish Detail \(appearance)", app)
            app.terminate()
        }
    }

}
