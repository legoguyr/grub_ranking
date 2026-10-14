import Foundation
import SwiftData
import Testing
@testable import StayGrubby

@MainActor struct CookingReRankingWorkflowTests {
    struct Fixture {
        let container: ModelContainer
        let context: ModelContext
        let list: RankingList
        let cooks: [CookingAttempt]
    }
    func fixture(_ count: Int) throws -> Fixture {
        let container = try ModelContainer(for: AppPersistence.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext, list = try CookingStore.prepare(context: container.mainContext)
        var cooks: [CookingAttempt] = []
        for n in 0..<count {
            var draft = CookingDraft(); draft.dishName = "Dish \(n)"
            var session = RankingEngine(itemID: UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: .fine)
            while session.nextOpponent != nil { session.answer(.newItem) }
            cooks.append(try CookingStore.create(draft: draft, session: session, context: context))
        }
        return Fixture(container: container, context: context, list: list, cooks: cooks)
    }
    @Test(arguments: InitialReaction.allCases, [1, 2, 9, 10, 30])
    func freshNormalSessionAutomaticallyEligibleToFinishWithoutDuplicating(reaction: InitialReaction, count: Int) throws {
        let f = try fixture(count); defer { withExtendedLifetime(f) {} }
        let cook = try #require(f.cooks.first), workflow = CookingReRankingWorkflow(attempt: cook)
        let old = Dictionary(uniqueKeysWithValues: f.list.comparisons.map { ($0.id, $0.evidence) })
        let dishes = try f.context.fetch(FetchDescriptor<Dish>()).map(\.id)
        let items = f.list.items.map(\.id), attempts = f.cooks.map(\.id)
        #expect(workflow.session == nil && !workflow.completed)
        try workflow.choose(reaction, context: f.context)
        #expect(workflow.session?.reaction == reaction)
        #expect(workflow.session?.itemID == cook.rankedItemID)
        #expect(workflow.session?.orderedIDs.contains(cook.rankedItemID) == false)
        let start = try CookingGraphExport.snapshot(context: f.context)
        while workflow.session?.nextOpponent != nil { workflow.answer(.newItem) }
        let fresh = try #require(workflow.session).evidence
        #expect(try CookingGraphExport.snapshot(context: f.context) == start)
        try workflow.finish(context: f.context)
        #expect(workflow.completed)
        #expect(workflow.completionSnapshot?.eligibleRankedEntryCount == count)
        #expect(f.list.comparisons.count == old.count + fresh.count)
        for (id, evidence) in old { #expect(f.list.comparisons.first { $0.id == id }?.evidence == evidence) }
        #expect(Set(f.list.items.map(\.id)) == Set(items))
        #expect(Set(try f.context.fetch(FetchDescriptor<Dish>()).map(\.id)) == Set(dishes))
        #expect(Set(try f.context.fetch(FetchDescriptor<CookingAttempt>()).map(\.id)) == Set(attempts))
        #expect(ScoreUnlockPolicy.state(in: f.context).rankedEntryCount == count)
        #expect((ShareCardModel.make(for: cook).scoreText != nil) == (count >= ScoreUnlockPolicy.requiredRankedEntryCount))
        let saved = try CookingGraphExport.snapshot(context: f.context)
        try workflow.finish(context: f.context)
        #expect(try CookingGraphExport.snapshot(context: f.context) == saved)
        let expected = BradleyTerryModel.analyze(ids: f.list.items.map(\.id), evidence: f.list.comparisons.map(\.evidence))
        for item in f.list.items { #expect(abs(item.strength - (expected.estimates[item.id]?.strength ?? .infinity)) < 1e-12) }
    }
    @Test func skipTieUndoAndCancellationKeepAllDraftEvidenceOffDisk() throws {
        let f = try fixture(12); defer { withExtendedLifetime(f) {} }
        let before = try CookingGraphExport.snapshot(context: f.context)
        let workflow = CookingReRankingWorkflow(attempt: try #require(f.cooks.first))
        try workflow.choose(.fine, context: f.context)
        let opponent = workflow.session?.nextOpponent
        workflow.answer(.skip)
        #expect(workflow.session?.evidence.isEmpty == true)
        workflow.undo(); #expect(workflow.session?.nextOpponent == opponent)
        let timestamp = Date(timeIntervalSinceReferenceDate: 100_000)
        workflow.answer(.tooTough, at: timestamp)
        #expect(workflow.session?.evidence.first?.outcome == 0.5)
        #expect(workflow.session?.evidence.first?.timestamp == timestamp)
        workflow.undo(); #expect(workflow.session?.nextOpponent == opponent)
        workflow.answer(.existingItem)
        #expect(try CookingGraphExport.snapshot(context: f.context) == before)
        #expect(!f.context.hasChanges)
        // Dropping the workflow is Cancel; no store transaction is started.
    }
    @Test func incompleteAndInvalidSessionsCannotCommit() throws {
        let f = try fixture(10); defer { withExtendedLifetime(f) {} }
        let workflow = CookingReRankingWorkflow(attempt: try #require(f.cooks.first))
        try workflow.choose(.liked, context: f.context)
        #expect(throws: (any Error).self) { try workflow.finish(context: f.context) }
        let before = try CookingGraphExport.snapshot(context: f.context)
        while workflow.session?.nextOpponent != nil { workflow.answer(.newItem) }
        let id = workflow.attempt.rankedItemID
        f.context.insert(SyncTombstone(SyncReference(entity: .rankedItem, key: id.uuidString.lowercased())))
        try f.context.save()
        #expect(throws: (any Error).self) { try workflow.finish(context: f.context) }
        #expect(f.list.comparisons.count == before.comparisons.count)
    }
    @Test func repeatedFreshSessionsCanMoveIntoAndOutOfFirstWithoutReplacingHistory() throws {
        let f = try fixture(10); defer { withExtendedLifetime(f) {} }
        let cook = try #require(f.cooks.first)
        let originalIDs = Set(f.list.comparisons.map(\.id))
        var promoted: RankingCompletionSnapshot?
        for _ in 0..<30 {
            let workflow = CookingReRankingWorkflow(attempt: cook); try workflow.choose(.liked, context: f.context)
            while workflow.session?.nextOpponent != nil { workflow.answer(.newItem) }
            try workflow.finish(context: f.context)
            if f.list.orderedItems.first?.id == cook.rankedItemID {
                promoted = workflow.completionSnapshot; break
            }
        }
        #expect(ShareCardModel.make(for: cook, event: try #require(promoted)).achievement == .newNumberOne)
        let leader = CookingReRankingWorkflow(attempt: cook); try leader.choose(.liked, context: f.context)
        while leader.session?.nextOpponent != nil { leader.answer(.newItem) }
        try leader.finish(context: f.context)
        #expect(ShareCardModel.make(for: cook, event: leader.completionSnapshot).achievement != .newNumberOne)
        for _ in 0..<30 where f.list.orderedItems.first?.id == cook.rankedItemID {
            let workflow = CookingReRankingWorkflow(attempt: cook); try workflow.choose(.disliked, context: f.context)
            while workflow.session?.nextOpponent != nil { workflow.answer(.existingItem) }
            try workflow.finish(context: f.context)
            #expect(ShareCardModel.make(for: cook, event: workflow.completionSnapshot).achievement != .newNumberOne)
        }
        #expect(f.list.orderedItems.first?.id != cook.rankedItemID)
        #expect(originalIDs.isSubset(of: Set(f.list.comparisons.map(\.id))))
        #expect(ScoreUnlockPolicy.state(in: f.context).rankedEntryCount == 10)
    }
    @Test func completedFreshSessionReloadsAndJournalsThroughExistingSyncPath() async throws {
        let f = try fixture(10); defer { withExtendedLifetime(f) {} }
        let owner = UUID(), root = FileManager.default.temporaryDirectory.appendingPathComponent("rerank-restore-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        var graph = try CookingGraphExport.snapshot(context: f.context); graph.accountID = owner
        var expected: CookingGraph?
        var selectedID: UUID?
        do {
            let store = try LocalStoreStartup.openAccount(owner, root: root); try store.restore(graph, revision: 1)
            let context = store.container.mainContext
            try SyncJournal.enable(context)
            let cook = try #require(context.fetch(FetchDescriptor<CookingAttempt>()).first)
            selectedID = cook.id
            let workflow = CookingReRankingWorkflow(attempt: cook); try workflow.choose(.fine, context: context)
            while workflow.session?.nextOpponent != nil { workflow.answer(.tooTough) }
            try workflow.finish(context: context)
            let pending = try SyncJournal.pending(context)
            #expect(pending.count == 1 && pending.first?.kind == "appendEvidence")
            expected = try CookingGraphExport.snapshot(context: context)
            #expect(expected?.attempts.count == 10 && expected?.items.count == 10)
            #expect(try #require(expected).comparisons.count > graph.comparisons.count)
            let transport = RerankLoopbackTransport(graph)
            try await SyncDispatcher().flush(context: context, transport: transport)
            #expect(try SyncJournal.pending(context).isEmpty)
            #expect(try SyncJournal.binding(context)?.acceptedRevision == 2)
            let synced = await transport.graph
            #expect(synced.canonicalized() == expected)
        }
        let reloaded = try LocalStoreStartup.openAccount(owner, root: root)
        #expect(try CookingGraphExport.snapshot(context: reloaded.container.mainContext) == expected)
        #expect(try reloaded.container.mainContext.fetch(FetchDescriptor<CookingAttempt>()).contains { $0.id == selectedID })
        #expect(ScoreUnlockPolicy.state(in: reloaded.container.mainContext).rankedEntryCount == 10)
    }
}

private actor RerankLoopbackTransport: SyncTransport {
    private(set) var graph: CookingGraph
    init(_ graph: CookingGraph) { self.graph = graph }
    func send(_ envelope: SyncEnvelope) async throws -> SyncReceipt {
        graph = try JSONDecoder().decode(SyncChanges.self, from: envelope.payload).applying(to: graph)
        return SyncReceipt(operationID: envelope.operationID, revision: 2)
    }
}
