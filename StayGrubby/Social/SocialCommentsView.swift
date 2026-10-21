import SwiftUI

nonisolated struct SocialComment: Codable, Identifiable, Sendable {
    let id: UUID
    let author: SocialPerson
    let body: String
    let createdAt: Double
    let canDelete: Bool
    let isAuthor: Bool
    var date: Date { Date(timeIntervalSince1970: createdAt) }
}
nonisolated struct SocialCommentsPage: Codable, Sendable { let comments: [SocialComment] }

struct SocialEngagementView: View {
    let post: SocialPost
    @Environment(\.socialRequest) private var request
    @State private var latest: SocialPost?
    @State private var busy = false
    @State private var failed = false
    @State private var showingComments = false
    private var current: SocialPost { latest ?? post }
    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 24) {
                Button { Task { await update(current.liked == true ? "unlike" : "like") } } label: {
                    Label("\(current.likeCount ?? 0)", systemImage: current.liked == true ? "heart.fill" : "heart").frame(minHeight: 44)
                }.accessibilityLabel(current.liked == true ? "Unlike post" : "Like post")
                    .accessibilityValue("\(current.likeCount ?? 0) likes").accessibilityIdentifier("social-like-\(post.id)")
                Button { showingComments = true } label: { Label("\(current.commentCount ?? 0)", systemImage: "bubble").frame(minHeight: 44) }
                    .accessibilityLabel("Comments").accessibilityValue("\(current.commentCount ?? 0) comments").accessibilityIdentifier("social-comments-\(post.id)")
            }.disabled(busy || failed).frame(minHeight: 44)
            if failed { Text("Post unavailable or connection interrupted.").font(.footnote); Button("Refresh post") { Task { await update(nil) } } }
        }
        .sheet(isPresented: $showingComments, onDismiss: { Task { await update(nil) } }) { SocialCommentsView(postID: post.id) }
    }
    private func update(_ action: String?) async {
        guard let request else { return }; busy = true
        defer { busy = false }
        do {
            let response = try await request(action == nil ? "social_feed" : "social_interactions", action ?? "post", .init(postID: post.id))
            guard !Task.isCancelled, let next = try JSONDecoder().decode(SocialPostsPage.self, from: response).posts.first else { return }
            latest = next; failed = false
        } catch is CancellationError { } catch { failed = true }
    }
}

struct SocialCommentsView: View {
    let postID: UUID
    @Environment(\.socialRequest) private var request
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var comments: [SocialComment] = []
    @State private var post: SocialPost?
    @State private var text = ""
    @State private var commentID = UUID()
    @State private var loading = false
    @State private var busy = false
    @State private var failed = false
    @State private var hasMore = false
    @State private var generation = UUID()
    @State private var person: SocialPerson?
    @State private var deleting: SocialComment?
    @State private var confirmingDelete = false
    var body: some View {
        NavigationStack {
            List {
                if let post { Text(post.title).font(.headline) }
                if loading && comments.isEmpty { ProgressView("Loading comments") }
                if failed {
                    Text("Comments unavailable. The post or your access may have changed, or your connection was interrupted.")
                    Button("Retry") { Task { await load() } }.accessibilityIdentifier("comments-retry")
                } else if !loading && comments.isEmpty { Text("No comments yet. Start a conversation.") }
                ForEach(comments) { comment in
                    VStack(alignment: .leading, spacing: 8) {
                        if comment.isAuthor { Text("You · \(comment.author.handle)").font(.headline) }
                        else {
                            Button { person = comment.author } label: { Text("\(comment.author.displayName) · \(comment.author.handle)").font(.headline) }
                        }
                        Text(comment.date, style: .relative).font(.caption).foregroundStyle(.secondary)
                        Text(comment.body).fixedSize(horizontal: false, vertical: true)
                        if comment.canDelete { Button("Delete comment", role: .destructive) { deleting = comment; confirmingDelete = true }.accessibilityIdentifier("comment-delete-\(comment.id)") }
                        if !comment.isAuthor { SocialReportButton(kind: "comment", targetID: comment.id) }
                    }.buttonStyle(.borderless).padding(.vertical, 6).accessibilityElement(children: .contain).accessibilityIdentifier("social-comment-\(comment.id)")
                }
                if hasMore { Button("Load more comments") { Task { await load(more: true) } }.disabled(loading || busy) }
                if post != nil && !failed {
                    Section("Add a comment") {
                        TextField("Write a comment", text: $text, axis: .vertical).lineLimit(2...6).accessibilityIdentifier("comment-body")
                            .onChange(of: text) { _, _ in if !busy { commentID = UUID() } }
                        Text("\(text.unicodeScalars.count) / 1000").font(.caption).foregroundStyle(.secondary)
                        Button(busy ? "Sending…" : "Send comment") { Task { await send() } }
                            .disabled(busy || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.unicodeScalars.count > 1000)
                            .accessibilityIdentifier("comment-send")
                    }.disabled(busy)
                }
            }.navigationTitle("Comments").navigationBarTitleDisplayMode(.inline)
                .scrollDismissesKeyboard(.interactively)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .refreshable { await load() }.task { await load() }
                .onChange(of: scenePhase) { _, phase in
                    generation = UUID(); comments = []; post = nil
                    if phase == .active { Task { await load() } }
                }
                .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
                .onDisappear { generation = UUID(); comments = []; post = nil }
                .sheet(item: $person, onDismiss: { Task { await load() } }) { person in
                    NavigationStack {
                        FriendProfileView(person: person) { Task { await load() } }
                            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { self.person = nil } } }
                    }
                }
                .confirmationDialog("Delete this comment?", isPresented: $confirmingDelete, titleVisibility: .visible, presenting: deleting) { comment in
                    Button("Delete comment", role: .destructive) { Task { await remove(comment) } }
                }
        }
    }
    private func load(more: Bool = false) async {
        guard let request else { return }
        let token = UUID(); generation = token; let cursor = more ? comments.last : nil
        loading = true; failed = false
        if !more { comments = []; post = nil; hasMore = false }
        defer { if generation == token { loading = false } }
        do {
            let snapshot = try JSONDecoder().decode(SocialPostsPage.self, from: await request("social_feed", "post", .init(postID: postID)))
            let page = try JSONDecoder().decode(SocialCommentsPage.self, from: await request("social_interactions", "comments", .init(postID: postID, beforeTime: cursor?.createdAt, beforeID: cursor?.id)))
            guard !Task.isCancelled, generation == token, let latest = snapshot.posts.first else { return }
            post = latest; let ids = Set(comments.map(\.id)); comments += page.comments.filter { !ids.contains($0.id) }; hasMore = page.comments.count == 25
        } catch is CancellationError { } catch {
            guard generation == token else { return }; post = nil; comments = []; failed = true
        }
    }
    private func send() async {
        guard let request else { return }; busy = true
        defer { busy = false }
        do {
            _ = try await request("social_interactions", "comment", .init(postID: postID, commentID: commentID, body: text))
            guard !Task.isCancelled else { return }; text = ""; commentID = UUID(); await load()
        } catch is CancellationError { } catch { failed = true }
    }
    private func remove(_ comment: SocialComment) async {
        guard let request else { return }; busy = true
        defer { busy = false }
        do { _ = try await request("social_interactions", "deleteComment", .init(postID: postID, commentID: comment.id)); await load() }
        catch is CancellationError { } catch { failed = true }
    }
}
