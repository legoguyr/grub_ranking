import Foundation
import SwiftData
import SwiftUI

/// One publication implementation shared by manual composition and completed-cook intents.
@MainActor enum SocialPostPublisher {
    static func ready(context: ModelContext, sync: CookingSyncCoordinator?) -> Bool {
        // A visible cooking form holds hydration, not structured upload. Do not wait on photo backup
        // or .current while that lease is held; server expectedRevision remains authoritative.
        guard !context.hasChanges, (try? SyncJournal.pending(context).isEmpty) == true else { return false }
        return sync?.status != .conflict && sync?.status != .needsReview && sync?.status != .signInRequired
    }
    static func publish(attemptID: UUID, postID: UUID, revision: Int, includePhoto: Bool, photo: Data?,
                        request: SocialRequest, media: SocialMediaRequest?,
                        prepared: (SocialPost) throws -> Void = { _ in }) async throws -> SocialPost {
        let response = try await request("social_content", "prepare", .init(postID: postID, attemptID: attemptID,
            expectedRevision: revision, confirmed: true, includePhoto: includePhoto))
        guard let post = try JSONDecoder().decode(SocialPostsPage.self, from: response).posts.first else { throw AccountFoundationError.invalidResolution }
        try Task.checkCancellation(); try prepared(post)
        if post.published { return post }
        if let path = post.photoPath {
            guard includePhoto, let photo, let media, SocialMediaRules.validJPEG(photo) else { throw AccountFoundationError.invalidResolution }
            _ = try await media(.upload(path: path, bytes: photo))
        }
        let result = try await request("social_content", "publish", .init(postID: post.id))
        guard let published = try JSONDecoder().decode(SocialPostsPage.self, from: result).posts.first, published.published else { throw AccountFoundationError.invalidResolution }
        try Task.checkCancellation(); return published
    }
}

nonisolated struct SocialPublicationIntent: Codable, Equatable, Identifiable, Sendable {
    let id: UUID // Newly allocated RankedItem identity, known before the private transaction.
    var postID: UUID
    let includePhoto: Bool
    let createdAt: Date
    var scoreWasLocked: Bool? = nil // Unknown older records are treated conservatively as locked.
}
nonisolated struct SocialPublicationJournal: Codable, Sendable {
    let version: Int
    let accountID: UUID
    var intents: [SocialPublicationIntent]
    static func url(_ root: URL) -> URL { root.appendingPathComponent("SocialPublicationOutbox.json") }
    static func load(root: URL, accountID: UUID) throws -> Self {
        let file = url(root)
        guard (try? file.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true else { throw SyncFoundationError.wrongAccount }
        guard FileManager.default.fileExists(atPath: file.path) else { return .init(version: 1, accountID: accountID, intents: []) }
        let bytes = try Data(contentsOf: file)
        guard bytes.count <= 2_097_152 else { throw SyncFoundationError.wrongAccount }
        let saved = try JSONDecoder().decode(Self.self, from: bytes)
        guard saved.version == 1, saved.accountID == accountID, Set(saved.intents.map(\.id)).count == saved.intents.count else { throw SyncFoundationError.wrongAccount }
        return saved
    }
    func save(root: URL) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var file = Self.url(root)
        try JSONEncoder().encode(self).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try file.setResourceValues(values)
    }
}

