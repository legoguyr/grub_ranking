import SwiftUI
import UIKit

nonisolated enum NativeShareOutcome: Equatable {
    case cancelled, shared, imageSaved, imageSaveFailed, sharingFailed

    static func make(activity: UIActivity.ActivityType?, completed: Bool, error: Error?) -> Self {
        if error != nil { return activity == .saveToCameraRoll ? .imageSaveFailed : .sharingFailed }
        guard completed else { return .cancelled }
        return activity == .saveToCameraRoll ? .imageSaved : .shared
    }

    var notice: ShareCardNotice? {
        switch self {
        case .cancelled, .shared: nil
        case .imageSaved: .imageSaved
        case .imageSaveFailed: .imageSaveFailed
        case .sharingFailed: .sharingFailed
        }
    }
}

/// Both entry points share precisely one rendered local image. No screen capture,
/// account metadata, link, or cloud service is included in the activity items.
struct NativeDishShareSheet: UIViewControllerRepresentable {
    let card: RenderedDishShareCard
    var onCompletion: (NativeShareOutcome) -> Void = { _ in }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        Self.makeActivityController(for: card, onCompletion: onCompletion)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}

    static func makeActivityController(for card: RenderedDishShareCard,
                                       onCompletion: @escaping (NativeShareOutcome) -> Void) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems(for: card), applicationActivities: nil)
        controller.completionWithItemsHandler = { activity, completed, _, error in
            let outcome = NativeShareOutcome.make(activity: activity, completed: completed, error: error)
            Task { @MainActor in onCompletion(outcome) }
        }
        return controller
    }
    static func activityItems(for card: RenderedDishShareCard) -> [Any] { [card.image] }
}
