import SwiftUI

/// Reads only the server-authorized social profile page, never the local cooking graph.
struct SocialProfilePosts: View {
    var open: (UUID) -> Void
    var personID: UUID? = nil // nil is the authenticated account, resolved by the server.
    @Environment(\.socialRequest) private var request
    @Environment(\.scenePhase) private var phase
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var posts: [SocialPost] = []
    @State private var loading = false
    @State private var failed = false
    @State private var more = false
    @State private var generation = UUID()
    @State private var revision = 0
    private var columns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: SGTheme.Space.small), count: typeSize.isAccessibilitySize ? 1 : 3) }
    var body: some View {
        if request != nil {
            VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
                Text("Shared from this kitchen").font(SGTheme.TypeRole.title).accessibilityAddTraits(.isHeader)
                if loading && posts.isEmpty { ProgressView("Loading posts") }
                if failed {
                    Text("Posts unavailable. Check your connection or refresh.")
                    Button("Retry posts") { revision += 1 }.accessibilityIdentifier("profile-posts-retry")
                } else if !loading && posts.isEmpty {
                    Text(personID == nil ? "Nothing shared yet. Share a cook with your Sous Chefs when you’re ready." : "No shared posts available to you.").foregroundStyle(.secondary).accessibilityIdentifier("profile-posts-empty")
                }
                LazyVGrid(columns: columns, alignment: .leading, spacing: SGTheme.Space.medium) {
                    ForEach(posts) { post in
                        Button { open(post.id) } label: {
                            VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                                Color.clear.aspectRatio(1, contentMode: .fit).overlay { SocialPhoto(path: post.photoPath) }.clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: SGTheme.Radius.chip)).accessibilityHidden(true)
                                Text(post.title).font(SGTheme.TypeRole.secondary.weight(.semibold)).lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }.frame(maxWidth: .infinity, alignment: .topLeading).contentShape(Rectangle())
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel([post.title, post.versionTitle].compactMap { $0 }.joined(separator: ", "))
                        }.buttonStyle(.plain).accessibilityHint("Opens shared post details")
                            .accessibilityIdentifier("profile-post-\(post.id)")
                    }
                }
                if more { Button("More posts") { Task { await load(nextPage: true) } }.disabled(loading) }
            }.frame(maxWidth: .infinity, alignment: .leading)
                .task(id: revision) { await load() }
                .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in posts = []; revision += 1 }
                .onChange(of: phase) { _, next in generation = UUID(); posts = []; if next == .active { revision += 1 } }
                .onDisappear { generation = UUID() }
        }
    }
    private func load(nextPage: Bool = false) async {
        guard let request else { return }; let token = UUID(); generation = token
        let cursor = nextPage ? posts.last : nil
        if !nextPage { posts = []; more = false }
        loading = true; failed = false; defer { if token == generation { loading = false } }
        do {
            let page = try JSONDecoder().decode(SocialPostsPage.self, from: await request("social_feed", "profile", .init(peerID: personID, beforeTime: cursor?.createdAt, beforeID: cursor?.id)))
            guard !Task.isCancelled, token == generation else { return }
            let ids = Set(posts.map(\.id)); posts += page.posts.filter { !ids.contains($0.id) }; more = page.posts.count == 25
        } catch is CancellationError {} catch { if token == generation { posts = []; more = false; failed = true } }
    }
}