@MainActor @Observable final class SocialPublicationCoordinator {
    enum Status: Equatable { case pending, sharing, failed, review, shared }
    private(set) var intents: [SocialPublicationIntent] = []
    private var completed = Set<UUID>()
    private var failed = Set<UUID>()
    private var publishing: UUID?
    private var reviewRequired = Set<UUID>()
    private(set) var storageFailed = false
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var root: URL?
    @ObservationIgnored private var owner: UUID?
    @ObservationIgnored private var request: SocialRequest?
    @ObservationIgnored private var media: SocialMediaRequest?
    @ObservationIgnored private var sync: CookingSyncCoordinator?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var requestedAgain = false
    @ObservationIgnored private var writable = true
    func connect(context: ModelContext, root: URL, accountID: UUID, request: @escaping SocialRequest,
                 media: SocialMediaRequest?, sync: CookingSyncCoordinator?) {
        disconnect(); self.context = context; self.root = root; owner = accountID
        self.request = request; self.media = media; self.sync = sync
        do { intents = try SocialPublicationJournal.load(root: root, accountID: accountID).intents }
        catch { storageFailed = true; writable = false }
        retry()
    }
    func disconnect() {
        generation = UUID(); task?.cancel(); task = nil
        context = nil; root = nil; owner = nil; request = nil; media = nil; sync = nil
        intents = []; completed = []; failed = []; reviewRequired = []; publishing = nil; storageFailed = false; writable = true
    }
    /// Called only by genuine new-cook creation; never by edit, re-rank, hydration or restore.
    @discardableResult func record(itemID: UUID, includePhoto: Bool) -> Bool {
        guard owner != nil else { return false }
        guard !intents.contains(where: { $0.id == itemID }), !completed.contains(itemID) else { return true }
        intents.append(.init(id: itemID, postID: itemID, includePhoto: includePhoto, createdAt: .now))
        do { try persist() } catch { storageFailed = true; failed.insert(itemID) }
        return true
    }
    func privateSaveFinished(_ attempt: CookingAttempt) {
        guard let index = intents.firstIndex(where: { $0.id == attempt.rankedItemID }) else { return }
        intents[index].scoreWasLocked = !ScoreUnlockPolicy.state(for: attempt).isUnlocked
        do { try persist() } catch { storageFailed = true; failed.insert(attempt.rankedItemID) }
    }
    func sharedManually(_ item: UUID) {
        guard intents.contains(where: { $0.id == item }) else { return }
        intents.removeAll { $0.id == item }; completed.insert(item); failed.remove(item); reviewRequired.remove(item)
        do { try persist() } catch { storageFailed = true }
    }
    func status(_ item: UUID) -> Status? {
        if completed.contains(item) { return .shared }
        guard intents.contains(where: { $0.id == item }) else { return nil }
        if reviewRequired.contains(item) { return .review }
        if failed.contains(item) || storageFailed { return .failed }
        return publishing == item ? .sharing : .pending
    }
    var pendingAttempts: [CookingAttempt] {
        let ids = Set(intents.map(\.id))
        return ((try? context?.fetch(FetchDescriptor<CookingAttempt>())) ?? []).filter { ids.contains($0.rankedItemID) }
    }
    func retry() {
        guard task == nil else { requestedAgain = true; return }
        requestedAgain = false
        let token = generation
        task = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.generation == token {
                    self.task = nil
                    if self.requestedAgain { self.requestedAgain = false; self.retry() }
                }
            }
            await self.process(token: token)
        }
    }
    func retryNow() async { retry(); await task?.value }
    private func process(token: UUID) async {
        guard let context, let request else { return }
        do { try persist(); storageFailed = false } catch { storageFailed = true; return }
        guard SocialPostPublisher.ready(context: context, sync: sync) else { return }
        for intent in intents {
            guard token == generation, !Task.isCancelled else { return }
            guard let attempt = (try? context.fetch(FetchDescriptor<CookingAttempt>()))?.first(where: { $0.rankedItemID == intent.id }),
                  attempt.rankedItem != nil, attempt.dish != nil else { continue }
            if intent.scoreWasLocked != false && ScoreUnlockPolicy.state(for: attempt).isUnlocked {
                reviewRequired.insert(intent.id); continue
            }
            publishing = intent.id; failed.remove(intent.id)
            do {
                let revision = try SyncJournal.binding(context)?.acceptedRevision ?? 0
                let bytes = intent.includePhoto ? attempt.primaryImage.flatMap { LocalPhotoStore.data(for: $0, thumbnail: false, rootURL: root) } : nil
                _ = try await SocialPostPublisher.publish(attemptID: attempt.id, postID: intent.postID, revision: revision,
                    includePhoto: intent.includePhoto, photo: bytes, request: request, media: media, prepared: { post in
                        guard token == self.generation else { throw CancellationError() }
                        if let index = self.intents.firstIndex(where: { $0.id == intent.id }) {
                            self.intents[index].postID = post.id; try self.persist()
                        }
                    })
                guard token == generation, !Task.isCancelled else { return }
                intents.removeAll { $0.id == intent.id }; completed.insert(intent.id); try persist()
                NotificationCenter.default.post(name: .socialContentChanged, object: nil)
            } catch is CancellationError { return }
            catch { if token == generation { failed.insert(intent.id) } }
            if token == generation { publishing = nil }
        }
    }
    func keepPrivate(_ item: UUID) async {
        guard let intent = intents.first(where: { $0.id == item }), publishing != item else { return }
        let token = generation
        if let request {
            do { _ = try await request("social_content", "delete", .init(postID: intent.postID)) }
            catch { if token == generation { failed.insert(item) }; return }
            guard token == generation else { return }
            await SocialPhotoCleanup.run(request: request, media: media)
        }
        guard token == generation else { return }
        intents.removeAll { $0.id == item }; failed.remove(item)
        do { try persist() } catch { storageFailed = true }
    }
    private func persist() throws {
        guard writable, let root, let owner else { throw SyncFoundationError.wrongAccount }
        try SocialPublicationJournal(version: 1, accountID: owner, intents: intents).save(root: root)
    }
}

