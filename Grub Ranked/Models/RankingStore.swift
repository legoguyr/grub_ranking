import Foundation
import SwiftData

/// Commits a completed session atomically. Drafts and skipped questions never enter the store.
@MainActor
enum RankingStore {
    static func save(name: String, session: RankingEngine, to list: RankingList, context: ModelContext) throws {
        let baseline = try SyncJournal.begin(context)
        do {
            _ = try stage(name: name, session: session, to: list, context: context)
            try SyncJournal.stage(baseline, kind: "createRankedItem", context: context)
            try context.save()
        } catch { context.rollback(); throw error }
    }

    /// Shared transaction staging for domain adapters. The caller owns save/rollback.
    @discardableResult
    static func stage(name: String, session: RankingEngine, to list: RankingList, context: ModelContext) throws -> RankedItem {
        guard !list.items.contains(where: { $0.id == session.itemID }) else { throw EvidenceError.invalidComparison }
        let item = RankedItem(id: session.itemID, name: name)
        context.insert(item)
        list.items.append(item)
        for evidence in session.evidence {
            let comparison = Comparison(evidence: evidence)
            context.insert(comparison)
            list.comparisons.append(comparison)
        }
        let analysis = list.recompute()
        item.sessionDiagnosticsData = try JSONEncoder().encode(session.diagnostics(analysis: analysis, rank: analysis.rankEstimates()[item.id]))
        return item
    }

    enum EvidenceError: Error { case invalidComparison, sessionHasNewEvidence }

    /// Engine-facing entry point for future Improve Ranking. Always append, even when
    /// this pair already exists; timestamps are preserved and no decay is applied.
    static func record(_ evidence: PreferenceEvidence, in list: RankingList, context: ModelContext) throws {
        try record([evidence], in: list, context: context)
    }

    static func record(_ evidence: [PreferenceEvidence], in list: RankingList, context: ModelContext) throws {
        let ids = Set(list.items.map(\.id))
        guard evidence.allSatisfy({ ids.contains($0.first) && ids.contains($0.second) && $0.first != $0.second && [0.0, 0.5, 1.0].contains($0.outcome) }) else { throw EvidenceError.invalidComparison }
        let baseline = try SyncJournal.begin(context)
        for observation in evidence {
            let comparison = Comparison(evidence: observation)
            context.insert(comparison)
            list.comparisons.append(comparison)
        }
        list.recompute()
        do {
            try SyncJournal.stage(baseline, kind: "appendEvidence", context: context)
            try context.save()
        } catch { context.rollback(); throw error }
    }

    static func removeSession(_ session: RankingEngine, from list: RankingList, context: ModelContext) throws {
        let comparisons = list.comparisons.filter { $0.firstItemID == session.itemID || $0.secondItemID == session.itemID }
        // Once refinement has added evidence involving this item, completion undo
        // must not silently delete those later observations.
        var remaining = session.evidence
        for comparison in comparisons {
            guard let index = remaining.firstIndex(of: comparison.evidence) else { throw EvidenceError.sessionHasNewEvidence }
            remaining.remove(at: index)
        }
        guard remaining.isEmpty else { throw EvidenceError.sessionHasNewEvidence }
        let baseline = try SyncJournal.begin(context)
        let items = list.items.filter { $0.id == session.itemID }
        list.comparisons.removeAll { $0.firstItemID == session.itemID || $0.secondItemID == session.itemID }
        list.items.removeAll { $0.id == session.itemID }
        for comparison in comparisons { context.delete(comparison) }
        for item in items { context.delete(item) }
        list.recompute()
        do {
            try SyncJournal.stage(baseline, kind: "removeSession", context: context)
            try context.save()
        } catch { context.rollback(); throw error }
    }
}
