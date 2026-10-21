import SwiftUI
import SwiftData

struct SocialShareAction: View {
    let attempt: CookingAttempt
    @Environment(\.socialRequest) private var request
    @State private var showing = false
    var body: some View {
        if request != nil {
            Button { showing = true } label: { Label("Share with Friends", systemImage: "person.2").frame(maxWidth: .infinity) }
                .buttonStyle(SGButtonStyle()).accessibilityIdentifier("share-with-friends")
                .accessibilityHint("Review and explicitly publish a separate friends-only cooking post.")
                .sheet(isPresented: $showing) { SocialPostComposer(attempt: attempt, close: { showing = false }) }
        }
    }
}
struct SocialPostComposer: View {
    let attempt: CookingAttempt
    let close: () -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.cookingMediaRoot) private var mediaRoot
    @Environment(\.cookingSyncCoordinator) private var sync
    @Environment(\.socialRequest) private var request
    @Environment(\.socialMedia) private var media
    @State private var identity: SocialIdentity?
    @State private var editingIdentity = false
    @State private var includePhoto = false
    @State private var postID = UUID()
    @State private var savedPost: SocialPost?
    @State private var busy = false
    @State private var failed = false
    @State private var attemptedShare = false
    @State private var didPublish = false
    private var model: ShareCardModel { .make(for: attempt) }
    private var ready: Bool {
        (try? SyncJournal.pending(context).isEmpty) == true && !context.hasChanges && (sync == nil || sync?.status == .current)
    }
    var body: some View {
        NavigationStack {
            Form {
                if didPublish {
                    Section {
                        Label("Shared with Friends", systemImage: "checkmark.circle.fill").accessibilityIdentifier("social-share-success")
                        Text("Your separate cooking post is available to eligible friends. Your private cooking and ranking are unchanged.")
                        Button("Done", action: close).accessibilityIdentifier("social-share-done")
                    }
                } else {
                Section("Share with Friends") {
                    Text("Your cooking stays private unless you publish here. This creates a separate post for your current eligible friends.")
                    Text(model.title).font(SGTheme.TypeRole.headline)
                    if let version = model.versionSubtitle { Text(version).foregroundStyle(.secondary) }
                    if let score = model.scoreText { Text("\(score) / 10").foregroundStyle(SGTheme.ScoreColor.color(forDisplayedScore: score)) }
                    else { Text("Your score is locked and will not be shared.").accessibilityIdentifier("social-share-score-locked") }
                    if attempt.primaryImage != nil { Toggle("Include this food photo", isOn: $includePhoto).accessibilityIdentifier("social-share-photo") }
                    Text("Notes, tags, allergens, Source, comparisons and personal rank are not shared. Existing shared snapshots stay unchanged until deleted.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let identity {
                    if !identity.isConfigured {
                        Button("Set up social identity") { editingIdentity = true }.accessibilityIdentifier("social-share-setup")
                    } else {
                        Text("Posting as \(identity.handle). If you have no friends yet, only you can see the post until you connect.")
                        if !ready { Text("Wait for cooking data and photos to finish syncing before sharing.") }
                        Button(busy ? "Sharing…" : "Publish to Friends") { Task { await publish() } }
                            .disabled(busy || !ready).accessibilityIdentifier("social-share-publish")
                    }
                } else {
                    if failed { Button("Retry identity") { Task { await load() } } }
                    else { ProgressView("Loading social identity") }
                }
                if failed { Text("Couldn’t share. Check your connection and cooking sync, then retry. You can cancel a pending draft and try again.").accessibilityIdentifier("social-share-error") }
                Text("The separate Share action opens the native image share sheet; it does not publish to Friends.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Share with Friends").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { if !didPublish { Button("Cancel") { Task { await cancel() } }.disabled(busy) } } }
            .interactiveDismissDisabled(busy).task { await load() }
            .sheet(isPresented: $editingIdentity) {
                if let identity { SocialIdentityEditor(identity: identity) { self.identity = $0 } }
            }
        }
    }
    private func load() async {
        guard let request else { return }
        do { identity = try JSONDecoder().decode(SocialIdentity.self, from: await request("social_identity", "get", .init())) }
        catch is CancellationError { } catch { failed = true }
    }
    private func publish() async {
        guard let request, ready else { return }; busy = true; failed = false
        defer { busy = false }
        do {
            attemptedShare = true
            let revision = try SyncJournal.binding(context)?.acceptedRevision ?? 0
            let data = try await request("social_content", "prepare", .init(postID: postID, attemptID: attempt.id, expectedRevision: revision, confirmed: true, includePhoto: includePhoto))
            guard let post = try JSONDecoder().decode(SocialPostsPage.self, from: data).posts.first else { failed = true; return }
            savedPost = post; postID = post.id
            if !post.published {
                if let path = post.photoPath {
                    guard includePhoto, let photo = attempt.primaryImage, let bytes = LocalPhotoStore.data(for: photo, thumbnail: false, rootURL: mediaRoot), let media else { failed = true; return }
                    _ = try await media(.upload(path: path, bytes: bytes))
                }
                _ = try await request("social_content", "publish", .init(postID: post.id))
            }
            didPublish = true
            NotificationCenter.default.post(name: .socialContentChanged, object: nil)
        } catch is CancellationError { } catch { failed = true }
    }
    private func cancel() async {
        if attemptedShare && !didPublish && savedPost?.published != true, let request {
            _ = try? await request("social_content", "delete", .init(postID: postID))
            await SocialPhotoCleanup.run(request: request, media: media)
        }
        close()
    }
}
extension Notification.Name { static let socialContentChanged = Notification.Name("StayGrubby.socialContentChanged") }
