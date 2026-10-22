import SwiftUI

nonisolated struct SocialNotification: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let kind: String
    let actor: SocialPerson
    let targetID: UUID
    let postID: UUID?
    let createdAt: Double
    let read: Bool
    var date: Date { Date(timeIntervalSince1970: createdAt) }
    var message: String {
        switch kind {
        case "request": "sent you a friend request"
        case "accepted": "accepted your friend request"
        case "invited": "tagged you in a shared cook"
        case "joined": "joined your shared cook"
        case "recreated": "ran back your cooking"
        case "like": "gave your cooking Hands 🙌"
        case "comment": "commented on your cooking"
        default: "shared cooking activity"
        }
    }
}
nonisolated struct SocialNotificationsPage: Codable, Sendable { let notifications: [SocialNotification]; let unread: Int }

struct NotificationsLink: View {
    @Environment(\.socialRequest) private var request
    @Environment(\.scenePhase) private var phase
    @State private var unread = 0
    @State private var revision = 0
    var body: some View {
        if request != nil {
            NavigationLink { SocialNotificationsView() } label: {
                Label(unread > 0 ? "Order Up!, \(unread) unread" : "Order Up!", systemImage: unread > 0 ? "bell.badge" : "bell").frame(minHeight: SGTheme.Size.minimumTap).contentShape(Rectangle())
            }.accessibilityIdentifier("notifications-open")
                .task(id: revision) { await load() }
                .onChange(of: phase) { _, next in unread = 0; if next == .active { revision += 1 } }
                .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in revision += 1 }
                .onReceive(NotificationCenter.default.publisher(for: .socialNotificationsRead)) { _ in revision += 1 }
        }
    }
    private func load() async {
        guard let request else { return }
        do { let page = try JSONDecoder().decode(SocialNotificationsPage.self, from: await request("social_notifications", "page", .init())); try Task.checkCancellation(); unread = page.unread }
        catch is CancellationError { } catch { unread = 0 }
    }
}

struct SocialNotificationsView: View {
    @Environment(\.socialRequest) private var request
    @Environment(\.scenePhase) private var phase
    @State private var notifications: [SocialNotification] = []
    @State private var unread = 0
    @State private var hasMore = false
    @State private var busy = false
    @State private var failed = false
    @State private var route: SocialNotification?
    @State private var generation = UUID()
    var body: some View {
        SGEditorialList {
            SGPageIntro(title: "Order Up!", subtitle: "Your circle, caught up.", eyebrow: "Cooking together", showsTitle: false).listRowSeparator(.hidden)
            if busy && notifications.isEmpty { ProgressView("Loading notifications") }
            if failed {
                Text("Notifications unavailable. Check your connection and retry.")
                Button("Retry notifications") { Task { await load() } }
            } else if !busy && notifications.isEmpty {
                ContentUnavailableView("You’re all caught up", systemImage: "bell", description: Text("Friend requests and shared cooking activity appear here."))
            }
            Text("\(unread) unread").font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("notifications-unread")
            ForEach(notifications) { notice in
                Button { Task { await open(notice) } } label: {
                    HStack(alignment: .top, spacing: 12) {
                        SocialAvatar(name: notice.actor.displayName, path: notice.actor.avatarPath, size: 36)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(notice.actor.displayName).font(.headline)
                            Text(notice.message).font(.body)
                            Text(notice.date, style: .relative).font(.caption).foregroundStyle(SGTheme.ColorToken.subdued)
                        }.foregroundStyle(SGTheme.ColorToken.primaryText).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        if !notice.read { Image(systemName: "circle.fill").font(.caption2).foregroundStyle(SGTheme.ColorToken.accent).accessibilityLabel("Unread") }
                    }.padding(.vertical, SGTheme.Space.small).padding(.horizontal, SGTheme.Space.xSmall).background(notice.read ? Color.clear : SGTheme.ColorToken.selected, in: RoundedRectangle(cornerRadius: SGTheme.Radius.field)).contentShape(Rectangle())
                }.buttonStyle(.borderless).disabled(busy).accessibilityIdentifier("notification-\(notice.id)")
            }
            if hasMore { Button("Load more notifications") { Task { await load(more: true) } }.disabled(busy) }
        }.navigationTitle("Order Up!").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Mark All Read") { Task { await load(action: "readAll") } }.disabled(busy || unread == 0) } }
            .task { await load() }.refreshable { await load() }
            .onChange(of: phase) { _, next in generation = UUID(); notifications = []; unread = 0; if next == .active { Task { await load() } } }
            .onDisappear { generation = UUID() }
            .onChange(of: route) { _, next in if next == nil { Task { await load() } } }
            .navigationDestination(item: $route) { notice in
                switch notice.kind {
                case "request", "accepted": FriendProfileView(person: notice.actor) { Task { await load() } }
                case "invited", "joined": SharedCookingEntryView(eventID: notice.targetID)
                default:
                    if let postID = notice.postID { SocialPostDetailView(postID: postID, comments: notice.kind == "comment") }
                }
            }
    }
    private func load(more: Bool = false, action: String = "page") async {
        guard let request else { return }; let token = UUID(); generation = token
        let cursor = more ? notifications.last : nil
        if !more { notifications = []; unread = 0; hasMore = false }
        busy = true; failed = false
        defer { if generation == token { busy = false } }
        do {
            let next = try JSONDecoder().decode(SocialNotificationsPage.self, from: await request("social_notifications", action, .init(beforeTime: cursor?.createdAt, beforeID: cursor?.id)))
            guard !Task.isCancelled, token == generation else { return }
            let ids = Set(notifications.map(\.id)); notifications += next.notifications.filter { !ids.contains($0.id) }; unread = next.unread; hasMore = next.notifications.count == 25
            NotificationCenter.default.post(name: .socialNotificationsRead, object: nil)
        } catch is CancellationError { } catch { if token == generation { notifications = []; unread = 0; hasMore = false; failed = true } }
    }
    private func open(_ notice: SocialNotification) async {
        guard let request else { return }; busy = true
        defer { busy = false }
        do {
            _ = try await request("social_notifications", "read", .init(targetID: notice.id)); try Task.checkCancellation()
            route = notice; NotificationCenter.default.post(name: .socialContentChanged, object: nil)
        } catch is CancellationError { } catch { notifications = []; unread = 0; failed = true }
    }
}
extension Notification.Name { static let socialNotificationsRead = Notification.Name("StayGrubby.socialNotificationsRead") }

