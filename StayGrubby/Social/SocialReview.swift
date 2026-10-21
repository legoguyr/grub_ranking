#if DEBUG
import SwiftUI

/// Explicit isolated UI review only. No Auth, Supabase client or normal-store writes.
@MainActor @Observable final class SocialReview {
    var identity = SocialIdentity(displayName: "", username: nil, discoverable: false)
    var posts: [SocialPost] = []
    var people: [SocialPerson] = [
        SocialPerson(id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!, displayName: "Friendly Cook", username: "friend_cook", relationship: .friends),
        SocialPerson(id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!, displayName: "Incoming Cook", username: "incoming_cook", relationship: .incoming),
        SocialPerson(id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!, displayName: "Outgoing Cook", username: "outgoing_cook", relationship: .outgoing),
        SocialPerson(id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!, displayName: "Blocked Cook", username: "blocked_cook", relationship: .blocked),
        SocialPerson(id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!, displayName: "A cook with a long friendly display name", username: "new_cook", relationship: .none)
    ]
    init() {
        if ProcessInfo.processInfo.arguments.contains("--social-review-ready") { identity = .init(displayName: "Review Cook", username: "review_cook", discoverable: false) }
    }
    func request(_ endpoint: String, _ action: String, _ payload: SocialPayload) async throws -> Data {
        if endpoint == "social_identity" {
            if action == "save" { identity = SocialIdentity(displayName: payload.displayName ?? "", username: payload.username, discoverable: payload.discoverable ?? false) }
            return try JSONEncoder().encode(identity)
        }
        if endpoint == "social_content" {
            if action == "cleanup" { return Data(#"{"paths":[]}"#.utf8) }
            if action == "prepare", let id = payload.postID {
                if !posts.contains(where: { $0.id == id }) {
                    let author = SocialPerson(id: UUID(uuidString: "10000000-0000-0000-0000-000000000099")!, displayName: identity.displayName, username: identity.username ?? "review_cook", relationship: .none)
                    posts.append(SocialPost(id: id, author: author, title: "Review cooking post", versionTitle: nil, scoreText: nil, achievement: nil, createdAt: Date().timeIntervalSince1970, photoPath: payload.includePhoto == true ? author.id.uuidString.lowercased() + "/" + id.uuidString.lowercased() + ".jpg" : nil, published: payload.includePhoto != true, isAuthor: true, moderationState: "active"))
                }
            } else if action == "delete" { posts.removeAll { $0.id == payload.postID } }
            else if action == "publish", let index = posts.firstIndex(where: { $0.id == payload.postID }) {
                let p = posts[index]; posts[index] = SocialPost(id: p.id, author: p.author, title: p.title, versionTitle: p.versionTitle, scoreText: p.scoreText, achievement: p.achievement, createdAt: p.createdAt, photoPath: p.photoPath, published: true, isAuthor: p.isAuthor, moderationState: p.moderationState)
            }
            return try JSONEncoder().encode(SocialPostsPage(posts: payload.postID == nil ? posts : posts.filter { $0.id == payload.postID }))
        }
        if endpoint == "social_report" { return Data(#"{"reported":true}"#.utf8) }
        guard endpoint == "social_people" else { throw URLError(.unsupportedURL) }
        if let id = payload.peerID, let index = people.firstIndex(where: { $0.id == id }) {
            switch action {
            case "request": people[index].relationship = people[index].relationship == .incoming ? .friends : .outgoing
            case "accept": people[index].relationship = .friends
            case "decline", "cancel", "remove", "unblock": people[index].relationship = .none
            case "block": people[index].relationship = .blocked
            default: break
            }
            return try JSONEncoder().encode(SocialPeoplePage(people: [people[index]]))
        }
        let matches = people.filter { person in
            switch action {
            case "friends": person.relationship == .friends
            case "incoming": person.relationship == .incoming
            case "outgoing": person.relationship == .outgoing
            case "blocked": person.relationship == .blocked
            case "search": (payload.query?.count ?? 0) >= 2 && person.relationship != .blocked && person.username.contains(payload.query?.lowercased() ?? "")
            default: false
            }
        }
        return try JSONEncoder().encode(SocialPeoplePage(people: matches))
    }
}
struct SocialReviewModifier: ViewModifier {
    @State private var review = SocialReview()
    func body(content: Content) -> some View {
        if DebugReviewConfiguration.current.storeID != nil && ProcessInfo.processInfo.arguments.contains("--social-review") {
            content.environment(\.socialMedia, { action in
                if case .download = action { throw URLError(.fileDoesNotExist) }
                return Data()
            }).environment(\.socialRequest, { endpoint, action, payload in try await review.request(endpoint, action, payload) })
        } else { content }
    }
}
#endif
