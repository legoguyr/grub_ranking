import Foundation
import SwiftData

/// Applies complete accepted snapshots, never a local user transaction.
/// Pending edits/conflicts are retained; callers must resolve them before hydration.
@MainActor enum CookingGraphHydration {
    static func apply(_ incoming: CookingGraph, revision: Int, context: ModelContext) throws {
        let graph = incoming.canonicalized()
        try graph.validate()
        let binding = try SyncJournal.binding(context)
        guard graph.accountID == binding?.accountID else { throw SyncFoundationError.wrongAccount }
        guard revision >= 0, revision >= (binding?.acceptedRevision ?? -1) else { throw SyncFoundationError.staleRevision }
        guard try SyncJournal.pending(context).isEmpty, !context.hasChanges else { throw SyncFoundationError.pendingLocalChanges }
        let encoded = try graph.encoded()
        if revision == binding?.acceptedRevision, let accepted = binding?.acceptedSnapshotData, accepted != encoded {
            throw SyncFoundationError.revisionCollision
        }
        let tombstones = try context.fetch(FetchDescriptor<SyncTombstone>())
        let deleted = Set(tombstones.map(\.key))
        guard Set(try graph.records().map { $0.reference.identity }).isDisjoint(with: deleted) else { throw SyncFoundationError.deletedIdentity }
        if try CookingGraphExport.snapshot(context: context) == graph {
            binding?.acceptedRevision = revision; binding?.acceptedSnapshotData = encoded
            binding?.restorationRequired = false
            do { if context.hasChanges { try context.save() } } catch { context.rollback(); throw error }
            return
        }
        do {
            var libraries = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<CookingLibrary>()).map { ($0.key, $0) })
            var rankings = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<RankingList>()).map { ($0.id, $0) })
            var dishes = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Dish>()).map { ($0.id, $0) })
            var attempts = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<CookingAttempt>()).map { ($0.id, $0) })
            var items = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<RankedItem>()).map { ($0.id, $0) })
            var comparisons = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Comparison>()).map { ($0.id, $0) })
            var tags = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<CookingTag>()).map { ($0.key, $0) })
            var media = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<CookingMedia>()).map { ($0.id, $0) })
            var sources = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<DishSource>()).map { ($0.id, $0) })
            for row in graph.libraries {
                let value = libraries[row.key] ?? CookingLibrary(globalRankingID: row.globalRankingID)
                if libraries[row.key] == nil { context.insert(value); libraries[row.key] = value }
                value.key = row.key
                value.globalRankingID = row.globalRankingID
                value.bridgeVersion = row.bridgeVersion
            }
            for row in graph.rankings {
                let value = rankings[row.id] ?? RankingList(name: row.name, id: row.id, createdAt: row.createdAt)
                if rankings[row.id] == nil { context.insert(value); rankings[row.id] = value }
                value.id = row.id
                value.name = row.name
                value.createdAt = row.createdAt
            }
            for row in graph.tags {
                let value = tags[row.key] ?? CookingTag(kind: CookingTagKind(rawValue: row.kindCode) ?? .custom, value: row.value, label: row.label)
                if tags[row.key] == nil { context.insert(value); tags[row.key] = value }
                value.key = row.key
                value.kindCode = row.kindCode
                value.value = row.value
                value.label = row.label
            }
            for row in graph.dishes {
                let value = dishes[row.id] ?? Dish(name: row.name, createdAt: row.createdAt, id: row.id)
                if dishes[row.id] == nil { context.insert(value); dishes[row.id] = value }
                value.id = row.id
                value.name = row.name
                value.defaultCategoryCode = row.defaultCategoryCode
                value.createdAt = row.createdAt
            }
            for row in graph.items {
                let value = items[row.id] ?? RankedItem(id: row.id, name: row.name)
                if items[row.id] == nil { context.insert(value); items[row.id] = value }
                value.id = row.id
                value.name = row.name
                value.createdAt = row.createdAt
                value.strength = row.strength
                value.uncertainty = row.uncertainty
                value.sessionDiagnosticsData = row.sessionDiagnosticsData
                value.list = row.rankingID.flatMap { rankings[$0] }
            }
            for row in graph.attempts {
                let value = attempts[row.id] ?? CookingAttempt(item: items[row.rankedItemID]!, sequence: row.sequenceNumber, category: DishCategory(rawValue: row.categoryCode) ?? .other, cookedAt: row.cookedAt, legacy: row.isLegacyImport, id: row.id)
                if attempts[row.id] == nil { context.insert(value); attempts[row.id] = value }
                value.id = row.id
                value.rankedItemID = row.rankedItemID
                value.cookedAt = row.cookedAt
                value.versionTitle = row.versionTitle
                value.notes = row.notes
                value.categoryCode = row.categoryCode
                value.sequenceNumber = row.sequenceNumber
                value.createdAt = row.createdAt
                value.updatedAt = row.updatedAt
                value.isLegacyImport = row.isLegacyImport
                value.dish = row.dishID.flatMap { dishes[$0] }; value.rankedItem = items[row.rankedItemID]
                value.tags = row.tagKeys.compactMap { tags[$0] }
            }
            for row in graph.sources {
                let value = sources[row.id] ?? DishSource(type: DishSourceType(rawValue: row.typeCode) ?? .other, id: row.id)
                if sources[row.id] == nil { context.insert(value); sources[row.id] = value }
                value.id = row.id
                value.typeCode = row.typeCode
                value.createdAt = row.createdAt
                value.updatedAt = row.updatedAt
                value.cookbookTitle = row.cookbookTitle
                value.cookbookAuthors = row.cookbookAuthors
                value.cookbookRecipeName = row.cookbookRecipeName
                value.cookbookPage = row.cookbookPage
                value.restaurantName = row.restaurantName
                value.restaurantDishName = row.restaurantDishName
                value.restaurantLocation = row.restaurantLocation
                value.onlineRecipeName = row.onlineRecipeName
                value.onlineWebsite = row.onlineWebsite
                value.onlineURL = row.onlineURL
                value.socialCreator = row.socialCreator
                value.socialPlatform = row.socialPlatform
                value.socialURL = row.socialURL
                value.socialDishName = row.socialDishName
                value.friendName = row.friendName
                value.friendNote = row.friendNote
                value.otherName = row.otherName
                value.otherDetails = row.otherDetails
                value.dish = row.dishID.flatMap { dishes[$0] }
            }
            for row in graph.media {
                let value = media[row.id] ?? CookingMedia(id: row.id, displayFilename: row.displayFilename, thumbnailFilename: row.thumbnailFilename, pixelWidth: row.pixelWidth, pixelHeight: row.pixelHeight, sortOrder: row.sortOrder)
                if media[row.id] == nil { context.insert(value); media[row.id] = value }
                value.id = row.id
                value.kindCode = row.kindCode
                value.displayFilename = row.displayFilename
                value.thumbnailFilename = row.thumbnailFilename
                value.pixelWidth = row.pixelWidth
                value.pixelHeight = row.pixelHeight
                value.sortOrder = row.sortOrder
                value.createdAt = row.createdAt
                value.attempt = row.attemptID.flatMap { attempts[$0] }
            }
            for row in graph.comparisons {
                let value = comparisons[row.id] ?? Comparison(evidence: PreferenceEvidence(first: row.firstItemID, second: row.secondItemID, outcome: row.isTie ? 0.5 : (row.preferredItemID == row.firstItemID ? 1 : 0), timestamp: row.timestamp), id: row.id)
                if comparisons[row.id] == nil { context.insert(value); comparisons[row.id] = value }
                value.id = row.id
                value.firstItemID = row.firstItemID
                value.secondItemID = row.secondItemID
                value.preferredItemID = row.preferredItemID
                value.isTie = row.isTie
                value.timestamp = row.timestamp
                value.list = row.rankingID.flatMap { rankings[$0] }
            }
            // Rebuild inverse collections before pruning, so old cascade parents cannot delete surviving children.
            for row in graph.rankings {
                rankings[row.id]?.items = graph.items.filter { $0.rankingID == row.id }.compactMap { items[$0.id] }
                rankings[row.id]?.comparisons = graph.comparisons.filter { $0.rankingID == row.id }.compactMap { comparisons[$0.id] }
            }
            for row in graph.dishes {
                dishes[row.id]?.attempts = graph.attempts.filter { $0.dishID == row.id }.compactMap { attempts[$0.id] }
                dishes[row.id]?.source = row.sourceID.flatMap { sources[$0] }
            }
            for row in graph.attempts {
                attempts[row.id]?.media = graph.media.filter { $0.attemptID == row.id }.compactMap { media[$0.id] }
            }
            let comparisonsIDs = Set(graph.comparisons.map(\.id))
            for (key, value) in comparisons where !comparisonsIDs.contains(key) { context.delete(value) }
            let mediaIDs = Set(graph.media.map(\.id))
            for (key, value) in media where !mediaIDs.contains(key) { context.delete(value) }
            let attemptsIDs = Set(graph.attempts.map(\.id))
            for (key, value) in attempts where !attemptsIDs.contains(key) { context.delete(value) }
            let sourcesIDs = Set(graph.sources.map(\.id))
            for (key, value) in sources where !sourcesIDs.contains(key) { context.delete(value) }
            let itemsIDs = Set(graph.items.map(\.id))
            for (key, value) in items where !itemsIDs.contains(key) { context.delete(value) }
            let dishesIDs = Set(graph.dishes.map(\.id))
            for (key, value) in dishes where !dishesIDs.contains(key) { context.delete(value) }
            let rankingsIDs = Set(graph.rankings.map(\.id))
            for (key, value) in rankings where !rankingsIDs.contains(key) { context.delete(value) }
            let tagsIDs = Set(graph.tags.map(\.key))
            for (key, value) in tags where !tagsIDs.contains(key) { context.delete(value) }
            let librariesIDs = Set(graph.libraries.map(\.key))
            for (key, value) in libraries where !librariesIDs.contains(key) { context.delete(value) }
            let legacy = try context.fetch(FetchDescriptor<Item>())
            if legacy.map(\.timestamp).sorted() != graph.legacyItemDates {
                for value in legacy { context.delete(value) }
                for date in graph.legacyItemDates { context.insert(Item(timestamp: date)) }
            }
            for reference in graph.deletions where !deleted.contains(reference.identity) {
                let marker = SyncTombstone(reference); marker.acknowledgedRevision = revision; context.insert(marker)
            }
            binding?.acceptedRevision = revision; binding?.acceptedSnapshotData = encoded
            binding?.restorationRequired = false
            try context.save()
        } catch { context.rollback(); throw error }
    }
}
