import Foundation
import SwiftData
import Testing
@testable import StayGrubby

private actor StructuredCloud: SyncTransport {
    let user: UUID
    let owner: UUID
    var graph: CookingGraph
    var revision = 1
    var receipts: [UUID: (SyncEnvelope, SyncReceipt)] = [:]
    var loseReply = false
    init(user: UUID, graph: CookingGraph) { self.user = user; owner = graph.accountID!; self.graph = graph }
    func loseNextReply() { loseReply = true }
    func send(_ envelope: SyncEnvelope) async throws -> SyncReceipt {
        guard envelope.accountID == owner, SyncJournal.digest(envelope.payload) == envelope.payloadHash else { throw CookingSyncError.rejected }
        if let (original, receipt) = receipts[envelope.operationID] {
            guard original == envelope else { throw CookingSyncError.rejected }; return receipt
        }
        let predecessor = envelope.predecessorID.flatMap { receipts[$0] }
        guard envelope.expectedRevision == revision ||
            (predecessor?.1.revision == revision && predecessor?.0.storeID == envelope.storeID && envelope.expectedRevision >= predecessor!.0.expectedRevision)
        else { throw CookingSyncError.conflict }
        graph = try JSONDecoder().decode(SyncChanges.self, from: envelope.payload).applying(to: graph)
        revision += 1
        let receipt = SyncReceipt(operationID: envelope.operationID, revision: revision)
        receipts[envelope.operationID] = (envelope, receipt)
        if loseReply { loseReply = false; throw URLError(.networkConnectionLost) }
        return receipt
    }
    func snapshot() -> AccountLibrarySnapshot {
        AccountLibrarySnapshot(account: ProvisionedAccount(formatVersion: 1, authUserID: user, accountID: owner,
            syncRevision: revision, libraryState: .initialized), graph: graph)
    }
    func count() -> Int { receipts.count }
}

private actor DelayedAcceptedTransport: SyncTransport {
    let cloud: StructuredCloud
    var reply: CheckedContinuation<Void, Never>?
    init(_ cloud: StructuredCloud) { self.cloud = cloud }
    func send(_ envelope: SyncEnvelope) async throws -> SyncReceipt {
        let receipt = try await cloud.send(envelope)
        await withCheckedContinuation { reply = $0 }
        return receipt
    }
    func isWaiting() -> Bool { reply != nil }
    func release() { reply?.resume(); reply = nil }
}

