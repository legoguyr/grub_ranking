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
    var recipes: [UUID: Recipe] = [:]
    var ticketDates: [UUID: Double] = [:]
    var recipeClaims: [UUID: SocialCookingClaim] = [:]
    var sharedEvents: [UUID: SharedCookingEvent] = [:]
    var cookingClaims: [String: SocialCookingClaim] = [:]
    var notices: [SocialNotification] = []
    var people: [SocialPerson] = [
        SocialPerson(id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!, displayName: "Friendly Cook", username: "friend_cook", relationship: .friends),
        SocialPerson(id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!, displayName: "Incoming Cook", username: "incoming_cook", relationship: .incoming),
        SocialPerson(id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!, displayName: "Outgoing Cook", username: "outgoing_cook", relationship: .outgoing),
        SocialPerson(id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!, displayName: "Blocked Cook", username: "blocked_cook", relationship: .blocked),
        SocialPerson(id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!, displayName: "A cook with a long friendly display name", username: "new_cook", relationship: .none)
    ]
    init() {
        if ProcessInfo.processInfo.arguments.contains("--social-review-ready") { identity = .init(displayName: "Review Cook", username: "review_cook", discoverable: false, automaticallyShareNewDishes: ProcessInfo.processInfo.arguments.contains("--social-review-share-default")) }
        if ProcessInfo.processInfo.arguments.contains("--recipes-review") {
            identity.discoverable = true
            let id = UUID(uuidString: "60000000-0000-0000-0000-000000000001")!
            recipes[id] = Recipe(id: id, isOwner: true, content: RecipeContent(title: "Lemon Soup Recipe", ingredients: ["1 lemon", "2 cups stock"], steps: ["Simmer gently"], course: "soup", cuisine: "Italian", source: "A recipe author"), visibility: "private", revision: 1, createdAt: 100, updatedAt: 100, saved: false)
        }
        if ProcessInfo.processInfo.arguments.contains("--product-review-grid") {
            let own = SocialPerson(id: UUID(uuidString: "10000000-0000-0000-0000-000000000099")!, displayName: identity.displayName, username: identity.username ?? "review_cook", relationship: .none)
            for (n, title) in ["Lemon Soup", "Slow-roasted Cauliflower with Tahini", "Chocolate Tart"].enumerated() {
                let id = UUID(uuidString: "70000000-0000-0000-0000-00000000000\(n + 1)")!
                let path = n == 1 ? nil : own.id.uuidString.lowercased() + "/" + id.uuidString.lowercased() + ".jpg"
                if let path { avatars[path] = Self.avatarFixture }
                posts.append(SocialPost(id: id, author: own, title: title, versionTitle: "Sunday version", scoreText: n == 0 ? "8.4" : nil, achievement: nil, createdAt: 1000 - Double(n), photoPath: path, published: true, isAuthor: true, moderationState: "active", postDescription: n == 0 ? "Made this slowly on Sunday. Worth the wait!" : nil, metadata: .init(course: "soup")))
            }
        }
        if ProcessInfo.processInfo.arguments.contains("--shared-review") {
            let eventID = UUID(uuidString: "40000000-0000-0000-0000-000000000001")!
            let own = SocialPerson(id: UUID(uuidString: "10000000-0000-0000-0000-000000000099")!, displayName: "Review Cook", username: "review_cook", relationship: .none)
            sharedEvents[eventID] = .init(id: eventID, owner: people[0], metadata: .init(title: "Lemon Chicken Together", course: "main"), isOwner: false, participants: [.init(person: own, state: "pending")])
            for (index, kind) in ["invited", "request", "accepted", "like", "comment", "recreated"].enumerated() {
                let actor = kind == "request" ? people[1] : people[0]
                let target = kind == "invited" ? eventID : kind == "request" || kind == "accepted" ? actor.id : UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
                notices.append(.init(id: UUID(uuidString: "50000000-0000-0000-0000-00000000000\(index + 1)")!, kind: kind, actor: actor, targetID: target, postID: ["like", "comment", "recreated"].contains(kind) ? target : nil, createdAt: Date().timeIntervalSince1970 - Double(index), read: false))
            }
        }
    }
    private var feedFailures = ProcessInfo.processInfo.arguments.contains("--social-review-feed-error") ? 1 : 0
    private var feedSeeded = false
    func request(_ endpoint: String, _ action: String, _ payload: SocialPayload) async throws -> Data {
        // Opt-in diagnostics for isolated fixtures only; never log payloads/identities.
        if ProcessInfo.processInfo.arguments.contains("--social-review-trace") { NSLog("SOCIAL_REVIEW %@ %@", endpoint, action) }
        if endpoint == "profile_link" {
            guard !ProcessInfo.processInfo.arguments.contains("--profile-link-private") else { throw URLError(.resourceUnavailable) }
            if payload.username == identity.username, identity.discoverable {
                let own = SocialPerson(id: UUID(uuidString: "10000000-0000-0000-0000-000000000099")!, displayName: identity.displayName, username: identity.username!, relationship: .none)
                return try JSONEncoder().encode(SocialPeoplePage(people: [own], isOwn: true))
            }
            guard let person = people.first(where: { $0.username == payload.username && $0.relationship != .blocked }) else { throw URLError(.resourceUnavailable) }
            return try JSONEncoder().encode(SocialPeoplePage(people: [person]))
        }
        if endpoint == "recipes" {
            if action == "list" { return try JSONEncoder().encode(RecipesPage(recipes: Array(recipes.values))) }
            if action == "tickets" { return try JSONEncoder().encode(TicketsPage(tickets: ticketDates.map { RecipeTicket(id: $0.key, createdAt: $0.value, recipe: recipes[$0.key]) })) }
            if action == "provenance" {
                let values = recipeClaims.values.filter { $0.itemID == payload.targetID && $0.completed }.compactMap { c -> RecipeCookSnapshot? in
                    guard let snapshot = c.recipeSnapshot else { return nil }
                    return RecipeCookSnapshot(id: c.id, recipeID: recipes.values.first { $0.content == snapshot }?.id, snapshot: snapshot, revision: 1)
                }
                return try JSONEncoder().encode(RecipeCooksPage(cooks: values))
            }
            if action == "complete", let id = payload.originID, let previous = recipeClaims[id] {
                recipeClaims[id] = .init(id: id, itemID: previous.itemID, kind: previous.kind, completed: true, metadata: previous.metadata, recipeOriginID: id, recipeSnapshot: previous.recipeSnapshot)
                return Data("{}".utf8)
            }
            guard let id = payload.recipeID else { throw URLError(.badURL) }
            if action == "save", let content = payload.recipe {
                let value = Recipe(id: id, isOwner: true, content: content, visibility: payload.visibility ?? "private", revision: (recipes[id]?.revision ?? 0) + 1, createdAt: recipes[id]?.createdAt ?? 100, updatedAt: 200, saved: ticketDates[id] != nil)
                recipes[id] = value; return try JSONEncoder().encode(value)
            }
            if action == "delete" { recipes[id] = nil; ticketDates[id] = nil; return Data("{}".utf8) }
            if action == "unticket" { ticketDates[id] = nil; recipes[id]?.saved = false; return Data("{}".utf8) }
            guard var recipe = recipes[id] else { throw URLError(.resourceUnavailable) }
            if action == "ticket" { ticketDates[id] = ticketDates[id] ?? 100; recipe.saved = true; recipes[id] = recipe }
            if action == "begin", let reservation = payload.originID {
                if recipeClaims[reservation] == nil {
                    recipeClaims[reservation] = .init(id: reservation, itemID: UUID(), kind: "recipe", completed: false, metadata: .init(title: recipe.content.title, course: recipe.content.course), recipeOriginID: reservation, recipeSnapshot: recipe.content)
                }
                return try JSONEncoder().encode(recipeClaims[reservation])
            }
            return try JSONEncoder().encode(recipe)
        }
        if endpoint == "social_notifications" {
            if action == "read" || action == "readAll" {
                notices = notices.map { n in SocialNotification(id: n.id, kind: n.kind, actor: n.actor, targetID: n.targetID, postID: n.postID, createdAt: n.createdAt, read: n.read || action == "readAll" || n.id == payload.targetID) }
            }
            let visible = notices.filter { n in people.contains { $0.id == n.actor.id && $0.relationship != .blocked && $0.relationship != .none && (n.kind != "request" || $0.relationship == .incoming) } }
            return try JSONEncoder().encode(SocialNotificationsPage(notifications: visible.filter { n in payload.beforeTime == nil || n.createdAt < payload.beforeTime! }.prefix(25).map { $0 }, unread: visible.filter { !$0.read }.count))
        }
        if endpoint == "social_cooking" {
            if action == "own" {
                let origins = cookingClaims.values.filter { $0.itemID == payload.targetID }.map { c in CookingProvenance(id: c.id, kind: c.kind, itemID: c.itemID, completed: c.completed, creator: people[0].relationship == .friends ? people[0] : nil, eventID: nil) }
                return try JSONEncoder().encode(CookingProvenancePage(origins: origins, events: sharedEvents.values.filter { $0.isOwner && $0.id == payload.targetID }))
            }
            if action == "complete", let key = cookingClaims.first(where: { $0.value.id == payload.originID })?.key, let c = cookingClaims[key] {
                cookingClaims[key] = .init(id: c.id, itemID: c.itemID, kind: c.kind, completed: true, metadata: c.metadata)
                if let eid = UUID(uuidString: key), let event = sharedEvents[eid] {
                    sharedEvents[eid] = .init(id: eid, owner: event.owner, metadata: event.metadata, isOwner: event.isOwner,
                        participants: event.participants.map { .init(person: $0.person, state: "joined") })
                }
                return try JSONEncoder().encode(cookingClaims[key])
            }
            if action == "create", let eid = payload.eventID {
                if sharedEvents[eid] == nil {
                    let owner = SocialPerson(id: UUID(uuidString: "10000000-0000-0000-0000-000000000099")!, displayName: identity.displayName, username: identity.username ?? "review_cook", relationship: .none)
                    sharedEvents[eid] = .init(id: eid, owner: owner, metadata: .init(title: "Your saved shared cook", course: "main"), isOwner: true, participants: people.filter { payload.participantIDs?.contains($0.id) == true }.map { .init(person: $0, state: "pending") })
                }
                return try JSONEncoder().encode(sharedEvents[eid])
            }
            if let eid = payload.eventID, let event = sharedEvents[eid] {
                guard event.isOwner || people[0].relationship == .friends else { throw URLError(.userAuthenticationRequired) }
                if action == "decline" { sharedEvents[eid] = nil; notices.removeAll { $0.targetID == eid }; return Data("{}".utf8) }
                if action == "event" { return try JSONEncoder().encode(event) }
                if action == "remove" {
                    sharedEvents[eid] = .init(id: eid, owner: event.owner, metadata: event.metadata, isOwner: event.isOwner, participants: event.participants.map { .init(person: $0.person, state: $0.id == payload.peerID ? "removed" : $0.state) })
                    return try JSONEncoder().encode(sharedEvents[eid])
                }
                if action == "claim" {
                    let key = eid.uuidString
                    if cookingClaims[key] == nil { cookingClaims[key] = .init(id: UUID(), itemID: UUID(), kind: "together", completed: false, metadata: event.metadata) }
                    return try JSONEncoder().encode(cookingClaims[key])
                }
            }
            if action == "recreate", let post = posts.first(where: { $0.id == payload.postID }) {
                guard people.contains(where: { $0.id == post.author.id && $0.relationship == .friends }) else { throw URLError(.userAuthenticationRequired) }
                let key = post.id.uuidString
                if cookingClaims[key] == nil {
                    var claim = SocialCookingClaim(id: UUID(), itemID: UUID(), kind: "recreated", completed: false, metadata: .init(title: post.title, course: "main"))
                    if let id = post.recipeID, let recipe = recipes[id] { claim.recipeOriginID = claim.id; claim.recipeSnapshot = recipe.content; recipeClaims[claim.id] = claim }
                    cookingClaims[key] = claim
                }
                return try JSONEncoder().encode(cookingClaims[key])
            }
            throw URLError(.resourceUnavailable)
        }
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
            if action == "page" && feedFailures > 0 { feedFailures -= 1; throw URLError(.notConnectedToInternet) }
            if !feedSeeded && ProcessInfo.processInfo.arguments.contains("--social-review-feed") {
                feedSeeded = true
                posts.append(SocialPost(id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!, author: people[0], title: "Harissa Chicken with Roasted Peppers", versionTitle: "Grilled with lemon", scoreText: "8.6", achievement: nil, createdAt: Date().timeIntervalSince1970, photoPath: nil, published: true, isAuthor: false, moderationState: "active"))
            }
            if ProcessInfo.processInfo.arguments.contains("--social-review-comment"), let seed = posts.first, comments[seed.id] == nil {
                if let index = posts.firstIndex(where: { $0.id == seed.id }) { posts[index].commentCount = 1 }
                comments[seed.id] = [SocialComment(id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!, author: people[0], body: "A friendly cooking comment", createdAt: Date().timeIntervalSince1970, canDelete: false, isAuthor: false)]
            }
            if ProcessInfo.processInfo.arguments.contains("--recipes-review-feed"), let id = recipes.keys.first, let index = posts.firstIndex(where: { !$0.isAuthor }) { posts[index].recipeID = id }
            let visible = posts.filter { post in post.isAuthor || people.contains(where: { $0.id == post.author.id && $0.relationship == .friends }) }.sorted { $0.createdAt == $1.createdAt ? $0.id.uuidString > $1.id.uuidString : $0.createdAt > $1.createdAt }
            if action == "profile" { return try JSONEncoder().encode(SocialPostsPage(posts: visible.filter { post in
                if let peer = payload.peerID { return post.author.id == peer }
                return post.isAuthor
            })) }
            if action == "post" { return try JSONEncoder().encode(SocialPostsPage(posts: visible.filter { $0.id == payload.postID })) }
            return try JSONEncoder().encode(SocialPostsPage(posts: visible))
        }
        if endpoint == "social_content" {
            if action == "cleanup" { return Data(#"{"paths":[]}"#.utf8) }
            if action == "prepare", let id = payload.postID {
                if !posts.contains(where: { $0.id == id }) {
                    let author = SocialPerson(id: UUID(uuidString: "10000000-0000-0000-0000-000000000099")!, displayName: identity.displayName, username: identity.username ?? "review_cook", relationship: .none)
                    posts.append(SocialPost(id: id, author: author, title: "Review cooking post", versionTitle: nil, scoreText: nil, achievement: nil, createdAt: Date().timeIntervalSince1970, photoPath: payload.includePhoto == true ? author.id.uuidString.lowercased() + "/" + id.uuidString.lowercased() + ".jpg" : nil, published: payload.includePhoto != true, isAuthor: true, moderationState: "active", postDescription: payload.postDescription))
                }
            } else if action == "editDescription", let index = posts.firstIndex(where: { $0.id == payload.postID && $0.isAuthor }) {
                posts[index].postDescription = payload.postDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
            } else if action == "delete" { posts.removeAll { $0.id == payload.postID } }
            else if action == "publish", let index = posts.firstIndex(where: { $0.id == payload.postID }) {
                let p = posts[index]; posts[index] = SocialPost(id: p.id, author: p.author, title: p.title, versionTitle: p.versionTitle, scoreText: p.scoreText, achievement: p.achievement, createdAt: p.createdAt, photoPath: p.photoPath, published: true, isAuthor: p.isAuthor, moderationState: p.moderationState, postDescription: p.postDescription, metadata: p.metadata)
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
    @Environment(AppLinkRouter.self) private var links
    func body(content: Content) -> some View {
        if DebugReviewConfiguration.current.storeID != nil && ProcessInfo.processInfo.arguments.contains("--social-review") {
            content.environment(\.socialMedia, { action in
                if action.isDownload { if let data = review.avatars[action.paths[0]] { return data }; throw URLError(.fileDoesNotExist) }
                if case .avatarUpload(let path, let bytes) = action { review.avatars[path] = bytes }
                if case .avatarRemove(let paths) = action { for path in paths { review.avatars[path] = nil } }
                return Data()
            }).environment(\.socialRequest, { endpoint, action, payload in try await review.request(endpoint, action, payload) })
                .task {
                    let arguments = ProcessInfo.processInfo.arguments
                    if let index = arguments.firstIndex(of: "--review-profile-url"), arguments.indices.contains(index + 1), let url = URL(string: arguments[index + 1]) { links.receive(url) }
                }
        } else { content }
    }
}
#endif
