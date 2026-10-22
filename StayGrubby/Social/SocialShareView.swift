import SwiftUI
import SwiftData

struct SocialShareAction: View {
    let attempt: CookingAttempt
    @Environment(\.socialRequest) private var request
    @State private var showing = false
    var body: some View {
        if request != nil {
            Button { showing = true } label: { Label("Share with Sous Chefs", systemImage: "person.2").frame(maxWidth: .infinity) }
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
    @Environment(\.socialPublication) private var publication
    @State private var identity: SocialIdentity?
    @State private var editingIdentity = false
    @State private var includePhoto = false
    @State private var postDescription = ""
    @State private var postID = UUID()
    @State private var savedPost: SocialPost?
    @State private var busy = false
    @State private var failed = false
    @State private var attemptedShare = false
    @State private var didPublish = false
    private var model: ShareCardModel { .make(for: attempt) }
    private var ready: Bool {
        SocialPostPublisher.ready(context: context, sync: sync)
    }
    var body: some View {
        NavigationStack {
            SGEditorialList {
                if didPublish {
                    Section {
                        Label("Shared with Sous Chefs", systemImage: "checkmark.circle.fill").accessibilityIdentifier("social-share-success")
                        Text("Your separate cooking post is available to eligible friends. Your private cooking and ranking are unchanged.")
                        Button("Done", action: close).accessibilityIdentifier("social-share-done")
                    }
                } else {
                Section("Share with Sous Chefs") {
                    Text("Your cooking stays private unless you publish here. This creates a separate post for your current eligible friends.")
                    Text(model.title).font(SGTheme.TypeRole.headline)
                    if let version = model.versionSubtitle { Text(version).foregroundStyle(.secondary) }
                    if let score = model.scoreText { Text("\(score) / 10").foregroundStyle(SGTheme.ScoreColor.color(forDisplayedScore: score)) }
                    else { Text("Your score is locked and will not be shared.").accessibilityIdentifier("social-share-score-locked") }
                    if attempt.primaryImage != nil { Toggle("Include this food photo", isOn: $includePhoto).accessibilityIdentifier("social-share-photo") }
                    Text("Includes Course, Cuisine and public cookbook/restaurant/online attribution. Private notes, tags, allergens, Friend/Family details, comparisons and personal rank are not shared. Existing shared snapshots stay unchanged until deleted.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Post Description · optional") {
                    TextField("Tell your Sous Chefs about this cook", text: $postDescription, axis: .vertical)
                        .lineLimit(3...8).accessibilityIdentifier("post-description-input")
                    Text("Shared with this post’s authorized audience. Personal Notes stay private and are never copied here. Up to 2,000 characters.").font(.footnote).foregroundStyle(.secondary)
                }
                if let identity {
                    if !identity.isConfigured {
                        Button("Set up Profile") { editingIdentity = true }.accessibilityIdentifier("social-share-setup")
                    } else {
                        Text("Posting as \(identity.handle). If you have no friends yet, only you can see the post until you connect.")
                        if !ready { Text("Wait for cooking data and photos to finish syncing before sharing.") }
                        Button(busy ? "Sharing…" : "Publish to Sous Chefs") { Task { await publish() } }
                            .disabled(busy || !ready || postDescription.unicodeScalars.count > 2000).accessibilityIdentifier("social-share-publish")
                    }
                } else {
                    if failed { Button("Retry identity") { Task { await load() } } }
                    else { ProgressView("Loading profile") }
                }
                if failed { Text("Couldn’t share. Check your connection and cooking sync, then retry. You can cancel a pending draft and try again.").accessibilityIdentifier("social-share-error") }
                Text("The separate Share action opens the native image share sheet; it does not publish to Sous Chefs.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Share with Sous Chefs").navigationBarTitleDisplayMode(.inline)
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
            let bytes = includePhoto ? attempt.primaryImage.flatMap { LocalPhotoStore.data(for: $0, thumbnail: false, rootURL: mediaRoot) } : nil
            _ = try await SocialPostPublisher.publish(attemptID: attempt.id, postID: postID, revision: revision,
                includePhoto: includePhoto, photo: bytes, request: request, media: media, postDescription: postDescription, prepared: { post in
                    savedPost = post; postID = post.id
                })
            didPublish = true
            publication?.sharedManually(attempt.rankedItemID)
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