@MainActor struct StructuredCookingSyncTests {
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("structured-sync-\(UUID())") }
    private func empty(_ account: UUID) throws -> CookingGraph {
        let id = UUID()
        return try CookingGraph.decode(Data("""
        {"formatVersion":1,"accountID":"\(account)","deletions":[],"libraries":[{"key":"local","globalRankingID":"\(id)","bridgeVersion":1}],"rankings":[{"id":"\(id)","name":"My Cooking","createdAt":1000.1234567}],"dishes":[],"attempts":[],"items":[],"comparisons":[],"sources":[],"tags":[],"media":[],"legacyItemDates":[]}
        """.utf8))
    }
    private func device(_ graph: CookingGraph, root: URL) throws -> LocalStoreSession {
        let store = try LocalStoreStartup.openAccount(graph.accountID!, root: root)
        try store.restore(graph, revision: 1); try SyncJournal.enable(store.container.mainContext)
        return store
    }
    private func draft(_ name: String) -> CookingDraft {
        var value = CookingDraft(); value.dishName = name; value.versionTitle = "Transport version"
        value.cookedAt = Date(timeIntervalSinceReferenceDate: 812345678.1234567)
        value.notes = "Isolated sync fixture"; value.category = .main
        value.customTags = ["transport fixture"]
        value.dietary = [.vegetarian]; value.contains = [.milk]
        var source = DishSourceDraft(type: .cookbook); source.cookbookTitle = "Fixture Cookbook"
        source.cookbookAuthors = "Fixture author"; source.cookbookPage = "12"; value.source = source
        return value
    }
    private func create(_ context: ModelContext, _ name: String, dish: Dish? = nil) throws -> CookingAttempt {
        let list = try CookingStore.globalRanking(context: context)
        var engine = RankingEngine(itemID: UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: .liked)
        while engine.nextOpponent != nil { engine.answer(.newItem) }
        return try CookingStore.create(draft: draft(name), existingDish: dish, session: engine, context: context)
    }
    private func current(_ store: LocalStoreSession) throws -> CookingGraph {
        try CookingGraphExport.snapshot(context: store.container.mainContext).canonicalized()
    }
    private func restore(_ store: LocalStoreSession, _ cloud: StructuredCloud) async throws {
        let snapshot = await cloud.snapshot()
        try CookingGraphHydration.apply(snapshot.graph, revision: snapshot.account.syncRevision, context: store.container.mainContext)
    }
    @Test func twoDevicesCreateEditSourceTagsEvidenceMediaMetadataAndDeleteWithoutEcho() async throws {
        let owner = UUID(), user = UUID(), aRoot = root(), bRoot = root(), initial = try empty(owner)
        defer { try? FileManager.default.removeItem(at: aRoot); try? FileManager.default.removeItem(at: bRoot) }
        let cloud = StructuredCloud(user: user, graph: initial), a = try device(initial, root: aRoot)
        let context = a.container.mainContext
        let first = try create(context, "Fixture A"), second = try create(context, "Fixture B")
        let removedDishID = second.dish!.id, removedAttemptID = second.id
        _ = try create(context, "Fixture A", dish: first.dish)
        let baseline = try SyncJournal.begin(context)
        let metadata = CookingMedia(id: UUID(), displayFilename: "metadata-display.jpg", thumbnailFilename: "metadata-thumbnail.jpg", pixelWidth: 1200, pixelHeight: 800)
        context.insert(metadata); first.media.append(metadata)
        try SyncJournal.stage(baseline, kind: "mediaMetadata", context: context); try context.save()
        let sent = try SyncJournal.pending(context).map { SyncJournal.envelope($0) }
        #expect(sent.count == 4 && sent.allSatisfy { $0.expectedRevision == 1 })
        try await SyncDispatcher().flush(context: context, transport: cloud)
        #expect(try SyncJournal.pending(context).isEmpty)
        #expect(try SyncJournal.binding(context)?.acceptedSnapshotData != nil)
        let b = try LocalStoreStartup.openAccount(owner, root: bRoot)
        try await restore(b, cloud); try SyncJournal.enable(b.container.mainContext)
        #expect(try current(a) == current(b))
        let before = try current(b)
        try await restore(b, cloud)
        #expect(try current(b) == before && SyncJournal.pending(b.container.mainContext).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: b.mediaRoot!.appendingPathComponent("StayGrubbyMedia").path))
        let restored = try #require(b.container.mainContext.fetch(FetchDescriptor<CookingAttempt>()).first { $0.id == first.id })
        #expect(LocalPhotoStore.data(for: restored.primaryImage!, thumbnail: false, rootURL: b.mediaRoot) == nil)
        var edit = CookingDraft(attempt: restored); edit.dishName = "Renamed fixture"; edit.versionTitle = "Edited version"
        edit.notes = "Edited notes"; edit.category = .dessert; edit.customTags = ["new fixture tag"]
        edit.dietary = []; edit.contains = []
        var source = DishSourceDraft(type: .restaurant); source.restaurantName = "Fixture restaurant"; edit.source = source
        try CookingStore.edit(restored, draft: edit, context: b.container.mainContext)
        try await SyncDispatcher().flush(context: b.container.mainContext, transport: cloud)
        try await restore(a, cloud)
        #expect(try current(a) == current(b))
        #expect(Set(try current(a).comparisons.map(\.id)) == Set(before.comparisons.map(\.id)))
        let remove = try #require(context.fetch(FetchDescriptor<CookingAttempt>()).first { $0.id == second.id })
        try CookingStore.delete(remove, context: context)
        try await SyncDispatcher().flush(context: context, transport: cloud)
        try await restore(b, cloud); try await restore(b, cloud)
        #expect(try current(a) == current(b))
        #expect(try current(b).attempts.allSatisfy { $0.id != removedAttemptID })
        #expect(try current(b).deletions.contains { $0.entity == .dish && $0.key == removedDishID.uuidString })
        #expect(try SyncJournal.pending(b.container.mainContext).isEmpty)
    }
    @Test func ambiguousServerAcceptanceSurvivesRestartAndOfflineReentry() async throws {
        let base = root(), owner = UUID(), user = UUID(), initial = try empty(owner)
        defer { try? FileManager.default.removeItem(at: base) }
        let cloud = StructuredCloud(user: user, graph: initial)
        var original: SyncEnvelope!
        do {
            let a = try device(initial, root: base)
            _ = try create(a.container.mainContext, "Lost response fixture")
            original = SyncJournal.envelope(try #require(SyncJournal.pending(a.container.mainContext).first))
            await cloud.loseNextReply()
            do { try await SyncDispatcher().flush(context: a.container.mainContext, transport: cloud); Issue.record("Expected lost response") }
            catch { #expect(error is URLError) }
        }
        let snapshot = await cloud.snapshot(), access = AccountLibraryAccess()
        await access.prepare(snapshot.account, root: base, load: { snapshot })
        #expect(access.isReady(for: snapshot.account)) // Pending work never blocks ready-store entry.
        let store = try #require(access.store)
        #expect(SyncJournal.envelope(try #require(SyncJournal.pending(store.container.mainContext).first)) == original)
        try await SyncDispatcher().flush(context: store.container.mainContext, transport: cloud, now: .distantFuture)
        #expect(await cloud.count() == 1)
        #expect(try SyncJournal.pending(store.container.mainContext).isEmpty)
        await access.prepare(snapshot.account, root: base, offline: true, load: { Issue.record("Offline must not load"); return snapshot })
        #expect(access.offline && access.isReady(for: snapshot.account))
        #expect(try access.store!.container.mainContext.fetchCount(FetchDescriptor<Dish>()) == 1)
    }
    @Test func competingOfflineEditsFailClosedAndKeepDurableLocalChange() async throws {
        let owner = UUID(), initial = try empty(owner), aRoot = root(), bRoot = root()
        defer { try? FileManager.default.removeItem(at: aRoot); try? FileManager.default.removeItem(at: bRoot) }
        let cloud = StructuredCloud(user: UUID(), graph: initial), a = try device(initial, root: aRoot), b = try device(initial, root: bRoot)
        _ = try create(a.container.mainContext, "Accepted A")
        _ = try create(b.container.mainContext, "Pending B")
        let pending = SyncJournal.envelope(try #require(SyncJournal.pending(b.container.mainContext).first)), before = try current(b)
        try await SyncDispatcher().flush(context: a.container.mainContext, transport: cloud)
        do { try await SyncDispatcher().flush(context: b.container.mainContext, transport: cloud); Issue.record("Conflict must reject") }
        catch { #expect(error as? CookingSyncError == .conflict) }
        #expect(try current(b) == before)
        #expect(SyncJournal.envelope(try #require(SyncJournal.pending(b.container.mainContext).first)) == pending)
        #expect(try SyncJournal.pending(b.container.mainContext).first?.lastError == "revision-conflict")
        do { try await restore(b, cloud); Issue.record("Pending edits must block hydration") }
        catch { #expect(error as? SyncFoundationError == .pendingLocalChanges) }
    }
    @Test(arguments: ["operation", "store", "owner", "hash", "revision"])
    func forgedAcknowledgmentsCannotClearOutbox(_ field: String) throws {
        let envelope = SyncEnvelope(operationID: UUID(), storeID: UUID(), accountID: UUID(), kind: "createCook", payload: Data(), payloadHash: "hash", expectedRevision: 1)
        let receipt = CookingOperationReceipt(operationID: field == "operation" ? UUID() : envelope.operationID,
            storeID: field == "store" ? UUID() : envelope.storeID, accountID: field == "owner" ? UUID() : envelope.accountID,
            payloadHash: field == "hash" ? "other" : envelope.payloadHash, revision: field == "revision" ? 1 : 2)
        #expect(throws: SyncFoundationError.self) { try receipt.validated(for: envelope) }
    }
    @Test func guestDemoAndWrongOwnerCannotConnectTransportOrConstructAuth() async throws {
        let base = root(), owner = UUID(), initial = try empty(owner)
        defer { try? FileManager.default.removeItem(at: base) }
        let guest = try LocalStoreSession.open(.guest, root: base), account = ProvisionedAccount(formatVersion: 1, authUserID: UUID(), accountID: owner, syncRevision: 1, libraryState: .initialized)
        let cloud = StructuredCloud(user: account.authUserID, graph: initial), sync = CookingSyncCoordinator()
        #expect(throws: SyncFoundationError.self) {
            try sync.connect(store: guest, account: account, send: { try await cloud.send($0) }, load: { await cloud.snapshot() })
        }
        var backendCreations = 0
        let session = AccountSessionCoordinator(backendFactory: { backendCreations += 1; throw CookingSyncError.unavailable })
        #if DEBUG
        #expect(session.beginDevelopmentReview())
        #endif
        let envelope = SyncEnvelope(operationID: UUID(), storeID: UUID(), accountID: owner, kind: "createCook", payload: Data(), payloadHash: "hash", expectedRevision: 1)
        do { _ = try await session.applyResolvedOperation(envelope); Issue.record("Logged-out/demo cannot upload") }
        catch { #expect(error as? CookingSyncError == .authenticationRequired) }
        #expect(backendCreations == 0)
    }
    @Test func incomingHydrationWaitsForDetailOrDraftLifetime() async throws {
        let base = root(), owner = UUID(), initial = try empty(owner), user = UUID()
        defer { try? FileManager.default.removeItem(at: base) }
        let local = try device(initial, root: base), remoteRoot = root(), remote = try device(initial, root: remoteRoot)
        defer { try? FileManager.default.removeItem(at: remoteRoot) }
        _ = try create(remote.container.mainContext, "Remote while editing")
        let cloud = StructuredCloud(user: user, graph: initial)
        try await SyncDispatcher().flush(context: remote.container.mainContext, transport: cloud)
        let account = (await cloud.snapshot()).account, sync = CookingSyncCoordinator(), hold = UUID()
        try sync.connect(store: local, account: account, send: { try await cloud.send($0) }, load: { await cloud.snapshot() })
        sync.hold(hold)
        try await Task.sleep(for: .milliseconds(700))
        #expect(try local.container.mainContext.fetchCount(FetchDescriptor<Dish>()) == 0)
        sync.release(hold)
        for _ in 0..<100 {
            if sync.status == .current { break }; try await Task.sleep(for: .milliseconds(20))
        }
        #expect(sync.status == .current)
        #expect(try local.container.mainContext.fetchCount(FetchDescriptor<Dish>()) == 1)
        sync.disconnect()
    }
    @Test func cancelledAccountWorkerCannotAcknowledgeOrMountAnotherAccountsData() async throws {
        let aRoot = root(), bRoot = root(), ownerA = UUID(), ownerB = UUID(), userA = UUID(), userB = UUID()
        defer { try? FileManager.default.removeItem(at: aRoot); try? FileManager.default.removeItem(at: bRoot) }
        let graphA = try empty(ownerA), graphB = try empty(ownerB)
        let a = try device(graphA, root: aRoot), b = try device(graphB, root: bRoot)
        let cloudA = StructuredCloud(user: userA, graph: graphA), cloudB = StructuredCloud(user: userB, graph: graphB)
        let delayed = DelayedAcceptedTransport(cloudA), sync = CookingSyncCoordinator()
        _ = try create(a.container.mainContext, "Account A delayed receipt")
        let accountA = (await cloudA.snapshot()).account, accountB = (await cloudB.snapshot()).account
        let token = try sync.connect(store: a, account: accountA, send: { try await delayed.send($0) }, load: { await cloudA.snapshot() })
        for _ in 0..<100 { if await delayed.isWaiting() { break }; try await Task.sleep(for: .milliseconds(20)) }
        #expect(await delayed.isWaiting())
        sync.disconnect(token)
        try sync.connect(store: b, account: accountB, send: { try await cloudB.send($0) }, load: { await cloudB.snapshot() })
        await delayed.release()
        try await Task.sleep(for: .milliseconds(600))
        #expect(try SyncJournal.pending(ModelContext(a.container)).count == 1)
        #expect(try b.container.mainContext.fetchCount(FetchDescriptor<Dish>()) == 0)
        #expect(await cloudA.count() == 1)
        #expect(await cloudB.count() == 0)
        sync.disconnect()
        try await SyncDispatcher().flush(context: a.container.mainContext, transport: cloudA, now: .distantFuture)
        #expect(try SyncJournal.pending(ModelContext(a.container)).isEmpty)
        #expect(await cloudA.count() == 1)
    }
    @Test func outboxWrongAccountOrDamagedPayloadNeverReachesTransport() async throws {
        let base = root(), owner = UUID(), graph = try empty(owner)
        defer { try? FileManager.default.removeItem(at: base) }
        let store = try device(graph, root: base), cloud = StructuredCloud(user: UUID(), graph: graph)
        _ = try create(store.container.mainContext, "Corrupt outbox fixture")
        let operation = try #require(SyncJournal.pending(store.container.mainContext).first)
        operation.accountID = UUID(); try store.container.mainContext.save()
        do { try await SyncDispatcher().flush(context: store.container.mainContext, transport: cloud); Issue.record("Wrong-account outbox must reject before transport") }
        catch { #expect(error as? SyncFoundationError == .wrongAccount) }
        #expect(await cloud.count() == 0)
        operation.accountID = owner; operation.payloadHash = "damaged"; try store.container.mainContext.save()
        do { try await SyncDispatcher().flush(context: store.container.mainContext, transport: cloud); Issue.record("Damaged outbox must reject") }
        catch { #expect(error as? SyncFoundationError == .wrongAccount) }
        #expect(await cloud.count() == 0)
    }
    #if DEBUG
    @Test func scratchRestoreCheckPreservesExactGraphAndCannotGenerateWork() async throws {
        let base = root(), owner = UUID(), user = UUID(), graph = try empty(owner)
        defer { try? FileManager.default.removeItem(at: base) }
        let a = try device(graph, root: base), cloud = StructuredCloud(user: user, graph: graph)
        _ = try create(a.container.mainContext, "Scratch verification fixture")
        try await SyncDispatcher().flush(context: a.container.mainContext, transport: cloud)
        let snapshot = await cloud.snapshot(), before = try current(a)
        let result = try FreshCookingRestoreCheck.verify(snapshot, for: snapshot.account)
        #expect(result.dishes == 1 && result.attempts == 1)
        #expect(result.digest == SyncJournal.digest(try snapshot.graph.canonicalized().encoded()))
        #expect(try current(a) == before && SyncJournal.pending(a.container.mainContext).isEmpty)
        var wrong = snapshot.account
        wrong = ProvisionedAccount(formatVersion: 1, authUserID: user, accountID: UUID(), syncRevision: 1, libraryState: .initialized)
        #expect(throws: AccountFoundationError.self) { try FreshCookingRestoreCheck.verify(snapshot, for: wrong) }
    }
    #endif
    @Test func restoreLeaseReleasesOnlyAtLifetimeEnd() async throws {
        let sync = CookingSyncCoordinator(), token = UUID()
        sync.hold(token)
        var lease: CookingRestoreLease? = CookingRestoreLease { Task { @MainActor in sync.release(token) } }
        var retained = lease
        lease = nil
        #expect(sync.hasActiveRestoreLease)
        #expect(retained != nil)
        retained = nil
        for _ in 0..<100 { if !sync.hasActiveRestoreLease { break }; await Task.yield() }
        #expect(!sync.hasActiveRestoreLease)
    }
    @Test func exportsActualSwiftWireOperationsForSQLInteroperability() throws {
        let owner = UUID(), base = root(), initial = try empty(owner), store = try device(initial, root: base)
        defer { try? FileManager.default.removeItem(at: base) }
        let context = store.container.mainContext
        var steps: [CookingGraph] = []
        let first = try create(context, "SQL wire fixture A"); steps.append(try current(store))
        let second = try create(context, "SQL wire fixture B"); steps.append(try current(store))
        _ = try create(context, "SQL wire fixture A", dish: first.dish); steps.append(try current(store))
        let baseline = try SyncJournal.begin(context)
        let metadata = CookingMedia(id: UUID(), displayFilename: "wire-display.jpg", thumbnailFilename: "wire-thumbnail.jpg", pixelWidth: 1200, pixelHeight: 800)
        context.insert(metadata); first.media.append(metadata)
        first.dish?.source?.socialURL = "https://example.com/fixture?x=1&y=2"
        first.dish?.source?.onlineURL = "https://example.com/recipe"
        first.dish?.source?.friendNote = "Hidden nullable-field fixture"
        try SyncJournal.stage(baseline, kind: "mediaMetadata", context: context); try context.save(); steps.append(try current(store))
        var edit = CookingDraft(attempt: first); edit.dishName = "Edited wire fixture"; edit.versionTitle = "Wire edited version"
        edit.notes = "Transport SQL edit"; edit.category = .dessert
        edit.dietary = Set(DietaryTag.allCases); edit.contains = Set(Allergen.allCases)
        edit.allergy = Set(AllergyTag.allCases); edit.customTags = ["wire updated tag"]
        try CookingStore.edit(first, draft: edit, context: context); steps.append(try current(store))
        try CookingStore.delete(second, context: context); steps.append(try current(store))
        struct Fixture: Encodable { let initial: CookingGraph; let operations: [SyncEnvelope]; let steps: [CookingGraph]; let expected: CookingGraph }
        let fixture = Fixture(initial: initial, operations: try SyncJournal.pending(context).map { SyncJournal.envelope($0) }, steps: steps, expected: try current(store))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("staygrubby-3d-swift-wire.json")
        try encoder.encode(fixture).write(to: destination)
        #expect(fixture.operations.count == 6 && steps.count == 6)
    }
}
