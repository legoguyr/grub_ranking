import Foundation
import SwiftData
import Testing
@testable import Grub_Ranked

private actor ReceiptTransport: SyncTransport {
    var receipts: [UUID: (SyncEnvelope, SyncReceipt)] = [:]
    var loseFirstReply: Bool
    init(loseFirstReply: Bool = false) { self.loseFirstReply = loseFirstReply }
    func send(_ envelope: SyncEnvelope) async throws -> SyncReceipt {
        #expect(SyncJournal.digest(envelope.payload) == envelope.payloadHash)
        if let (original, receipt) = receipts[envelope.operationID] {
            #expect(original == envelope); return receipt
        }
        let receipt = SyncReceipt(operationID: envelope.operationID, revision: receipts.count + 1)
        receipts[envelope.operationID] = (envelope, receipt)
        if loseFirstReply { loseFirstReply = false; throw URLError(.networkConnectionLost) }
        return receipt
    }
    func count() -> Int { receipts.count }
}

@MainActor struct SyncFoundationTests {
    private func memory(account: UUID? = nil) throws -> ModelContainer {
        let container = try ModelContainer(for: AppPersistence.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        if let account { container.mainContext.insert(SyncStoreBinding(accountID: account, restorationRequired: false)); try container.mainContext.save() }
        return container
    }
    private func draft(_ name: String = "Harissa Chicken") -> CookingDraft {
        var value = CookingDraft(); value.dishName = name; value.versionTitle = "Sunday sear"
        value.cookedAt = Date(timeIntervalSinceReferenceDate: 812_345_678.1234567)
        value.category = .main; value.dietary = Set(DietaryTag.allCases)
        value.contains = Set(Allergen.allCases); value.allergy = Set(AllergyTag.allCases)
        value.customTags = ["Family Favorite", "Weeknight"]
        var source = DishSourceDraft(type: .cookbook)
        source.cookbookTitle = "Zahav"; source.cookbookAuthors = "Illustrative author"
        source.cookbookPage = "27"; source.cookbookRecipeName = "Kabobs"
        value.source = source; value.notes = "Less salt next time"
        return value
    }
    @discardableResult private func create(_ context: ModelContext, _ value: CookingDraft, dish: Dish? = nil) throws -> CookingAttempt {
        let list = try CookingStore.globalRanking(context: context)
        var session = RankingEngine(itemID: UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: .liked)
        while session.nextOpponent != nil { session.answer(.newItem) }
        return try CookingStore.create(draft: value, existingDish: dish, session: session, context: context)
    }
    private func fixture(account: UUID? = nil) throws -> ModelContainer {
        let container = try memory(account: account); let context = container.mainContext
        let list = try CookingStore.prepare(context: context)
        let first = try create(context, draft())
        _ = try create(context, draft("Lemon Cake"))
        _ = try create(context, CookingDraft(dish: first.dish!), dish: first.dish)
        let ids = list.items.map(\.id)
        try RankingStore.record([1.0, 0.0, 0.5].enumerated().map { index, outcome in
            PreferenceEvidence(first: ids[0], second: ids[1], outcome: outcome,
                timestamp: Date(timeIntervalSinceReferenceDate: 800_000_000.1234567 + Double(index)))
        }, in: list, context: context)
        // Metadata-only local fixture; hydration transfers metadata, never accesses image bytes.
        let image = CookingMedia(id: UUID(), displayFilename: "fixture-display.jpg", thumbnailFilename: "fixture-thumbnail.jpg", pixelWidth: 1200, pixelHeight: 800)
        context.insert(image); first.media.append(image)
        first.dish?.source?.socialCreator = "Hidden legacy creator"
        first.dish?.source?.socialURL = "https://example.com/original?x=1&y=2"
        first.dish?.source?.friendNote = "Hidden legacy note"
        context.insert(Item(timestamp: Date(timeIntervalSinceReferenceDate: 42.1234567)))
        try context.save()
        return container
    }
    private func acknowledgeAll(_ context: ModelContext) throws {
        for operation in try SyncJournal.pending(context) {
            let next = (try SyncJournal.binding(context)!.acceptedRevision) + 1
            try SyncJournal.acknowledge(SyncJournal.envelope(operation), revision: max(0, next), context: context)
        }
    }

    @Test func guestInitializationRemainsIdempotentAndSyncDisabled() throws {
        let container = try LocalStoreStartup.openGuest(overrideURL: FileManager.default.temporaryDirectory.appendingPathComponent("guest-\(UUID()).store"))
        let context = container.mainContext
        let first = try CookingStore.prepare(context: context)
        #expect(try CookingStore.prepare(context: context).id == first.id)
        _ = try create(context, draft())
        #expect(try SyncJournal.binding(context) == nil)
        #expect(try SyncJournal.pending(context).isEmpty)
    }
    @Test func accountIsolationAndRestorationGateSurviveReopen() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("accounts-\(UUID())")
        let a = UUID(), b = UUID()
        let first = try LocalStoreStartup.openAccount(a, root: root)
        #expect(throws: SyncFoundationError.self) { try first.prepare() }
        #expect(try first.container.mainContext.fetchCount(FetchDescriptor<RankingList>()) == 0)
        try first.initializeVerifiedEmptyAccount()
        _ = try create(first.container.mainContext, draft("Account A meal"))
        let second = try LocalStoreStartup.openAccount(b, root: root)
        #expect(throws: SyncFoundationError.self) { try second.prepare() }
        #expect(try second.container.mainContext.fetchCount(FetchDescriptor<Dish>()) == 0)
        #expect(first.mediaRoot != second.mediaRoot)
        let reopened = try LocalStoreStartup.openAccount(a, root: root)
        #expect(try reopened.prepare().items.count == 1)
        #expect(try SyncJournal.binding(reopened.container.mainContext)?.accountID == a)
        #expect(try reopened.container.mainContext.fetchCount(FetchDescriptor<RankingList>()) == 1)
    }
    @Test func losslessRoundTripPreservesIDsEvidenceCachesTagsSourcesDatesAndMedia() throws {
        let original = try fixture(); let context = original.mainContext
        let graph = try CookingGraphExport.snapshot(context: context)
        try graph.validate()
        let decoded = try CookingGraph.decode(graph.encoded())
        #expect(decoded == graph)
        let restored = try memory(); let target = restored.mainContext
        try CookingGraphHydration.apply(decoded, revision: 0, context: target)
        #expect(try CookingGraphExport.snapshot(context: target) == graph)
        let first = try CookingStore.globalRanking(context: context), second = try CookingStore.globalRanking(context: target)
        #expect(first.orderedItems.map(\.id) == second.orderedItems.map(\.id))
        #expect(first.orderedItems.map(\.score) == second.orderedItems.map(\.score))
        #expect(Set(first.comparisons.map(\.id)) == Set(second.comparisons.map(\.id)))
        #expect(first.comparisons.count == second.comparisons.count && second.comparisons.contains { $0.isTie })
        #expect(graph.sources.contains { $0.socialCreator == "Hidden legacy creator" })
        #expect(graph.media.count == 1 && graph.tags.contains { $0.kindCode == "contains" })
        #expect(graph.attempts.first?.createdAt.timeIntervalSinceReferenceDate.bitPattern == decoded.attempts.first?.createdAt.timeIntervalSinceReferenceDate.bitPattern)
        #expect(try SyncJournal.pending(target).isEmpty)
    }
    @Test func repeatedHydrationKeepsObjectIdentityAndGeneratesNoUpload() throws {
        let account = UUID(); let source = try fixture(account: account); let graph = try CookingGraphExport.snapshot(context: source.mainContext)
        let destination = try memory(account: account); let target = destination.mainContext
        try CookingGraphHydration.apply(graph, revision: 4, context: target)
        try SyncJournal.enable(target)
        let dish = try #require(target.fetch(FetchDescriptor<Dish>()).first)
        try CookingGraphHydration.apply(graph, revision: 4, context: target)
        #expect(try target.fetch(FetchDescriptor<Dish>()).contains { $0 === dish })
        #expect(try SyncJournal.pending(target).isEmpty)
        #expect(try CookingGraphExport.snapshot(context: target) == graph)
        var changed = graph; changed.dishes[0].name = "Accepted rename"
        try CookingGraphHydration.apply(changed, revision: 5, context: target)
        #expect(try CookingGraphExport.snapshot(context: target) == changed)
        #expect(try SyncJournal.pending(target).isEmpty)
        #expect(throws: SyncFoundationError.self) { try CookingGraphHydration.apply(graph, revision: 5, context: target) }
    }
    @Test func localMutationsJournalExactlyOnceAndKeepRankingSemantics() throws {
        let container = try memory(account: UUID()); let context = container.mainContext
        let list = try CookingStore.prepare(context: context); try SyncJournal.enable(context)
        let first = try create(context, draft()); let second = try create(context, draft("Lamb"))
        _ = try create(context, CookingDraft(dish: first.dish!), dish: first.dish)
        var edit = CookingDraft(attempt: first); edit.notes = "Changed locally"
        let scores = Dictionary(uniqueKeysWithValues: list.items.map { ($0.id, [$0.strength, $0.uncertainty]) })
        let order = list.orderedItems.map(\.id), evidence = Set(list.comparisons.map(\.id))
        try CookingStore.edit(first, draft: edit, context: context)
        #expect(scores == Dictionary(uniqueKeysWithValues: list.items.map { ($0.id, [$0.strength, $0.uncertainty]) }))
        #expect(order == list.orderedItems.map(\.id))
        #expect(evidence == Set(list.comparisons.map(\.id)))
        try CookingStore.rerank(first, evidence: [PreferenceEvidence(first: first.rankedItemID, second: second.rankedItemID, outcome: 0.5)], context: context)
        try CookingStore.delete(second, context: context)
        let operations = try SyncJournal.pending(context)
        #expect(operations.map(\.kind) == ["createCook", "createCook", "createCook", "editCook", "appendEvidence", "deleteCook"])
        #expect(Set(operations.map(\.id)).count == 6)
        #expect(operations[1].predecessorID == operations[0].id)
        let additions = try JSONDecoder().decode(SyncChanges.self, from: operations[4].payload)
        #expect(additions.upserts.filter { $0.reference.entity == .comparison }.count == 1)
        #expect(try context.fetchCount(FetchDescriptor<RankingList>()) == 1)
    }
    @Test func abandonedIncompleteRankingWritesNoModelsOrOperations() throws {
        let container = try memory(account: UUID()); let context = container.mainContext
        let list = try CookingStore.prepare(context: context); _ = try create(context, draft())
        try SyncJournal.enable(context)
        let session = RankingEngine(itemID: UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: .liked)
        #expect(!session.isComplete)
        #expect(throws: CookingStore.StoreError.self) { try CookingStore.create(draft: draft("Abandoned"), session: session, context: context) }
        #expect(list.items.count == 1)
        #expect(try SyncJournal.pending(context).isEmpty)
    }
    @Test func journalAndDomainChangesRollbackTogether() throws {
        let container = try fixture(account: UUID()); let context = container.mainContext
        try SyncJournal.enable(context); let before = try CookingGraphExport.snapshot(context: context)
        let baseline = try SyncJournal.begin(context)
        let orphan = DishSource(type: .other); context.insert(orphan)
        #expect(throws: SyncFoundationError.self) { try SyncJournal.stage(baseline, kind: "invalidFixture", context: context) }
        context.rollback()
        #expect(try CookingGraphExport.snapshot(context: context) == before)
        #expect(try SyncJournal.pending(context).isEmpty)
    }
    @Test func pendingWorkAndAcknowledgedTombstonesPreventResurrection() throws {
        let container = try fixture(account: UUID()); let context = container.mainContext
        let old = try CookingGraphExport.snapshot(context: context); try SyncJournal.enable(context)
        let cook = try #require(context.fetch(FetchDescriptor<CookingAttempt>()).first)
        let removedItem = cook.rankedItemID
        try CookingStore.delete(cook, context: context)
        #expect(throws: SyncFoundationError.self) { try CookingGraphHydration.apply(old, revision: 10, context: context) }
        try acknowledgeAll(context)
        #expect(try context.fetch(FetchDescriptor<SyncTombstone>()).contains { $0.entityKey == removedItem.uuidString })
        #expect(throws: SyncFoundationError.self) { try CookingGraphHydration.apply(old, revision: 10, context: context) }
        #expect(try context.fetch(FetchDescriptor<RankedItem>()).allSatisfy { $0.id != removedItem })
    }
    @Test func outboxAndDeletionSurviveDiskReopen() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("outbox-\(UUID())"); let account = UUID()
        var operationIDs: [UUID] = []; var deleted: UUID!
        do {
            let session = try LocalStoreSession.open(.account(account), root: root); try session.initializeVerifiedEmptyAccount()
            let context = session.container.mainContext; try SyncJournal.enable(context)
            let cook = try create(context, draft()); deleted = cook.id
            try CookingStore.delete(cook, context: context)
            operationIDs = try SyncJournal.pending(context).map(\.id)
        }
        let session = try LocalStoreSession.open(.account(account), root: root); let context = session.container.mainContext
        #expect(try SyncJournal.pending(context).map(\.id) == operationIDs)
        #expect(try context.fetch(FetchDescriptor<SyncTombstone>()).contains { $0.entityKey == deleted.uuidString })
        #expect(try session.prepare().items.isEmpty)
        try acknowledgeAll(context)
        let replay = try context.fetch(FetchDescriptor<SyncOperation>()).sorted { $0.sequence < $1.sequence }
        let receipt = SyncJournal.envelope(replay[0]); let accepted = replay[0].acknowledgedRevision!
        try SyncJournal.acknowledge(receipt, revision: accepted, context: context)
        #expect(try SyncJournal.pending(context).isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<SyncTombstone>()) > 0)
    }
    @Test func lostAcknowledgmentRetriesSameUUIDAndPayloadAfterReopen() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("retry-\(UUID())"); let account = UUID()
        let transport = ReceiptTransport(loseFirstReply: true)
        var envelope: SyncEnvelope!
        do {
            let session = try LocalStoreSession.open(.account(account), root: root); try session.initializeVerifiedEmptyAccount()
            let context = session.container.mainContext; try SyncJournal.enable(context); _ = try create(context, draft())
            envelope = SyncJournal.envelope(try #require(SyncJournal.pending(context).first))
            do { try await SyncDispatcher().flush(context: context, transport: transport); Issue.record("Expected simulated lost reply") }
            catch { #expect(error is URLError) }
            #expect(try SyncJournal.pending(ModelContext(session.container)).first?.lastError != nil)
        }
        let session = try LocalStoreSession.open(.account(account), root: root); let context = session.container.mainContext
        #expect(SyncJournal.envelope(try #require(SyncJournal.pending(context).first)) == envelope)
        try await SyncDispatcher().flush(context: context, transport: transport, now: .distantFuture)
        #expect(await transport.count() == 1)
        #expect(try SyncJournal.pending(context).isEmpty)
    }
    @Test(arguments: ["owner", "duplicate", "endpoint", "winner", "path", "stale"])
    func invalidRemoteGraphsAreRejectedWithoutChangingTheStore(_ corruption: String) throws {
        let account = UUID(); let container = try fixture(account: account); let context = container.mainContext
        let before = try CookingGraphExport.snapshot(context: context)
        try CookingGraphHydration.apply(before, revision: 3, context: context)
        var invalid = before; var revision = 4
        switch corruption {
        case "owner": invalid.accountID = UUID()
        case "duplicate": invalid.comparisons.append(invalid.comparisons[0])
        case "endpoint": invalid.comparisons[0].firstItemID = UUID()
        case "winner": invalid.comparisons[0].isTie = false; invalid.comparisons[0].preferredItemID = UUID()
        case "path": invalid.media[0].displayFilename = "/tmp/private-photo.jpg"
        default: revision = 2
        }
        #expect(throws: SyncFoundationError.self) { try CookingGraphHydration.apply(invalid, revision: revision, context: context) }
        #expect(try CookingGraphExport.snapshot(context: context) == before)
        #expect(!context.hasChanges)
    }
    @Test func restorationDoesNotInitializeADuplicateRanking() throws {
        let account = UUID(); let source = try fixture(account: account)
        let graph = try CookingGraphExport.snapshot(context: source.mainContext)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("restore-\(UUID())")
        let target = try LocalStoreStartup.openAccount(account, root: root)
        #expect(throws: SyncFoundationError.self) { try CookingStore.prepare(context: target.container.mainContext) }
        try target.restore(graph, revision: 7)
        #expect(try target.prepare().id == graph.libraries[0].globalRankingID)
        #expect(try target.container.mainContext.fetchCount(FetchDescriptor<RankingList>()) == 1)
        #expect(try SyncJournal.pending(target.container.mainContext).isEmpty)
    }
    @Test func mediaRootsIsolateEvenIdenticalLogicalMediaIDs() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("media-\(UUID())")
        let a = LocalStoreLayout.resolve(.account(UUID()), root: root), b = LocalStoreLayout.resolve(.account(UUID()), root: root)
        #expect(LocalStoreLayout.resolve(.guest, root: root).databaseURL == nil)
        let id = UUID()
        let first = try LocalPhotoStore.write(PreparedCookingPhoto(id: id, displayData: Data("A".utf8), thumbnailData: Data("a".utf8), pixelWidth: 10, pixelHeight: 10), rootURL: a.mediaRoot)
        let second = try LocalPhotoStore.write(PreparedCookingPhoto(id: id, displayData: Data("B".utf8), thumbnailData: Data("b".utf8), pixelWidth: 10, pixelHeight: 10), rootURL: b.mediaRoot)
        #expect(first.id == second.id)
        #expect(LocalPhotoStore.data(for: first, thumbnail: false, rootURL: a.mediaRoot) == Data("A".utf8))
        #expect(LocalPhotoStore.data(for: second, thumbnail: false, rootURL: b.mediaRoot) == Data("B".utf8))
    }
    @Test func allSourceCodesAndNullableLegacyFieldsTransferWithoutConversion() throws {
        let original = try memory(); let context = original.mainContext
        try CookingStore.prepare(context: context)
        for type in DishSourceType.allCases {
            var value = draft(type.rawValue); value.source = DishSourceDraft(type: type)
            let cook = try create(context, value)
            cook.dish?.source?.restaurantLocation = "Legacy location"
            cook.dish?.source?.socialPlatform = "Legacy platform"
            cook.dish?.source?.otherDetails = "Preserved hidden details"
        }
        try context.save()
        let graph = try CookingGraphExport.snapshot(context: context)
        let restored = try memory(); try CookingGraphHydration.apply(graph, revision: 0, context: restored.mainContext)
        #expect(try CookingGraphExport.snapshot(context: restored.mainContext) == graph)
        #expect(Set(graph.sources.map(\.typeCode)) == Set(DishSourceType.allCases.map(\.rawValue)))
        #expect(graph.sources.allSatisfy { $0.otherDetails == "Preserved hidden details" })
    }
    @Test func remoteDeletionAppliesWithoutEchoAndRetainsAnAntiResurrectionMarker() throws {
        let account = UUID(); let source = try fixture(account: account)
        let initial = try CookingGraphExport.snapshot(context: source.mainContext)
        let target = try memory(account: account); let context = target.mainContext
        try CookingGraphHydration.apply(initial, revision: 1, context: context); try SyncJournal.enable(context)
        let cook = try #require(source.mainContext.fetch(FetchDescriptor<CookingAttempt>()).first)
        let removed = cook.id
        try CookingStore.delete(cook, context: source.mainContext)
        var remote = try CookingGraphExport.snapshot(context: source.mainContext)
        let remaining = Set(try remote.records().map { $0.reference.identity })
        remote.deletions = try initial.records().map(\.reference).filter { !remaining.contains($0.identity) }.sorted { $0.identity < $1.identity }
        try CookingGraphHydration.apply(remote, revision: 2, context: context)
        #expect(try SyncJournal.pending(context).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CookingAttempt>()).allSatisfy { $0.id != removed })
        #expect(try CookingGraphExport.snapshot(context: context) == remote)
        #expect(throws: SyncFoundationError.self) { try CookingGraphHydration.apply(initial, revision: 3, context: context) }
    }
    @Test func wrongAcknowledgmentAndOutOfOrderReceiptsAreRejected() throws {
        let container = try memory(account: UUID()); let context = container.mainContext
        try CookingStore.prepare(context: context); try SyncJournal.enable(context)
        _ = try create(context, draft()); _ = try create(context, draft("Soup"))
        let pending = try SyncJournal.pending(context)
        var forged = SyncJournal.envelope(pending[0]); forged.accountID = UUID()
        #expect(throws: SyncFoundationError.self) { try SyncJournal.acknowledge(forged, revision: 1, context: context) }
        #expect(throws: SyncFoundationError.self) { try SyncJournal.acknowledge(SyncJournal.envelope(pending[1]), revision: 2, context: context) }
        #expect(try SyncJournal.pending(context).count == 2)
        #expect(!context.hasChanges)
    }
    @Test func dispatcherFailureDoesNotRollbackOtherContextsUnsavedWork() async throws {
        let container = try memory(account: UUID()); let context = container.mainContext
        try CookingStore.prepare(context: context); try SyncJournal.enable(context)
        let cook = try create(context, draft())
        cook.notes = "Uncommitted caller work"
        do { try await SyncDispatcher().flush(context: context, transport: ReceiptTransport(loseFirstReply: true)) }
        catch { #expect(error is URLError) }
        #expect(cook.notes == "Uncommitted caller work" && context.hasChanges)
        context.rollback()
    }

}
