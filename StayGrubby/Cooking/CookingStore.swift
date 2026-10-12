import Foundation
import SwiftData

@MainActor
enum CookingStore {
    enum StoreError: LocalizedError {
        case missingRanking, invalidDraft, missingItem, duplicateItem, incompleteSession
        var errorDescription: String? {
            switch self {
            case .missingRanking: "The saved cooking ranking could not be found. Your data has not been reset."
            case .invalidDraft: "Enter a dish name and a cooked date for a new version."
            case .missingItem: "This version is no longer available."
            case .duplicateItem: "This ranked item already has a cooking version."
            case .incompleteSession: "Finish the ranking questions before saving."
            }
        }
    }

    /// Additive, idempotent bridge. Never rewrites original item names, scores,
    /// comparison observations, or their timestamps; never combines legacy lists.
    @discardableResult
    static func prepare(context: ModelContext) throws -> RankingList {
        try SyncJournal.requireReady(context)
        let baseline = try SyncJournal.begin(context)
        do {
            let lists = try context.fetch(FetchDescriptor<RankingList>())
            let libraries = try context.fetch(FetchDescriptor<CookingLibrary>())
            let global: RankingList
            if let library = libraries.first(where: { $0.key == "local" }) {
                guard let existing = lists.first(where: { $0.id == library.globalRankingID }) else { throw StoreError.missingRanking }
                global = existing
            } else {
                // Preserve the largest established ranking; stable date/UUID tie breaks.
                if let existing = lists.sorted(by: {
                    if $0.items.count != $1.items.count { return $0.items.count > $1.items.count }
                    if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
                    return $0.id.uuidString < $1.id.uuidString
                }).first { global = existing }
                else { global = RankingList(name: "My Cooking"); context.insert(global) }
                context.insert(CookingLibrary(globalRankingID: global.id))
            }
            let attempts = try context.fetch(FetchDescriptor<CookingAttempt>())
            var linked = Set(attempts.map(\.rankedItemID))
            for item in try context.fetch(FetchDescriptor<RankedItem>()) where linked.insert(item.id).inserted {
                let dish = Dish(name: item.name, category: .other, createdAt: item.createdAt)
                let attempt = CookingAttempt(item: item, sequence: 1, category: .other, cookedAt: nil, legacy: true)
                context.insert(dish); context.insert(attempt)
                dish.attempts.append(attempt)
            }
            if context.hasChanges {
                try SyncJournal.stage(baseline, kind: "initialize", context: context)
                try context.save()
            }
            return global
        } catch { context.rollback(); throw error }
    }

    static func globalRanking(context: ModelContext) throws -> RankingList {
        let libraries = try context.fetch(FetchDescriptor<CookingLibrary>())
        guard let id = libraries.first(where: { $0.key == "local" })?.globalRankingID,
              let list = try context.fetch(FetchDescriptor<RankingList>()).first(where: { $0.id == id }) else { throw StoreError.missingRanking }
        return list
    }

