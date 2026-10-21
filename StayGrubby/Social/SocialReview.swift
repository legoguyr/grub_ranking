#if DEBUG
import SwiftUI

/// Explicit isolated UI review only. No Auth, Supabase client or normal-store writes.
@MainActor @Observable final class SocialReview {
    var identity = SocialIdentity(displayName: "", username: nil, discoverable: false)
    func request(_ endpoint: String, _ action: String, _ payload: SocialPayload) async throws -> Data {
        guard endpoint == "social_identity" else { throw URLError(.unsupportedURL) }
        if action == "save" { identity = SocialIdentity(displayName: payload.displayName ?? "", username: payload.username, discoverable: payload.discoverable ?? false) }
        return try JSONEncoder().encode(identity)
    }
}
struct SocialReviewModifier: ViewModifier {
    @State private var review = SocialReview()
    func body(content: Content) -> some View {
        if DebugReviewConfiguration.current.storeID != nil && ProcessInfo.processInfo.arguments.contains("--social-review") {
            content.environment(\.socialRequest, { endpoint, action, payload in try await review.request(endpoint, action, payload) })
        } else { content }
    }
}
#endif
