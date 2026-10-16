import Foundation
import Testing
import UIKit
import Vision
@testable import StayGrubby

@MainActor struct SharingPresentationTests {
    private func card(achievement: ShareAchievement? = nil) throws -> RenderedDishShareCard {
        try ShareCardRenderer.render(model: .init(title: "Sunday Roast", versionSubtitle: "Crispy skin",
            scoreText: "8.7", achievement: achievement, photo: nil), mediaRoot: nil)
    }

    private func recognizedText(_ image: UIImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: #require(image.cgImage)).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " ").uppercased()
    }

    @Test(arguments: [ShareAchievement.newNumberOne, .topFive, .bestVersion])
    func individualExportPresentsTheApprovedAchievementAndNoPrivatePosition(achievement: ShareAchievement) throws {
        let rendered = try card(achievement: achievement)
        let text = try recognizedText(rendered.image)
        #expect(text.contains("SUNDAY ROAST"))
        #expect(text.contains("CRISPY SKIN"))
        #expect(text.contains(achievement.title))
        #expect(!text.contains("OVERALL") && !text.contains("MOVEMENT") && !text.contains("UP 3 SPOTS"))
        #expect(rendered.pixelSize == CGSize(width: 1080, height: 1080))
    }

    @Test func reusableTopThreeFooterIsBlankAndMilestoneFooterIsExplicit() throws {
        let rows = (1...3).map { position in
            TopThreeShareCardModel.Row(position: position, dish: .init(title: "Dish \(position)",
                versionSubtitle: "Version \(position)", scoreText: "8.7", achievement: nil, photo: nil))
        }
        for milestone in [false, true] {
            let model = TopThreeShareCardModel(rows: rows, isUnlockMilestone: milestone)
            let rendered = try ShareCardRenderer.render(topThree: model, mediaRoot: nil)
            let text = try recognizedText(rendered.image)
            #expect(text.contains("MY TOP 3 DISHES SO FAR"))
            #expect(text.contains("SCORES UNLOCKED") == milestone)
            #expect(rendered.pixelSize == CGSize(width: 1080, height: 1350))
        }
    }

    @Test func nativeCompletionDeliversSuccessfulSaveAfterItsCallback() async throws {
        let rendered = try card()
        let outcome = await withCheckedContinuation { continuation in
            let controller = NativeDishShareSheet.makeActivityController(for: rendered) {
                continuation.resume(returning: $0)
            }
            controller.completionWithItemsHandler?(.saveToCameraRoll, true, nil, nil)
        }
        #expect(outcome == .imageSaved)
        #expect(outcome.notice == .imageSaved)
        #expect(outcome.notice?.message.contains("#stayGRUBBY") == true)
        let items = NativeDishShareSheet.activityItems(for: rendered)
        #expect(items.count == 1 && (items[0] as? UIImage) === rendered.image)
    }

    @Test func saveFailureWinsOverCompletedAndNeverReportsSuccess() async throws {
        let rendered = try card()
        let error = NSError(domain: "SharingPresentationTests", code: 1)
        let outcome = await withCheckedContinuation { continuation in
            let controller = NativeDishShareSheet.makeActivityController(for: rendered) {
                continuation.resume(returning: $0)
            }
            controller.completionWithItemsHandler?(.saveToCameraRoll, true, nil, error)
        }
        #expect(outcome == .imageSaveFailed)
        #expect(outcome.notice == .imageSaveFailed)
    }

    @Test func cancelledSaveCopyAndOrdinarySharingDoNotShowSaveSuccess() {
        for activity in [nil, UIActivity.ActivityType.saveToCameraRoll, .copyToPasteboard] {
            let result = NativeShareOutcome.make(activity: activity, completed: false, error: nil)
            #expect(result == .cancelled && result.notice == nil)
        }
        let copy = NativeShareOutcome.make(activity: .copyToPasteboard, completed: true, error: nil)
        #expect(copy == .shared && copy.notice == nil)
        let failure = NativeShareOutcome.make(activity: nil, completed: false,
            error: NSError(domain: "SharingPresentationTests", code: 2))
        #expect(failure == .sharingFailed && failure.notice == .sharingFailed)
    }

    @Test func saveFeedbackWaitsForDismissalAndAlsoHandlesLateCompletion() {
        var feedback = NativeShareFeedback()
        feedback.appeared()
        #expect(feedback.completed(with: .imageSaved) == nil)
        #expect(feedback.dismissed() == .imageSaved)
        #expect(feedback.dismissed() == nil)
        feedback.appeared()
        #expect(feedback.dismissed() == nil)
        #expect(feedback.completed(with: .imageSaved) == .imageSaved)
    }

    @Test func cancelledAndRepeatedSheetsCannotReusePreviousSaveFeedback() {
        var feedback = NativeShareFeedback()
        feedback.appeared()
        #expect(feedback.completed(with: .imageSaveFailed) == nil)
        #expect(feedback.dismissed() == .imageSaveFailed)
        feedback.appeared()
        #expect(feedback.completed(with: nil) == nil)
        #expect(feedback.dismissed() == nil)
    }

    @Test func preparationFailureExplainsActualRendererProblem() {
        let locked = ShareCardNotice.preparationFailed(ShareCardRenderer.RenderError.scoresLocked.localizedDescription)
        #expect(locked.message.contains("10 dishes or versions"))
        let failed = ShareCardNotice.preparationFailed(ShareCardRenderer.RenderError.renderingFailed.localizedDescription)
        #expect(failed.message.contains("try again"))
    }
}