    @discardableResult
    static func create(draft: CookingDraft, existingDish: Dish? = nil, session: RankingEngine,
                       context: ModelContext, mediaDirectory: URL? = nil) throws -> CookingAttempt {
        guard !draft.cleanDishName.isEmpty, draft.cookedAt != nil else { throw StoreError.invalidDraft }
        guard session.isComplete else { throw StoreError.incompleteSession }
        let global = try globalRanking(context: context)
        let itemID = session.itemID
        guard try context.fetchCount(FetchDescriptor<RankedItem>(predicate: #Predicate { $0.id == itemID })) == 0
        else { throw StoreError.duplicateItem }
        guard session.orderedIDs.count == global.items.count,
              Set(session.orderedIDs) == Set(global.items.map(\.id)),
              existingDish == nil || existingDish!.attempts.contains(where: { $0.rankedItem?.list?.id == global.id })
        else { throw RankingStore.EvidenceError.invalidComparison }
        let baseline = try SyncJournal.begin(context)
        var writtenMedia: CookingMedia?
        do {
            let dish: Dish
            if let existingDish { dish = existingDish }
            else {
                dish = Dish(name: draft.cleanDishName, category: draft.category)
                context.insert(dish)
                DishSourceStore.apply(draft.source, to: dish, context: context)
            }
            let number = (dish.attempts.map(\.sequenceNumber).max() ?? 0) + 1
            let label = "\(dish.name) — \(draft.cleanTitle ?? "Version \(number)")"
            let item = try RankingStore.stage(name: label, session: session, to: global, context: context)
            let attempt = CookingAttempt(item: item, sequence: number, category: draft.category, cookedAt: draft.cookedAt)
            context.insert(attempt)
            dish.attempts.append(attempt)
            apply(draft, to: attempt)
            attempt.tags = try tags(for: draft, context: context)
            if let photo = draft.pendingPhoto {
                let media = try LocalPhotoStore.write(photo, rootURL: mediaDirectory)
                writtenMedia = media
                context.insert(media)
                attempt.media.append(media)
            }
            try SyncJournal.stage(baseline, kind: "createCook", context: context)
            try context.save()
            return attempt
        } catch {
            if let writtenMedia { LocalPhotoStore.deleteFiles(for: writtenMedia, rootURL: mediaDirectory) }
            context.rollback(); throw error
        }
    }

    static func edit(_ attempt: CookingAttempt, draft: CookingDraft, context: ModelContext,
                     mediaDirectory: URL? = nil) throws {
        guard !draft.cleanDishName.isEmpty else { throw StoreError.invalidDraft }
        guard let dish = attempt.dish, attempt.rankedItem != nil else { throw StoreError.missingItem }
        let replacingPhoto = draft.pendingPhoto != nil || draft.removeExistingPhoto
        let retiredFiles = replacingPhoto ? attempt.media.map { ($0.displayFilename, $0.thumbnailFilename) } : []
        let baseline = try SyncJournal.begin(context)
        var writtenMedia: CookingMedia?
        do {
            let renamed = dish.name != draft.cleanDishName
            dish.name = draft.cleanDishName
            DishSourceStore.apply(draft.source, to: dish, context: context)
            apply(draft, to: attempt)
            attempt.tags = try tags(for: draft, context: context)
            if replacingPhoto {
                for media in attempt.media { context.delete(media) }
                attempt.media.removeAll()
                if let photo = draft.pendingPhoto {
                    let media = try LocalPhotoStore.write(photo, rootURL: mediaDirectory)
                    writtenMedia = media
                    context.insert(media)
                    attempt.media.append(media)
                }
            }
            // Renaming the shared dish updates display caches only, never preference evidence.
            for sibling in dish.attempts where renamed || sibling.id == attempt.id {
                sibling.rankedItem?.name = sibling.displayName
                sibling.updatedAt = .now
            }
            try SyncJournal.stage(baseline, kind: "editCook", context: context)
            try context.save()
            for files in retiredFiles {
                LocalPhotoStore.deleteFiles(displayFilename: files.0, thumbnailFilename: files.1,
                                            rootURL: mediaDirectory)
            }
        } catch {
            if let writtenMedia { LocalPhotoStore.deleteFiles(for: writtenMedia, rootURL: mediaDirectory) }
            context.rollback(); throw error
        }
    }

    static func delete(_ attempt: CookingAttempt, context: ModelContext, mediaDirectory: URL? = nil) throws {
        guard let item = attempt.rankedItem else { throw StoreError.missingItem }
        let list = item.list
        let retiredFiles = attempt.media.map { ($0.displayFilename, $0.thumbnailFilename) }
        let baseline = try SyncJournal.begin(context)
        do {
            // IDs in evidence are scalar values; explicitly remove every incident edge,
            // including repeated/tie/refinement observations before deleting the item.
            let observations = try context.fetch(FetchDescriptor<Comparison>()).filter { $0.firstItemID == item.id || $0.secondItemID == item.id }
            for observation in observations {
                observation.list?.comparisons.removeAll { $0.id == observation.id }
                context.delete(observation)
            }
            list?.items.removeAll { $0.id == item.id }
            let dish = attempt.dish
            dish?.attempts.removeAll { $0.id == attempt.id }
            attempt.tags = []
            context.delete(attempt)
            context.delete(item)
            if let dish, dish.attempts.isEmpty { context.delete(dish) }
            list?.recompute()
            try SyncJournal.stage(baseline, kind: "deleteCook", context: context)
            try context.save()
            for files in retiredFiles {
                LocalPhotoStore.deleteFiles(displayFilename: files.0, thumbnailFilename: files.1,
                                            rootURL: mediaDirectory)
            }
        } catch { context.rollback(); throw error }
    }

    static func rerank(_ attempt: CookingAttempt, evidence: [PreferenceEvidence], context: ModelContext) throws {
        guard let item = attempt.rankedItem, let list = item.list else { throw StoreError.missingItem }
        guard evidence.allSatisfy({ $0.first == item.id || $0.second == item.id }) else { throw RankingStore.EvidenceError.invalidComparison }
        // The generic batch API appends and globally refits; no old evidence is removed.
        try RankingStore.record(evidence, in: list, context: context)
    }

    private static func apply(_ draft: CookingDraft, to attempt: CookingAttempt) {
        attempt.cookedAt = draft.cookedAt; attempt.versionTitle = draft.cleanTitle
        attempt.notes = CookingDraft.optional(draft.notes); attempt.category = draft.category
        attempt.updatedAt = .now
    }

    private static func tags(for draft: CookingDraft, context: ModelContext) throws -> [CookingTag] {
        var existing = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<CookingTag>()).map { ($0.key, $0) })
        var result: [CookingTag] = []
        func append(_ kind: CookingTagKind, _ value: String, _ label: String) {
            let key = "\(kind.rawValue):\(value)"
            if let tag = existing[key] { result.append(tag) }
            else {
                let tag = CookingTag(kind: kind, value: value, label: label)
                context.insert(tag); existing[key] = tag; result.append(tag)
            }
        }
        for tag in draft.dietary.sorted(by: { $0.rawValue < $1.rawValue }) { append(.dietary, tag.rawValue, tag.label) }
        for tag in draft.allergy.sorted(by: { $0.rawValue < $1.rawValue }) { append(.allergy, tag.rawValue, tag.label) }
        for tag in draft.contains.sorted(by: { $0.rawValue < $1.rawValue }) { append(.contains, tag.rawValue, tag.label) }
        for label in TagNormalization.deduplicated(draft.customTags) { append(.custom, TagNormalization.key(label), label) }
        return result
    }
}
