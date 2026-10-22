import SwiftUI

struct SocialFeedView: View {
    var isSelected = true
    @Environment(\.socialRequest) private var request
    @Environment(\.socialMedia) private var media
    @Environment(\.scenePhase) private var scenePhase
    @State private var posts: [SocialPost] = []
    @State private var own = false
    @State private var identity: SocialIdentity?
    @State private var friendCount = 0
    @State private var loading = false
    @State private var failed = false
    @State private var hasMore = false
    @State private var generation = UUID()
    @State private var revision = 0
    @State private var editingIdentity = false
    @State private var person: SocialPerson?
    @State private var deleting: SocialPost?
    @State private var confirmingDelete = false
    var body: some View {
        List {
            Picker("Posts", selection: $own) {
                Text("Friends Feed").tag(false); Text("Shared by me").tag(true)
            }.pickerStyle(.segmented).accessibilityIdentifier("feed-scope")
            if request == nil {
                ContentUnavailableView("Friends Feed", systemImage: "person.2", description: Text("Sign in to connect with friends. Your development cooking library remains private."))
            } else if let identity, !identity.isConfigured {
                Section {
                    Text("Choose your social identity to connect. Your cooking stays private until you share it.")
                    Button("Set up social identity") { editingIdentity = true }
                }
            } else {
                if loading && posts.isEmpty { ProgressView("Loading posts") }
                if failed {
                    Text("Couldn’t load posts. Check your connection and retry.").accessibilityIdentifier("feed-error")
                    Button("Retry") { revision += 1 }.accessibilityIdentifier("feed-retry")
                } else if !loading && posts.isEmpty {
                    ContentUnavailableView(own ? "Nothing shared yet" : friendCount == 0 ? "Cook, rank, connect" : "Your friends haven’t shared yet", systemImage: "fork.knife",
                        description: Text(own ? "Share with Friends from a cook or ranking result. Sharing is always your choice." : "Only you and current friends can see the cooking posts you choose to share."))
                    NavigationLink("Find Friends") { FriendsView() }.accessibilityIdentifier("feed-find-friends")
                }
                ForEach(posts) { post in
                    SocialFeedCard(post: post) { person = post.author } delete: { deleting = post; confirmingDelete = true }
                }.listRowSeparator(.hidden).listRowBackground(SGTheme.ColorToken.background)
                if hasMore { Button("Load more posts") { Task { await load(more: true) } }.disabled(loading).accessibilityIdentifier("feed-more") }
            }
        }
        .listStyle(.plain).background(SGTheme.ColorToken.background)
        .navigationTitle("Friends Feed").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { NotificationsLink() }
            ToolbarItem(placement: .topBarTrailing) { NavigationLink { FriendsView() } label: { Label("Friends", systemImage: "person.2") } }
        }
        .refreshable { await load() }
        .task(id: "\(isSelected):\(own):\(revision)") {
            guard isSelected else { generation = UUID(); posts = []; return }
            await load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in posts = []; revision += 1 }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && isSelected { revision += 1 }
            else { generation = UUID(); posts = [] }
        }
        .onDisappear { generation = UUID() }
        .sheet(item: $person, onDismiss: { revision += 1 }) { person in
            NavigationStack {
                FriendProfileView(person: person) { revision += 1 }
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { self.person = nil } } }
            }
        }
        .sheet(isPresented: $editingIdentity, onDismiss: { revision += 1 }) {
            if let identity { SocialIdentityEditor(identity: identity) { self.identity = $0; revision += 1 } }
        }
        .confirmationDialog("Delete this shared post?", isPresented: $confirmingDelete, titleVisibility: .visible, presenting: deleting) { post in
            Button("Delete shared post", role: .destructive) { Task { await delete(post) } }
        } message: { _ in Text("Your private cook, photo and ranking stay intact.") }
    }
    private func load(more: Bool = false) async {
        guard let request else { return }
        let token = UUID(); generation = token; loading = true; failed = false
        let cursor = more ? posts.last : nil
        if !more { posts = []; hasMore = false }
        defer { if generation == token { loading = false } }
        do {
            let ownIdentity = try JSONDecoder().decode(SocialIdentity.self, from: await request("social_identity", "get", .init()))
            guard !Task.isCancelled, generation == token else { return }; identity = ownIdentity
            guard ownIdentity.isConfigured else { return }
            let people = try JSONDecoder().decode(SocialPeoplePage.self, from: await request("social_people", "friends", .init()))
            let next = try JSONDecoder().decode(SocialPostsPage.self, from: await request(own ? "social_content" : "social_feed", own ? "own" : "page", .init(beforeTime: cursor?.createdAt, beforeID: cursor?.id)))
            guard !Task.isCancelled, generation == token else { return }
            friendCount = people.people.count
            let ids = Set(posts.map(\.id)); posts += next.posts.filter { !ids.contains($0.id) }; hasMore = next.posts.count == 25
            await SocialPhotoCleanup.run(request: request, media: media)
        } catch is CancellationError { } catch {
            guard generation == token else { return }; posts = []; hasMore = false; failed = true
        }
    }
    private func delete(_ post: SocialPost) async {
        guard let request else { return }
        do {
            _ = try await request("social_content", "delete", .init(postID: post.id))
            posts.removeAll { $0.id == post.id }
            await SocialPhotoCleanup.run(request: request, media: media)
            NotificationCenter.default.post(name: .socialContentChanged, object: nil)
        } catch is CancellationError { } catch { posts = []; failed = true }
    }
}