struct SocialPostDetailView: View {
    let postID: UUID
    var comments = false
    @Environment(\.socialRequest) private var request
    @Environment(\.scenePhase) private var phase
    @State private var post: SocialPost?
    @State private var failed = false
    @State private var showingComments = false
    @State private var person: SocialPerson?
    @State private var deleting = false
    @State private var route: SocialPostRoute?
    @State private var generation = UUID()
    var body: some View {
        ScrollView {
            if let post { SocialFeedCard(post: post, profile: { person = post.author }, delete: { deleting = true }, isDetail: true, navigate: { route = $0 }).padding() }
            else if failed { ContentUnavailableView("Post unavailable", systemImage: "lock", description: Text("The post or your access may have changed.")); Button("Retry post") { Task { await load() } } }
            else { ProgressView("Loading post") }
        }.background(SGTheme.ColorToken.background).navigationTitle("Post").navigationBarTitleDisplayMode(.inline).task { await load(); if post != nil { showingComments = comments } }
            .navigationDestination(item: $route) { SocialPostDestination(route: $0) }
            .onChange(of: phase) { _, next in generation = UUID(); post = nil; if next == .active { Task { await load() } } }
            .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
            .onDisappear { generation = UUID() }
            .sheet(isPresented: $showingComments, onDismiss: { Task { await load() } }) { SocialCommentsView(postID: postID) }
            .sheet(item: $person, onDismiss: { Task { await load() } }) { person in NavigationStack { FriendProfileView(person: person) { Task { await load() } }.toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { self.person = nil } } } } }
            .confirmationDialog("Delete shared post?", isPresented: $deleting, titleVisibility: .visible) { Button("Delete shared post", role: .destructive) { Task { await remove() } } }
    }
    private func load() async {
        guard let request else { return }; let token = UUID(); generation = token; post = nil; failed = false
        do { let next = try JSONDecoder().decode(SocialPostsPage.self, from: await request("social_feed", "post", .init(postID: postID))); guard !Task.isCancelled, generation == token else { return }; post = next.posts.first; failed = post == nil }
        catch is CancellationError { } catch { if generation == token { failed = true } }
    }
    private func remove() async {
        guard let request else { return }
        do { _ = try await request("social_content", "delete", .init(postID: postID)); await load(); NotificationCenter.default.post(name: .socialContentChanged, object: nil) }
        catch { post = nil; failed = true }
    }
}
