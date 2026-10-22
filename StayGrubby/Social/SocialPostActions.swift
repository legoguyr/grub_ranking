import SwiftUI

/// One explicit action per button, avoiding competing NavigationLinks in a List row.
enum SocialPostRoute: Hashable { case post(UUID), recreate(UUID), recipe(UUID) }
struct SocialPostDestination: View {
    let route: SocialPostRoute
    var body: some View {
        switch route {
        case .post(let id): SocialPostDetailView(postID: id)
        case .recreate(let id): SharedCookingEntryView(postID: id)
        case .recipe(let id): RecipeDetailView(id: id)
        }
    }
}

/// Secondary actions share one location. Only supported, authorized actions are offered.
struct SocialPostActions: View {
    let post: SocialPost
    var delete: () -> Void
    @Environment(\.socialRequest) private var request
    @State private var editing = false
    @State private var reporting = false
    @State private var blocking = false
    @State private var failed = false
    var body: some View {
        Menu {
            if post.isAuthor {
                if post.published && post.moderationState == "active" {
                    Button("Edit Post", systemImage: "pencil") { editing = true }.accessibilityIdentifier("post-edit-\(post.id)")
                }
                Button("Delete Post", systemImage: "trash", role: .destructive, action: delete).accessibilityIdentifier("feed-delete-\(post.id)")
            } else {
                Button("Report post", systemImage: "flag") { reporting = true }.accessibilityIdentifier("social-report-post")
                Button("Block account", systemImage: "person.crop.circle.badge.xmark", role: .destructive) { blocking = true }
            }
        } label: {
            Image(systemName: "ellipsis").frame(width: SGTheme.Size.minimumTap, height: SGTheme.Size.minimumTap).contentShape(Rectangle())
        }.accessibilityLabel("Post actions for \(post.title)").accessibilityIdentifier("post-actions-\(post.id)")
            .sheet(isPresented: $editing) { SocialPostDescriptionEditor(post: post) }
            .sheet(isPresented: $reporting) { SocialReportEditor(kind: "post", targetID: post.id, close: { reporting = false }) }
            .confirmationDialog("Block this account?", isPresented: $blocking, titleVisibility: .visible) {
                Button("Block account", role: .destructive) { Task { await block() } }
            } message: { Text("Their posts will no longer be available to you. Your private cooking is unchanged.") }
            .alert("Couldn’t block account", isPresented: $failed) { Button("OK", role: .cancel) {} } message: { Text("Check your connection and try again.") }
    }
    private func block() async {
        guard let request else { return }
        do { _ = try await request("social_people", "block", .init(peerID: post.author.id)); NotificationCenter.default.post(name: .socialContentChanged, object: nil) }
        catch is CancellationError {} catch { failed = true }
    }
}

struct SocialPostDescriptionEditor: View {
    let post: SocialPost
    @Environment(\.socialRequest) private var request
    @Environment(\.dismiss) private var dismiss
    @State private var description: String
    @State private var busy = false
    @State private var failed = false
    init(post: SocialPost) { self.post = post; _description = State(initialValue: post.postDescription ?? "") }
    var body: some View {
        NavigationStack {
            Form {
                Section("Post Description · optional") {
                    Text(post.title).font(SGTheme.TypeRole.headline)
                    TextField("Tell your Sous Chefs about this cook", text: $description, axis: .vertical).lineLimit(3...10)
                        .accessibilityIdentifier("post-description-input")
                    Text("Up to 2,000 characters. Shared with this post’s authorized audience. Personal Notes are private and never copied here.").font(.footnote)
                }
                if failed { Text("Couldn’t save. The post or your access may have changed. Check your connection and retry.").accessibilityIdentifier("post-edit-error") }
            }.navigationTitle("Edit Post").navigationBarTitleDisplayMode(.inline).disabled(busy)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(busy || description.unicodeScalars.count > 2000).accessibilityIdentifier("post-edit-save") }
                }.interactiveDismissDisabled(busy)
        }
    }
    private func save() async {
        guard let request else { failed = true; return }; busy = true; failed = false; defer { busy = false }
        do {
            _ = try JSONDecoder().decode(SocialPostsPage.self, from: await request("social_content", "editDescription", .init(postID: post.id, postDescription: description)))
            try Task.checkCancellation(); NotificationCenter.default.post(name: .socialContentChanged, object: nil); dismiss()
        } catch is CancellationError {} catch { failed = true }
    }
}

struct SocialPostMetadata: View {
    let metadata: SharedCookingMetadata
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            if let course = metadata.course.flatMap(DishCategory.init(rawValue:)) { Text("Course · \(course.label)").font(.subheadline) }
            if let cuisine = metadata.cuisine { Text("Cuisine · \(cuisine.label)").font(.subheadline) }
            if let source = metadata.source {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Source").font(.subheadline.weight(.semibold))
                    if let name = source.name, !name.isEmpty { Text(name) }
                    if let author = source.author, !author.isEmpty { Text(author) }
                    if let recipe = source.recipe, !recipe.isEmpty { Text(recipe) }
                    if let page = source.page, !page.isEmpty { Text("Page \(page)") }
                }.font(.subheadline)
            }
        }.foregroundStyle(.secondary)
    }
}
