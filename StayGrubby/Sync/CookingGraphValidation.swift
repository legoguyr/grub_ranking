import Foundation

extension CookingGraph {
    nonisolated func validate() throws {
        func require(_ value: Bool) throws { if !value { throw SyncFoundationError.invalidGraph } }
        func unique<T: Hashable>(_ values: [T]) throws { try require(Set(values).count == values.count) }
        try require(formatVersion == 1)
        try unique(libraries.map(\.key)); try require(libraries.count <= 1)
        try unique(rankings.map(\.id)); try unique(dishes.map(\.id)); try unique(attempts.map(\.id))
        try unique(items.map(\.id)); try unique(comparisons.map(\.id)); try unique(sources.map(\.id))
        try unique(tags.map(\.key)); try unique(media.map(\.id)); try unique(attempts.map(\.rankedItemID))
        let lists = Set(rankings.map(\.id)), dishIDs = Set(dishes.map(\.id)), tagIDs = Set(tags.map(\.key))
        let itemMap = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let attemptIDs = Set(attempts.map(\.id))
        if let library = libraries.first {
            try require(library.key == "local" && lists.contains(library.globalRankingID))
        } else { try require(rankings.isEmpty && dishes.isEmpty && attempts.isEmpty && items.isEmpty && comparisons.isEmpty && sources.isEmpty && media.isEmpty) }
        for item in items {
            try require(item.rankingID.map(lists.contains) == true && item.strength.isFinite && item.uncertainty.isFinite && item.uncertainty >= 0)
        }
        for attempt in attempts {
            try require(attempt.dishID.map(dishIDs.contains) == true && itemMap[attempt.rankedItemID] != nil && attempt.sequenceNumber > 0)
            try unique(attempt.tagKeys); try require(Set(attempt.tagKeys).isSubset(of: tagIDs))
        }
        for observation in comparisons {
            try require(observation.firstItemID != observation.secondItemID && observation.rankingID != nil)
            guard let first = itemMap[observation.firstItemID], let second = itemMap[observation.secondItemID] else { throw SyncFoundationError.invalidGraph }
            try require(first.rankingID == observation.rankingID && second.rankingID == observation.rankingID)
            try require(observation.isTie ? observation.preferredItemID == nil : observation.preferredItemID.map { [observation.firstItemID, observation.secondItemID].contains($0) } == true)
        }
        try unique(sources.compactMap(\.dishID))
        for source in sources {
            try require(source.dishID.map(dishIDs.contains) == true && dishes.first(where: { $0.id == source.dishID })?.sourceID == source.id)
        }
        for dish in dishes {
            if let source = dish.sourceID { try require(sources.contains { $0.id == source && $0.dishID == dish.id }) }
        }
        for photo in media {
            try require(photo.attemptID.map(attemptIDs.contains) == true && photo.pixelWidth > 0 && photo.pixelHeight > 0)
            for filename in [photo.displayFilename, photo.thumbnailFilename] {
                try require(!filename.isEmpty && filename != "." && filename != ".." && !filename.contains("/") && !filename.contains("\\") && !filename.contains("\0"))
            }
        }
        try unique(deletions.map(\.identity))
        try require(Set(try records().map { $0.reference.identity }).isDisjoint(with: Set(deletions.map(\.identity))))
        let dates = rankings.map(\.createdAt) + dishes.map(\.createdAt) + attempts.flatMap { [$0.createdAt, $0.updatedAt] + [$0.cookedAt].compactMap { $0 } }
            + items.map(\.createdAt) + comparisons.map(\.timestamp) + sources.flatMap { [$0.createdAt, $0.updatedAt] } + media.map(\.createdAt) + legacyItemDates
        try require(dates.allSatisfy { $0.timeIntervalSinceReferenceDate.isFinite })
    }
    nonisolated func canonicalized() -> Self {
        var result = self
        result.deletions.sort { $0.identity < $1.identity }
        result.libraries.sort { $0.key < $1.key }; result.rankings.sort { $0.id.uuidString < $1.id.uuidString }
        result.dishes.sort { $0.id.uuidString < $1.id.uuidString }; result.attempts.sort { $0.id.uuidString < $1.id.uuidString }
        for index in result.attempts.indices { result.attempts[index].tagKeys.sort() }
        result.items.sort { $0.id.uuidString < $1.id.uuidString }; result.comparisons.sort { $0.id.uuidString < $1.id.uuidString }
        result.sources.sort { $0.id.uuidString < $1.id.uuidString }; result.tags.sort { $0.key < $1.key }
        result.media.sort { $0.id.uuidString < $1.id.uuidString }; result.legacyItemDates.sort()
        return result
    }
}
