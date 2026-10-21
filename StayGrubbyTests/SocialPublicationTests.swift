#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import StayGrubby

@MainActor struct SocialPublicationTests {
    private func memory() throws -> ModelContainer {
        try ModelContainer(for: AppPersistence.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    }
    private func create(_ context: ModelContext, itemID: UUID = UUID()) throws -> CookingAttempt {
        let list = try CookingStore.globalRanking(context: context)
        var draft = CookingDraft(); draft.dishName = "Private soup"
        var session = RankingEngine(itemID: itemID, orderedIDs: list.orderedItems.map(\.id), reaction: .fine)
        while session.nextOpponent != nil { session.answer(.newItem) }
        return try CookingStore.create(draft: draft, session: session, context: context)
    }
    @Test func overridesWinAndUnknownDefaultIsPrivate() {
        var selection = CookingSharingSelection()
        #expect(!selection.selected)
        selection.override = false
        selection.receive(.init(displayName: "Cook", username: "cook", discoverable: false, automaticallyShareNewDishes: true))
        #expect(!selection.selected)
        selection.override = true
        selection.receive(.init(displayName: "Cook", username: "cook", discoverable: false, automaticallyShareNewDishes: false))
        #expect(selection.selected)
        selection = CookingSharingSelection(); let frozen = selection.selected
        selection.receive(.init(displayName: "Cook", username: "cook", discoverable: false, automaticallyShareNewDishes: true))
        #expect(!frozen && selection.selected)
    }
    @Test func journalSurvivesRelaunchAndRejectsAnotherAccount() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), owner = UUID(), item = UUID()
        defer { try? FileManager.default.removeItem(at: root) }
        let journal = SocialPublicationJournal(version: 1, accountID: owner, intents: [.init(id: item, postID: item, includePhoto: false, createdAt: .now)])
        try journal.save(root: root)
        #expect(try SocialPublicationJournal.url(root).resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
        #expect(try SocialPublicationJournal.load(root: root, accountID: owner).intents == journal.intents)
        #expect(throws: SyncFoundationError.self) { try SocialPublicationJournal.load(root: root, accountID: UUID()) }
    }
    @Test func onlyPersistedNewIntentPublishesAndFailurePreservesPrivateGraph() async throws {
        let container = try memory(), context = container.mainContext
        let list = try CookingStore.prepare(context: context)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), owner = UUID()
        defer { try? FileManager.default.removeItem(at: root) }
        let review = SocialReview(), worker = SocialPublicationCoordinator()
        var offline = true
        let request: SocialRequest = { endpoint, action, payload in
            if endpoint == "social_content" && action == "prepare" && offline { throw URLError(.notConnectedToInternet) }
            return try await review.request(endpoint, action, payload)
        }
        worker.connect(context: context, root: root, accountID: owner, request: request, media: nil, sync: nil)
        let item = UUID(); worker.record(itemID: item, includePhoto: false)
        await worker.retryNow()
        #expect(review.posts.isEmpty && list.items.isEmpty) // Form intent is not publication.
        let cook = try create(context, itemID: item)
        let before = try CookingGraphExport.snapshot(context: context)
        await worker.retryNow()
        #expect(worker.status(item) == .failed)
        #expect(try CookingGraphExport.snapshot(context: context) == before)
        #expect(review.posts.isEmpty)
        worker.disconnect(); offline = false
        worker.connect(context: context, root: root, accountID: owner, request: request, media: nil, sync: nil)
        await worker.retryNow()
        #expect(worker.status(item) == .shared && review.posts.count == 1)
        #expect(review.posts[0].scoreText == nil)
        #expect(try CookingGraphExport.snapshot(context: context) == before)
        await worker.retryNow(); #expect(review.posts.count == 1)
        var edit = CookingDraft(attempt: cook); edit.notes = "Private edit"
        try CookingStore.edit(cook, draft: edit, context: context)
        await worker.retryNow(); #expect(review.posts.count == 1 && worker.intents.isEmpty)
        let rerank = CookingReRankingWorkflow(attempt: cook)
        try rerank.choose(.fine, context: context)
        while rerank.session?.nextOpponent != nil { rerank.answer(.newItem) }
        try rerank.finish(context: context)
        await worker.retryNow(); #expect(review.posts.count == 1 && worker.intents.isEmpty)
        worker.disconnect()
        worker.connect(context: context, root: root, accountID: owner, request: request, media: nil, sync: nil)
        await worker.retryNow(); #expect(review.posts.count == 1) // Existing/restored graph is not scanned for publication.
        worker.disconnect()
    }
    @Test func delayedLockedIntentRequiresReviewAfterScoreUnlock() async throws {
        let container = try memory(), context = container.mainContext
        _ = try CookingStore.prepare(context: context)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let worker = SocialPublicationCoordinator(), review = SocialReview()
        var offline = true
        let request: SocialRequest = { endpoint, action, payload in
            if offline { throw URLError(.notConnectedToInternet) }
            return try await review.request(endpoint, action, payload)
        }
        worker.connect(context: context, root: root, accountID: UUID(), request: request, media: nil, sync: nil)
        let item = UUID(); worker.record(itemID: item, includePhoto: false)
        let cook = try create(context, itemID: item); worker.privateSaveFinished(cook)
        await worker.retryNow(); #expect(worker.status(item) == .failed)
        for _ in 0..<9 { _ = try create(context) }
        #expect(ScoreUnlockPolicy.state(for: cook).isUnlocked)
        offline = false; await worker.retryNow()
        #expect(worker.status(item) == .review && review.posts.isEmpty)
        _ = try await SocialPostPublisher.publish(attemptID: cook.id, postID: item, revision: 0, includePhoto: false, photo: nil, request: request, media: nil)
        worker.sharedManually(item)
        #expect(worker.status(item) == .shared && review.posts.count == 1)
        worker.disconnect()
    }
    @Test func failedSocialPhotoRetryUsesOnePostAndNoPrivateWrites() async throws {
        let review = SocialReview(), item = UUID(), attempt = UUID()
        let request: SocialRequest = { try await review.request($0, $1, $2) }
        await #expect(throws: URLError.self) {
            try await SocialPostPublisher.publish(attemptID: attempt, postID: item, revision: 0, includePhoto: true, photo: SocialReview.avatarFixture,
                request: request, media: { _ in throw URLError(.notConnectedToInternet) })
        }
        #expect(review.posts.count == 1 && !review.posts[0].published)
        let post = try await SocialPostPublisher.publish(attemptID: attempt, postID: item, revision: 0, includePhoto: true, photo: SocialReview.avatarFixture,
            request: request, media: { _ in Data() })
        #expect(post.published && review.posts.count == 1)
    }
}
#endif
