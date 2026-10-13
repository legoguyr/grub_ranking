import Foundation

extension SyncChanges {
    /// Advances the accepted base using only the acknowledged operation, never later local edits.
    nonisolated func applying(to original: CookingGraph) throws -> CookingGraph {
        var records = Dictionary(uniqueKeysWithValues: try original.records().map { ($0.reference.identity, $0) })
        var removed = Dictionary(uniqueKeysWithValues: original.deletions.map { ($0.identity, $0) })
        for reference in deletions { records.removeValue(forKey: reference.identity); removed[reference.identity] = reference }
        for record in upserts {
            guard removed[record.reference.identity] == nil else { throw SyncFoundationError.deletedIdentity }
            records[record.reference.identity] = record
        }
        let decoder = JSONDecoder()
        func rows<T: Decodable>(_ entity: SyncEntity, _: T.Type) throws -> [T] {
            try records.values.filter { $0.reference.entity == entity }.map { try decoder.decode(T.self, from: $0.data) }
        }
        let archive = try rows(.legacyArchive, [Date].self)
        let graph = CookingGraph(deletions: Array(removed.values), accountID: original.accountID,
            libraries: try rows(.library, LibraryTransfer.self), rankings: try rows(.ranking, RankingTransfer.self),
            dishes: try rows(.dish, DishTransfer.self), attempts: try rows(.attempt, AttemptTransfer.self),
            items: try rows(.rankedItem, RankedItemTransfer.self), comparisons: try rows(.comparison, ComparisonTransfer.self),
            sources: try rows(.source, SourceTransfer.self), tags: try rows(.tag, TagTransfer.self),
            media: try rows(.media, MediaTransfer.self), legacyItemDates: archive.first ?? [])
        try graph.validate()
        return graph.canonicalized()
    }
}

extension Notification.Name {
    static let cookingSyncWorkCommitted = Notification.Name("StayGrubby.cookingSyncWorkCommitted")
}
