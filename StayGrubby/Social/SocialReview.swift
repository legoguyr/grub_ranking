#if DEBUG
import SwiftUI

/// Explicit isolated UI review only. No Auth, Supabase client or normal-store writes.
@MainActor @Observable final class SocialReview {
    var identity = SocialIdentity(displayName: "", username: nil, discoverable: false)
    static var avatarFixture: Data {
        UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { c in UIColor.systemOrange.setFill(); c.fill(CGRect(x: 0, y: 0, width: 24, height: 24)) }.jpegData(compressionQuality: 0.8)!
    }
    var avatars: [String: Data] = [:]
    private var avatarDraft: String?
    var posts: [SocialPost] = []
    var comments: [UUID: [SocialComment]] = [:]
    var people: [SocialPerson] = [
        SocialPerson(id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!, displayName: "Friendly Cook", username: "friend_cook", relationship: .friends),
        SocialPerson(id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!, displayName: "Incoming Cook", username: "incoming_cook", relationship: .incoming),
        SocialPerson(id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!, displayName: "Outgoing Cook", username: "outgoing_cook", relationship: .outgoing),
        SocialPerson(id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!, displayName: "Blocked Cook", username: "blocked_cook", relationship: .blocked),
        SocialPerson(id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!, displayName: "A cook with a long friendly display name", username: "new_cook", relationship: .none)
    ]
    init() {
        if ProcessInfo.processInfo.arguments.contains("--social-review-ready") { identity = .init(displayName: "Review Cook", username: "review_cook", discoverable: false, automaticallyShareNewDishes: ProcessInfo.processInfo.arguments.contains("--social-review-share-default")) }
    }
    private var feedFailures = ProcessInfo.processInfo.arguments.contains("--social-review-feed-error") ? 1 : 0
    private var feedSeeded = false
    func request(_ endpoint: String, _ action: String, _ payload: SocialPayload) async throws -> Data {
        // Opt-in diagnostics for isolated fixtures only; never log payloads/identities.
        if ProcessInfo.processInfo.arguments.contains("--social-review-trace") { NSLog("SOCIAL_REVIEW %@ %@", endpoint, action) }
        if endpoint == "social_avatar" {
            if action == "prepare" { let path = "10000000-0000-0000-0000-000000000099/" + (payload.assetID ?? UUID()).uuidString.lowercased() + ".jpg"; avatarDraft = path; return try JSONEncoder().encode(["path": path]) }
            if action == "publish" { identity.avatarPath = payload.avatarPath }
            if action == "remove" { identity.avatarPath = nil }
            if action == "cleanup" { return Data(#"{"paths":[]}"#.utf8) }
            return try JSONEncoder().encode(identity)
        }
        if endpoint == "social_identity" {
            if action == "sharing" { identity.automaticallyShareNewDishes = payload.automaticallyShareNewDishes ?? false }
            if action == "save" { identity = SocialIdentity(displayName: payload.displayName ?? "", username: payload.username, discoverable: payload.discoverable ?? false, avatarPath: identity.avatarPath, automaticallyShareNewDishes: payload.automaticallyShareNewDishes ?? identity.automaticallyShareNewDishes) }
            return try JSONEncoder().encode(identity)
        }
        if endpoint == "social_interactions", let pid = payload.postID, let index = posts.firstIndex(where: { $0.id == pid }) {
            if action == "comments" { return try JSONEncoder().encode(SocialCommentsPage(comments: comments[pid] ?? [])) }
            if action == "like" { posts[index].liked = true; posts[index].likeCount = 1 }
            if action == "unlike" { posts[index].liked = false; posts[index].likeCount = 0 }
            if action == "comment", let cid = payload.commentID, !(comments[pid] ?? []).contains(where: { $0.id == cid }) {
                let author = SocialPerson(id: UUID(uuidString: "10000000-0000-0000-0000-000000000099")!, displayName: identity.displayName, username: identity.username ?? "review_cook", relationship: .none)
                comments[pid, default: []].insert(SocialComment(id: cid, author: author, body: payload.body ?? "", createdAt: Date().timeIntervalSince1970, canDelete: true, isAuthor: true), at: 0)
            }
            if action == "deleteComment" { comments[pid]?.removeAll { $0.id == payload.commentID } }
            posts[index].commentCount = comments[pid]?.count ?? 0
            return try JSONEncoder().encode(SocialPostsPage(posts: [posts[index]]))
        }
        if endpoint == "social_feed" {
            if feedFailures > 0 { feedFailures -= 1; throw URLError(.notConnectedToInternet) }
            if !feedSeeded && ProcessInfo.processInfo.arguments.contains("--social-review-feed") {
                feedSeeded = true
                posts.append(SocialPost(id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!, author: people[0], title: "Harissa Chicken with Roasted Peppers", versionTitle: "Grilled with lemon", scoreText: "8.6", achievement: nil, createdAt: Date().timeIntervalSince1970, photoPath: nil, published: true, isAuthor: false, moderationState: "active"))
            }
            if ProcessInfo.processInfo.arguments.contains("--social-review-comment"), let seed = posts.first, comments[seed.id] == nil {
                if let index = posts.firstIndex(where: { $0.id == seed.id }) { posts[index].commentCount = 1 }
                comments[seed.id] = [SocialComment(id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!, author: people[0], body: "A friendly cooking comment", createdAt: Date().timeIntervalSince1970, canDelete: false, isAuthor: false)]
            }
            if action == "post" { return try JSONEncoder().encode(SocialPostsPage(posts: posts.filter { $0.id == payload.postID })) }
            let visible = posts.filter { post in post.isAuthor || people.contains(where: { $0.id == post.author.id && $0.relationship == .friends }) }
            return try JSONEncoder().encode(SocialPostsPage(posts: visible))
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
            return try JSONEncoder().encode(SocialPostsPage(posts: payload.postID == nil ? posts.filter(\.isAuthor) : posts.filter { $0.id == payload.postID }))
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
                if action.isDownload { if let data = review.avatars[action.paths[0]] { return data }; throw URLError(.fileDoesNotExist) }
                if case .avatarUpload(let path, let bytes) = action { review.avatars[path] = bytes }
                if case .avatarRemove(let paths) = action { for path in paths { review.avatars[path] = nil } }
                return Data()
            }).environment(\.socialRequest, { endpoint, action, payload in try await review.request(endpoint, action, payload) })
        } else { content }
    }
}
#endif