private struct SocialPublicationKey: EnvironmentKey { static let defaultValue: SocialPublicationCoordinator? = nil }
extension EnvironmentValues {
    var socialPublication: SocialPublicationCoordinator? { get { self[SocialPublicationKey.self] } set { self[SocialPublicationKey.self] = newValue } }
}
struct SocialPublicationHost: ViewModifier {
    @Environment(\.modelContext) private var context
    @Environment(\.cookingMediaRoot) private var root
    @Environment(\.socialRequest) private var request
    @Environment(\.socialMedia) private var media
    @Environment(\.cookingSyncCoordinator) private var sync
    @Environment(\.scenePhase) private var phase
    @State private var coordinator = SocialPublicationCoordinator()
    func body(content: Content) -> some View {
        content.environment(\.socialPublication, coordinator)
            .task(id: root) {
                guard let root, let request else { return }
                var owner = try? SyncJournal.binding(context)?.accountID
                #if DEBUG
                if owner == nil, DebugReviewConfiguration.current.storeID != nil, ProcessInfo.processInfo.arguments.contains("--social-review") {
                    owner = UUID(uuidString: "10000000-0000-0000-0000-000000000099")
                }
                #endif
                guard let owner else { return }
                coordinator.connect(context: context, root: root, accountID: owner, request: request, media: media, sync: sync)
                defer { coordinator.disconnect() }
                try? await Task.sleep(for: .seconds(31_536_000))
            }
            .onChange(of: sync?.status) { _, _ in coordinator.retry() }
            .onChange(of: phase) { _, next in if next == .active { coordinator.retry() } }
            .onReceive(NotificationCenter.default.publisher(for: .cookingSyncWorkCommitted)) { _ in coordinator.retry() }
    }
}

struct SocialPublicationStatus: View {
    let itemID: UUID
    @Environment(\.socialPublication) private var coordinator
    var body: some View {
        if let coordinator, let state = coordinator.status(itemID) {
            VStack(alignment: .leading, spacing: 8) {
                switch state {
                case .shared: Label("Shared with Friends", systemImage: "checkmark.circle").accessibilityIdentifier("automatic-share-success")
                case .sharing: ProgressView("Sharing with Friends…")
                case .review:
                    Text("Your score is now unlocked. Review this pending share before publishing.")
                    if let attempt = coordinator.pendingAttempts.first(where: { $0.rankedItemID == itemID }) {
                        SocialShareAction(attempt: attempt)
                    }
                    Button("Keep this cook private") { Task { await coordinator.keepPrivate(itemID) } }
                case .pending, .failed:
                    Text("Your cook and ranking are saved. Sharing with Friends is pending.").accessibilityIdentifier("automatic-share-pending")
                    Button("Retry sharing") { coordinator.retry() }.accessibilityIdentifier("automatic-share-retry")
                    Button("Keep this cook private") { Task { await coordinator.keepPrivate(itemID) } }
                }
            }.font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).sgCard()
                .task { coordinator.retry() }
        }
    }
}

struct SocialPendingShares: View {
    @Environment(\.socialPublication) private var coordinator
    var body: some View {
        if let coordinator, !coordinator.pendingAttempts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pending shares").font(SGTheme.TypeRole.headline)
                ForEach(coordinator.pendingAttempts) { attempt in
                    Text(attempt.displayName)
                    SocialPublicationStatus(itemID: attempt.rankedItemID)
                }
            }.sgCard()
        }
    }
}
