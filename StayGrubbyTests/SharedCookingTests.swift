#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import StayGrubby

@MainActor struct SharedCookingTests {
    @Test func prefillCopiesOnlySafeAttribution() throws {
        let bytes = Data(#"{"title":"Soup inspired by a friend","course":"soup","cuisine":{"id":"french","label":"French"},"source":{"type":"cookbook","name":"A cookbook","author":"Recipe Author","recipe":"Soup","page":"42"},"notes":"private","score":"9.9","allergens":["milk"],"photoPath":"private/object.jpg"}"#.utf8)
        let metadata = try JSONDecoder().decode(SharedCookingMetadata.self, from: bytes), draft = metadata.draft()
        #expect(draft.dishName == "Soup inspired by a friend" && draft.category == .soup)
        #expect(draft.cuisine?.id == "french" && draft.source?.cookbookAuthors == "Recipe Author")
        #expect(draft.notes.isEmpty && draft.contains.isEmpty && draft.dietary.isEmpty && draft.allergy.isEmpty && !draft.hasPhoto)
    }
    @Test func journalIsOwnerBoundDurableAndExcludedFromBackup() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), owner = UUID(), item = UUID()
        defer { try? FileManager.default.removeItem(at: root) }
        let intent = CookingSocialIntent(id: item, eventID: item, participants: [UUID()], originID: UUID())
        try CookingSocialJournal(version: 1, accountID: owner, intents: [intent]).save(root: root)
        #expect(try CookingSocialJournal.load(root: root, accountID: owner).intents == [intent])
        #expect(try CookingSocialJournal.url(root).resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
        #expect(throws: SyncFoundationError.self) { try CookingSocialJournal.load(root: root, accountID: UUID()) }
    }
    @Test func noInviteUntilPrivateSaveAndRetryNeverDuplicatesPrivateCooking() async throws {
        let container = try ModelContainer(for: AppPersistence.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext, list = try CookingStore.prepare(context: context)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), owner = UUID(), peer = UUID(), item = UUID(), origin = UUID()
        defer { try? FileManager.default.removeItem(at: root) }
        var offline = true, events = Set<UUID>(), completed = Set<UUID>()
        let request: SocialRequest = { endpoint, action, payload in
            #expect(endpoint == "social_cooking")
            if offline { throw URLError(.notConnectedToInternet) }
            if action == "complete", let id = payload.originID { completed.insert(id) }
            if action == "create", let id = payload.eventID { events.insert(id); #expect(payload.participantIDs == [peer] && payload.confirmed == true) }
            return Data("{}".utf8)
        }
        let worker = SharedCookingCoordinator(); worker.connect(context: context, root: root, owner: owner, request: request, sync: nil)
        try worker.record(itemID: item, participants: [peer], originID: origin)
        await worker.retryNow(); #expect(events.isEmpty && completed.isEmpty && list.items.isEmpty)
        var draft = CookingDraft(); draft.dishName = "My own shared soup"
        let session = RankingEngine(itemID: item, orderedIDs: [], reaction: .fine)
        let cook = try CookingStore.create(draft: draft, session: session, context: context)
        let before = try CookingGraphExport.snapshot(context: context)
        await worker.retryNow(); #expect(worker.failed && events.isEmpty)
        #expect(try CookingGraphExport.snapshot(context: context) == before)
        worker.disconnect(); offline = false
        worker.connect(context: context, root: root, owner: owner, request: request, sync: nil)
        await worker.retryNow(); await worker.retryNow()
        #expect(events == [item] && completed == [origin] && worker.intents.isEmpty)
        #expect(try CookingGraphExport.snapshot(context: context) == before)
        #expect(cook.rankedItemID == item && list.items.count == 1 && list.comparisons.isEmpty)
        worker.disconnect()
    }
    @Test func switchingAccountDiscardsLateOriginReplyBeforeInvitation() async throws {
        let container = try ModelContainer(for: AppPersistence.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext, list = try CookingStore.prepare(context: context)
        var draft = CookingDraft(); draft.dishName = "Owner cook"
        let item = UUID(), session = RankingEngine(itemID: item, orderedIDs: list.orderedItems.map(\.id), reaction: .fine)
        _ = try CookingStore.create(draft: draft, session: session, context: context)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let worker = SharedCookingCoordinator(); var creates = 0
        worker.connect(context: context, root: root, owner: UUID(), request: { _, action, _ in
            if action == "complete" { worker.disconnect() } else { creates += 1 }
            return Data("{}".utf8)
        }, sync: nil)
        try worker.record(itemID: item, participants: [UUID()], originID: UUID()); await worker.retryNow()
        #expect(creates == 0 && worker.intents.isEmpty)
    }
    @Test func notificationUsesSafeCanonicalDestination() throws {
        let notice = SocialNotification(id: UUID(), kind: "comment", actor: .init(id: UUID(), displayName: "Friend", username: "friend", relationship: .friends), targetID: UUID(), postID: UUID(), createdAt: 100, read: false)
        let decoded = try JSONDecoder().decode(SocialNotification.self, from: JSONEncoder().encode(notice))
        #expect(decoded == notice && decoded.message == "commented on your cooking")
        let json = String(decoding: try JSONEncoder().encode(notice), as: UTF8.self)
        #expect(!json.contains("score") && !json.contains("notes") && !json.contains("photoPath"))
    }
    @Test func sourceAndJoinedCookUseIndependentRankingEvidence() throws {
        let a = try ModelContainer(for: AppPersistence.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let b = try ModelContainer(for: AppPersistence.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let source = try CookingStore.prepare(context: a.mainContext), recipient = try CookingStore.prepare(context: b.mainContext)
        func cook(_ name: String, list: RankingList, context: ModelContext) throws -> CookingAttempt {
            var draft = CookingDraft(); draft.dishName = name
            var session = RankingEngine(itemID: UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: .fine)
            while session.nextOpponent != nil { session.answer(.newItem) }
            return try CookingStore.create(draft: draft, session: session, context: context)
        }
        let original = try cook("Original cooking", list: source, context: a.mainContext)
        _ = try cook("Original second cook", list: source, context: a.mainContext)
        let before = try CookingGraphExport.snapshot(context: a.mainContext)
        _ = try cook("Recipient baseline", list: recipient, context: b.mainContext)
        let joined = try cook(original.dish!.name, list: recipient, context: b.mainContext)
        #expect(original.id != joined.id && original.rankedItemID != joined.rankedItemID)
        #expect(!recipient.comparisons.isEmpty && !source.comparisons.isEmpty)
        #expect(Set(source.comparisons.map(\.id)).isDisjoint(with: Set(recipient.comparisons.map(\.id))))
        #expect(try CookingGraphExport.snapshot(context: a.mainContext) == before)
        #expect(!ScoreUnlockPolicy.state(for: joined).isUnlocked)
    }
    @Test func resumingUnsavedOriginHonorsNewPrivateAndParticipantChoices() async throws {
        let container = try ModelContainer(for: AppPersistence.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext, list = try CookingStore.prepare(context: context)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), owner = UUID(), item = UUID(), origin = UUID(), peer = UUID()
        defer { try? FileManager.default.removeItem(at: root) }
        let review = SocialReview(), publication = SocialPublicationCoordinator(), shared = SharedCookingCoordinator()
        let request: SocialRequest = { endpoint, action, payload in
            if endpoint == "social_cooking" { return Data("{}".utf8) }
            return try await review.request(endpoint, action, payload)
        }
        publication.connect(context: context, root: root, accountID: owner, request: request, media: nil, sync: nil)
        shared.connect(context: context, root: root, owner: owner, request: request, sync: nil)
        publication.record(itemID: item, includePhoto: true)
        try shared.record(itemID: item, participants: [peer], originID: origin)
        await publication.retryNow(); await shared.retryNow()
        // No private save occurred; reopen the same origin and turn both sharing choices OFF.
        try publication.cancelUnsavedCreation(item)
        try shared.record(itemID: item, participants: [], originID: origin)
        #expect(shared.intents.first?.participants.isEmpty == true)
        var draft = CookingDraft(); draft.dishName = "Resumed privately"
        _ = try CookingStore.create(draft: draft, session: RankingEngine(itemID: item, orderedIDs: list.orderedItems.map(\.id), reaction: .fine), context: context)
        await publication.retryNow(); await shared.retryNow()
        #expect(review.posts.isEmpty && publication.intents.isEmpty && shared.intents.isEmpty)
        publication.disconnect(); shared.disconnect()
    }
    @Test func offlineInvitationCancellationSurvivesRelaunchWithoutSendingInvites() async throws {
        let container = try ModelContainer(for: AppPersistence.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext, list = try CookingStore.prepare(context: context), item = UUID()
        var draft = CookingDraft(); draft.dishName = "Saved privately"
        _ = try CookingStore.create(draft: draft, session: RankingEngine(itemID: item, orderedIDs: list.orderedItems.map(\.id), reaction: .fine), context: context)
        let before = try CookingGraphExport.snapshot(context: context)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), owner = UUID()
        defer { try? FileManager.default.removeItem(at: root) }
        var offline = true, creates = 0, cancels = 0
        let request: SocialRequest = { _, action, _ in
            if offline { throw URLError(.notConnectedToInternet) }
            if action == "create" { creates += 1 }; if action == "cancel" { cancels += 1 }
            return Data("{}".utf8)
        }
        let worker = SharedCookingCoordinator(); worker.connect(context: context, root: root, owner: owner, request: request, sync: nil)
        try worker.record(itemID: item, participants: [UUID()], originID: nil)
        await worker.retryNow(); await worker.cancelInvitations(item); await worker.retryNow()
        #expect(worker.intents.first?.cancelRequested == true)
        worker.disconnect(); offline = false
        worker.connect(context: context, root: root, owner: owner, request: request, sync: nil)
        await worker.retryNow()
        #expect(creates == 0 && cancels == 1 && worker.intents.isEmpty)
        #expect(try CookingGraphExport.snapshot(context: context) == before)
        worker.disconnect()
    }
}
#endif