struct SocialFeedCard: View {
    let post: SocialPost
    var profile: () -> Void
    var delete: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            HStack(alignment: .top, spacing: 12) {
            SocialAvatar(name: post.author.displayName, path: post.author.avatarPath)
            if post.isAuthor {
                Text("You · \(post.author.handle)").font(.headline)
            } else {
                Button(action: profile) {
                    VStack(alignment: .leading) { Text(post.author.displayName).font(.headline); Text(post.author.handle).font(.subheadline).foregroundStyle(.secondary) }
                }.buttonStyle(.plain).accessibilityLabel("View \(post.author.displayName)’s profile")
            }
            }
            Text(post.date, style: .relative).font(.caption).foregroundStyle(.secondary)
            SocialPhoto(path: post.photoPath).frame(maxWidth: .infinity).frame(height: 240).clipped().clipShape(RoundedRectangle(cornerRadius: 16))
            Text(post.title).font(SGTheme.TypeRole.title).fixedSize(horizontal: false, vertical: true)
            if let version = post.versionTitle { Text(version).foregroundStyle(.secondary) }
            if let provenance = post.provenance {
                if provenance.kind == "recreated", let creator = provenance.creator {
                    Label("Recreated from \(creator.displayName)", systemImage: "arrow.triangle.branch").font(.subheadline)
                } else if let people = provenance.people, !people.isEmpty {
                    Text("Cooked with " + people.map(\.displayName).joined(separator: ", ")).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
            }
            if let score = post.scoreText {
                Text("\(score) / 10").font(SGTheme.TypeRole.title).foregroundStyle(SGTheme.ScoreColor.color(forDisplayedScore: score))
            } else { Label("Score locked", systemImage: "lock").font(.subheadline).foregroundStyle(.secondary) }
            if let achievement = post.achievement { Text(achievement).font(.subheadline) }
            if !post.published { Text("Unpublished photo draft").foregroundStyle(.secondary) }
            if post.moderationState != "active" { Text("Hidden by moderation").foregroundStyle(.secondary) }
            if post.published && post.moderationState == "active" { SocialEngagementView(post: post) }
            if !post.isAuthor && post.published && post.moderationState == "active" {
                NavigationLink { SharedCookingEntryView(postID: post.id) } label: { Label("Make This", systemImage: "fork.knife") }
                    .accessibilityIdentifier("recreate-\(post.id)")
            }
            if post.isAuthor { Button("Delete post", role: .destructive, action: delete).accessibilityIdentifier("feed-delete-\(post.id)") }
            else { SocialReportButton(kind: "post", targetID: post.id) }
        }
        .padding().background(SGTheme.ColorToken.surface, in: RoundedRectangle(cornerRadius: 20))
        .buttonStyle(.borderless)
        .accessibilityElement(children: .contain).accessibilityIdentifier("feed-post-\(post.id)")
    }
}
