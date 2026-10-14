#if DEBUG
import SwiftUI
import SwiftData

/// Compiled out of Release. Never constructs an Auth/backend or invents an account.
@MainActor struct DevelopmentLibraryAccess {
    let container: ModelContainer
    let mediaRoot: URL?
    let isolated: Bool
    static var requestedOnLaunch: Bool {
        DebugReviewConfiguration.current.storeID != nil || ProcessInfo.processInfo.arguments.contains("--development-library")
    }
    static func open() throws -> Self {
        let review = DebugReviewConfiguration.current
        let url = review.storeURL(in: FileManager.default.temporaryDirectory)
        let root = review.mediaRoot(in: FileManager.default.temporaryDirectory)
        let container = try LocalStoreStartup.openGuest(overrideURL:url)
        if review.discoveryFixture, let root { try DiscoveryReviewFixture.seed(container:container,mediaDirectory:root) }
        if let count = review.scoreUnlockCount, let root { try ScoreUnlockReviewFixture.seed(container:container,mediaRoot:root,count:count) }
        return Self(container:container,mediaRoot:root,isolated:review.storeID != nil)
    }
}
private struct EndDevelopmentReviewKey: EnvironmentKey { static let defaultValue: (() -> Void)? = nil }
extension EnvironmentValues {
    var endDevelopmentReview: (() -> Void)? {
        get { self[EndDevelopmentReviewKey.self] }
        set { self[EndDevelopmentReviewKey.self] = newValue }
    }
}
#endif
