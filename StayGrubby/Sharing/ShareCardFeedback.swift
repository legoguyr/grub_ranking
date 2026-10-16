import Foundation

/// Feedback belongs to the presentation, never to the exported image.
nonisolated enum ShareCardNotice: Equatable, Sendable {
    case imageSaved
    case preparationFailed(String)
    case imageSaveFailed
    case sharingFailed

    var title: String {
        switch self {
        case .imageSaved: "Image saved"
        case .preparationFailed: "Couldn’t prepare share card"
        case .imageSaveFailed: "Couldn’t save image"
        case .sharingFailed: "Couldn’t share image"
        }
    }
    var message: String {
        switch self {
        case .imageSaved: "Your #stayGRUBBY card was saved to Photos."
        case .preparationFailed(let message): message
        case .imageSaveFailed: "Your card wasn’t saved to Photos. Try Save Image again from the share sheet."
        case .sharingFailed: "Your card couldn’t be shared. Please try again."
        }
    }
}

/// UIKit completion and SwiftUI dismissal can arrive in either order. Keep
/// feedback until dismissal, or deliver it immediately if dismissal came first.
nonisolated struct NativeShareFeedback: Sendable {
    private var isPresented = false
    private var pendingNotice: ShareCardNotice?

    mutating func appeared() {
        isPresented = true
        pendingNotice = nil
    }

    mutating func completed(with notice: ShareCardNotice?) -> ShareCardNotice? {
        guard isPresented else { return notice }
        pendingNotice = notice
        return nil
    }

    mutating func dismissed() -> ShareCardNotice? {
        isPresented = false
        defer { pendingNotice = nil }
        return pendingNotice
    }
}
