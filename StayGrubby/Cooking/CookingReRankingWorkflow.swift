import Foundation
import SwiftData
import Observation

/// A fresh normal session targeting an existing entry. The generic engine and
/// evidence-append transaction remain authoritative; cancellation writes nothing.
@MainActor @Observable final class CookingReRankingWorkflow {
    let attempt: CookingAttempt
    private(set) var session: RankingEngine?
    private(set) var completed = false
    private(set) var completionSnapshot: RankingCompletionSnapshot?

    init(attempt: CookingAttempt) { self.attempt = attempt }
    func choose(_ reaction: InitialReaction, context: ModelContext) throws {
        guard session == nil, !completed, let list = attempt.rankedItem?.list,
              ScoreUnlockPolicy.entries(in: context, list: list).contains(where: { $0.attempt.id == attempt.id })
        else { throw CookingStore.StoreError.missingItem }
        session = RankingEngine(itemID: attempt.rankedItemID,
            orderedIDs: list.orderedItems.map(\.id).filter { $0 != attempt.rankedItemID }, reaction: reaction)
    }
    func answer(_ choice: ComparisonAnswer, at timestamp: Date = .now) { session?.answer(choice, at: timestamp) }
    func undo() { session?.undo() }
    func finish(context: ModelContext) throws {
        guard !completed else { return }
        guard let session, session.isComplete else { throw CookingStore.StoreError.incompleteSession }
        guard let list = attempt.rankedItem?.list,
              ScoreUnlockPolicy.entries(in: context, list: list).contains(where: { $0.attempt.id == attempt.id }),
              Set(session.orderedIDs) == Set(list.items.map(\.id).filter { $0 != attempt.rankedItemID })
        else { throw CookingStore.StoreError.missingItem }
        let before = RankingCompletionSnapshot.capture(from: list)
        try CookingStore.rerank(attempt, evidence: session.evidence, context: context)
        completionSnapshot = before
        completed = true
    }
}
