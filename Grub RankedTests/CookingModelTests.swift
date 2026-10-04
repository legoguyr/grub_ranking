import Foundation
import Testing
import SwiftData
@testable import Grub_Ranked

@MainActor
struct CookingModelTests {
    private func memory() throws -> ModelContainer {
        try ModelContainer(for: AppPersistence.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    }
    private func draft(_ name: String = "Miso Salmon") -> CookingDraft {
        var result = CookingDraft(); result.dishName = name; result.category = .main
        result.cookedAt = Date(timeIntervalSince1970: 1_700_000_000)
        return result
    }
    @discardableResult private func create(_ context: ModelContext, _ draft: CookingDraft, dish: Dish? = nil) throws -> CookingAttempt {
        let list = try CookingStore.globalRanking(context: context)
        var session = RankingEngine(itemID: UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: .liked)
        while session.nextOpponent != nil { session.answer(.newItem) }
        return try CookingStore.create(draft: draft, existingDish: dish, session: session, context: context)
    }
    private struct ItemSnapshot: Equatable {
        let id: UUID; let listID: UUID?; let name: String; let created: Date
        let strength: Double; let uncertainty: Double; let diagnostics: Data?
        init(_ item: RankedItem) {
            id = item.id; listID = item.list?.id; name = item.name; created = item.createdAt
            strength = item.strength; uncertainty = item.uncertainty; diagnostics = item.sessionDiagnosticsData
        }
    }
    private struct ComparisonSnapshot: Equatable {
        let id: UUID; let listID: UUID?; let evidence: PreferenceEvidence
        let winner: UUID?; let tie: Bool
        init(_ comparison: Comparison) {
            id = comparison.id; listID = comparison.list?.id; evidence = comparison.evidence
            winner = comparison.preferredItemID; tie = comparison.isTie
        }
    }

    @Test func newDishAndVersionsShareGlobalRankingWithIndependentItems() throws {
        let container = try memory(); let context = ModelContext(container)
        let global = try CookingStore.prepare(context: context)
        let first = try create(context, draft())
        let dish = try #require(first.dish)
        #expect(dish.name == "Miso Salmon" && dish.defaultCategory == .main)
        #expect(dish.attempts.count == 1 && first.rankedItemID == first.rankedItem?.id)
        let other = try create(context, draft("Lamb"))
        var version = CookingDraft(dish: dish)
        #expect(version.dishName == dish.name && version.category == dish.defaultCategory)
        version.versionTitle = "More miso"
        let second = try create(context, version, dish: dish)
        let third = try create(context, version, dish: dish)
        #expect(dish.attempts.count == 3)
        #expect(Set([first, second, third, other].map(\.rankedItemID)).count == 4)
        #expect(global.items.count == 4 && global.comparisons.count >= 3)
        #expect([first, second, third, other].allSatisfy { $0.rankedItem?.list?.id == global.id })
        #expect(second.sequenceNumber == 2 && third.sequenceNumber == 3)
        #expect(try context.fetchCount(FetchDescriptor<Dish>()) == 2)
        let ids = Set(global.items.map(\.id))
        #expect(global.comparisons.allSatisfy { ids.contains($0.firstItemID) && ids.contains($0.secondItemID) })
    }

    @Test func categoriesAndAllTagKindsPersistAndRemainQueryableAfterReload() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cooking-\(UUID()).store")
        defer { removeStore(url) }
        var savedID = UUID()
        do {
            let container = try AppPersistence.open(url: url); let context = ModelContext(container)
            try CookingStore.prepare(context: context)
            var metadata = draft(); metadata.category = .pastaNoodles; metadata.versionTitle = " Sunday "; metadata.notes = " Extra lemon "
            metadata.dietary = Set(DietaryTag.allCases); metadata.allergy = Set(AllergyTag.allCases)
            metadata.customTags = ["  Family   Favorite ", "family favorite", "\nFAMILY\tFAVORITE", "", "Weeknight"]
            let attempt = try create(context, metadata); savedID = attempt.id
            _ = try create(context, metadata, dish: attempt.dish)
            #expect(try context.fetchCount(FetchDescriptor<CookingTag>()) == 17)
        }
        let container = try AppPersistence.open(url: url); let context = ModelContext(container)
        let attempt = try #require(context.fetch(FetchDescriptor<CookingAttempt>()).first { $0.id == savedID })
        #expect(attempt.category == .pastaNoodles && attempt.dish?.defaultCategory == .pastaNoodles)
        #expect(attempt.versionTitle == "Sunday" && attempt.notes == "Extra lemon")
        #expect(attempt.cookedAt == draft().cookedAt)
        #expect(attempt.dietaryTags == Set(DietaryTag.allCases))
        #expect(attempt.allergyTags == Set(AllergyTag.allCases))
        #expect(attempt.customTags == ["Family Favorite", "Weeknight"])
        #expect(attempt.dish?.attempts.count == 2 && attempt.rankedItem?.list?.items.count == 2)
        let filter = FetchDescriptor<CookingTag>(predicate: #Predicate { $0.kindCode == "dietary" && $0.value == "vegan" })
        #expect(try context.fetch(filter).first?.attempts.count == 2)
        let category = FetchDescriptor<CookingAttempt>(predicate: #Predicate { $0.categoryCode == "pastaNoodles" })
        #expect(try context.fetchCount(category) == 2)
        #expect(attempt.updatedAt >= attempt.createdAt)
    }

    @Test func customTagsNormalizeWhitespaceCaseAndWidthButKeepKindsSeparate() throws {
        #expect(TagNormalization.deduplicated(["  A  b ", "a\tb", "Ａ B", "\n", "Other"]) == ["A b", "Other"])
        let container = try memory(); let context = ModelContext(container)
        try CookingStore.prepare(context: context)
        var metadata = draft(); metadata.dietary = [.vegan]; metadata.customTags = ["Vegan", " VEGAN "]
        let attempt = try create(context, metadata)
        #expect(attempt.tags.count == 2 && attempt.dietaryTags == [.vegan] && attempt.customTags == ["Vegan"])
    }

    @Test func metadataEditRetainsIdentityEvidenceScoresAndSharedDish() throws {
        let container = try memory(); let context = ModelContext(container)
        let list = try CookingStore.prepare(context: context)
        let first = try create(context, draft())
        let second = try create(context, draft(), dish: first.dish)
        let ids = list.items.map(\.id); let evidence = list.comparisons.map(ComparisonSnapshot.init)
        let before = Dictionary(uniqueKeysWithValues: list.items.map { ($0.id, ($0.strength, $0.uncertainty, $0.sessionDiagnosticsData)) })
        let originalAttemptID = second.id; let originalItemID = second.rankedItemID
        var metadata = CookingDraft(attempt: second)
        metadata.dishName = "Salmon"; metadata.versionTitle = "Grilled"; metadata.category = .side
        metadata.notes = "Changed seasoning"; metadata.cookedAt = Date(timeIntervalSince1970: 1_800_000_000)
        metadata.dietary = [.kosher]; metadata.allergy = [.peanutFree]; metadata.customTags = ["Favorite"]
        try CookingStore.edit(second, draft: metadata, context: context)
        #expect(second.id == originalAttemptID && second.rankedItemID == originalItemID)
        #expect(list.items.map(\.id) == ids && list.comparisons.map(ComparisonSnapshot.init) == evidence)
        for item in list.items {
            #expect(item.strength == before[item.id]?.0 && item.uncertainty == before[item.id]?.1)
            #expect(item.sessionDiagnosticsData == before[item.id]?.2)
        }
        #expect(first.dish?.name == "Salmon" && first.rankedItem?.name == "Salmon — Version 1")
        #expect(second.rankedItem?.name == "Salmon — Grilled")
        #expect(first.category == .main && second.category == .side && second.dish?.defaultCategory == .main)
        #expect(second.dietaryTags == [.kosher] && second.allergyTags == [.peanutFree])
        #expect(second.customTags == ["Favorite"] && second.notes == metadata.notes && second.cookedAt == metadata.cookedAt)
    }

    @Test func deletionRemovesAllIncidentEvidenceKeepsOtherVersionsAndRefits() throws {
        let container = try memory(); let context = ModelContext(container)
        let list = try CookingStore.prepare(context: context)
        let first = try create(context, draft())
        let second = try create(context, draft(), dish: first.dish)
        let third = try create(context, draft("Lamb"))
        try CookingStore.rerank(second, evidence: [PreferenceEvidence(first: second.rankedItemID, second: first.rankedItemID, outcome: 0.5),
                                                  PreferenceEvidence(first: second.rankedItemID, second: third.rankedItemID, outcome: 0)], context: context)
        let removedID = second.rankedItemID
        let keptEvidence = list.comparisons.filter { $0.firstItemID != removedID && $0.secondItemID != removedID }.map(ComparisonSnapshot.init)
        try CookingStore.delete(second, context: context)
        #expect(list.items.count == 2 && first.dish?.attempts.count == 1)
        #expect(list.comparisons.map(ComparisonSnapshot.init) == keptEvidence)
        #expect(try context.fetch(FetchDescriptor<Comparison>()).allSatisfy { $0.firstItemID != removedID && $0.secondItemID != removedID })
        let expected = BradleyTerryModel.fit(ids: list.items.map(\.id), evidence: list.comparisons.map(\.evidence))
        #expect(list.items.allSatisfy { abs($0.strength - expected[$0.id]!.strength) < 1e-10 })
        try CookingStore.delete(first, context: context)
        #expect(try context.fetchCount(FetchDescriptor<Dish>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<CookingAttempt>()) == 1)
        #expect(list.items.count == 1 && third.rankedItem?.score == 5.5 && list.comparisons.isEmpty)
        try CookingStore.delete(third, context: context)
        #expect(try context.fetchCount(FetchDescriptor<Dish>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<RankedItem>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Comparison>()) == 0)
        #expect(try CookingStore.prepare(context: context).id == list.id)
        #expect(try context.fetchCount(FetchDescriptor<CookingAttempt>()) == 0)
    }

    @Test func rerankingAppendsRepeatedContradictoryEvidenceAndPreservesHistory() throws {
        let container = try memory(); let context = ModelContext(container)
        let list = try CookingStore.prepare(context: context)
        let first = try create(context, draft())
        let second = try create(context, draft("Lamb"))
        let originals = list.comparisons.map(ComparisonSnapshot.init)
        let strength = try #require(first.rankedItem?.strength)
        let repeated = PreferenceEvidence(first: first.rankedItemID, second: second.rankedItemID, outcome: 1, timestamp: Date(timeIntervalSince1970: 1234))
        try CookingStore.rerank(first, evidence: [repeated], context: context)
        try CookingStore.rerank(first, evidence: [repeated], context: context)
        #expect(list.comparisons.count == originals.count + 2)
        #expect(originals.allSatisfy { list.comparisons.map(ComparisonSnapshot.init).contains($0) })
        #expect(list.comparisons.filter { $0.evidence == repeated }.count == 2)
        #expect(first.rankedItem!.strength > strength)
        #expect(list.items.count == 2 && first.rankedItem?.id == first.rankedItemID)
        let expected = BradleyTerryModel.fit(ids: list.items.map(\.id), evidence: list.comparisons.map(\.evidence))
        #expect(list.items.allSatisfy { abs($0.strength - expected[$0.id]!.strength) < 1e-10 })
    }

    @Test func rerankDraftSkipUndoCancelAndFocusDoNotMutateSavedData() throws {
        let container = try memory(); let context = ModelContext(container)
        let list = try CookingStore.prepare(context: context)
        let first = try create(context, draft())
        _ = try create(context, draft("Lamb")); _ = try create(context, draft("Pasta"))
        let before = list.comparisons.map(ComparisonSnapshot.init)
        var session = ReRankingSession(itemID: first.rankedItemID, ids: list.items.map(\.id), history: list.comparisons.map(\.evidence))
        let originalOpponent = try #require(session.nextOpponent)
        session.answer(.skip)
        #expect(session.evidence.isEmpty && session.nextOpponent != originalOpponent)
        session.undo(); #expect(session.nextOpponent == originalOpponent)
        session.answer(.tooTough)
        #expect(session.evidence.first?.outcome == 0.5)
        #expect(session.evidence.allSatisfy { $0.first == first.rankedItemID })
        #expect(list.comparisons.map(ComparisonSnapshot.init) == before)
        session.undo(); #expect(session.evidence.isEmpty)
        #expect(!context.hasChanges)
    }

    @Test func rerankAndDeleteRemainConsistentAfterDiskReload() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cooking-delete-\(UUID()).store")
        defer { removeStore(url) }
        var survivorID = UUID(); var removedID = UUID(); var kept: [ComparisonSnapshot] = []
        do {
            let container = try AppPersistence.open(url: url); let context = ModelContext(container)
            let list = try CookingStore.prepare(context: context)
            let first = try create(context, draft()); survivorID = first.rankedItemID
            let second = try create(context, draft(), dish: first.dish); removedID = second.rankedItemID
            let third = try create(context, draft("Lamb"))
            let observation = PreferenceEvidence(first: first.rankedItemID, second: third.rankedItemID, outcome: 0.5)
            try CookingStore.rerank(first, evidence: [observation, observation], context: context)
            kept = list.comparisons.filter { $0.firstItemID != removedID && $0.secondItemID != removedID }.map(ComparisonSnapshot.init)
            try CookingStore.delete(second, context: context)
        }
        let container = try AppPersistence.open(url: url); let context = ModelContext(container)
        let list = try CookingStore.prepare(context: context)
        #expect(list.items.count == 2 && list.items.contains { $0.id == survivorID })
        #expect(!list.items.contains { $0.id == removedID })
        #expect(list.comparisons.count == kept.count && list.comparisons.map(ComparisonSnapshot.init).allSatisfy(kept.contains))
        let attempts = try context.fetch(FetchDescriptor<CookingAttempt>())
        #expect(attempts.count == 2 && attempts.allSatisfy { $0.rankedItem != nil && $0.dish != nil })
        #expect(try context.fetchCount(FetchDescriptor<Dish>()) == 2)
    }

    @Test func invalidOrCrossListCreationAndRerankingLeaveStoreUnchanged() throws {
        let container = try memory(); let context = ModelContext(container)
        let list = try CookingStore.prepare(context: context)
        let first = try create(context, draft())
        let empty = RankingEngine(itemID: UUID(), orderedIDs: [], reaction: .liked)
        #expect(throws: (any Error).self) { try CookingStore.create(draft: draft(), session: empty, context: context) }
        let unfinished = RankingEngine(itemID: UUID(), orderedIDs: list.items.map(\.id), reaction: .liked)
        #expect(throws: (any Error).self) { try CookingStore.create(draft: draft(), session: unfinished, context: context) }
        #expect(throws: (any Error).self) { try CookingStore.rerank(first, evidence: [PreferenceEvidence(first: first.rankedItemID, second: UUID(), outcome: 1)], context: context) }
        let independent = RankingList(name: "Independent")
        context.insert(independent)
        let existing = RankedItem(name: "Existing ID in another list")
        context.insert(existing); independent.items.append(existing); try context.save()
        var collision = RankingEngine(itemID: existing.id, orderedIDs: list.items.map(\.id), reaction: .liked)
        while collision.nextOpponent != nil { collision.answer(.skip) }
        #expect(throws: (any Error).self) { try CookingStore.create(draft: draft(), session: collision, context: context) }
        #expect(list.items.count == 1 && list.comparisons.isEmpty)
        #expect(independent.items.count == 1)
        #expect(try context.fetchCount(FetchDescriptor<Dish>()) == 1)
    }

    @Test func legacyDiskUpgradePreservesAllEvidenceAndBridgesIdempotently() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("legacy-\(UUID()).store")
        defer { removeStore(url) }
        var items: [ItemSnapshot] = []; var evidence: [ComparisonSnapshot] = []
        var listNames: [UUID: String] = [:]; var listDates: [UUID: Date] = [:]; var primaryID = UUID()
        do {
            // Exact pre-Phase-1 schema, genuinely stored on disk and closed before opening the new schema.
            let schema = Schema([Item.self, RankingList.self, RankedItem.self, Comparison.self])
            let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config]); let context = ModelContext(container)
            context.autosaveEnabled = false
            let primary = RankingList(name: "My real history"); let other = RankingList(name: "Keep separate")
            context.insert(primary); context.insert(other); primaryID = primary.id
            for name in ["Same name", "Same name", "Third"] {
                var session = RankingEngine(itemID: UUID(), orderedIDs: primary.orderedItems.map(\.id), reaction: .fine)
                while session.nextOpponent != nil { session.answer(.tooTough) }
                try RankingStore.save(name: name, session: session, to: primary, context: context)
            }
            try RankingStore.save(name: "Elsewhere", session: RankingEngine(itemID: UUID(), orderedIDs: [], reaction: .liked), to: other, context: context)
            let repeated = PreferenceEvidence(first: primary.items[0].id, second: primary.items[1].id, outcome: 1, timestamp: Date(timeIntervalSince1970: 100))
            try RankingStore.record([repeated, repeated], in: primary, context: context)
            items = try context.fetch(FetchDescriptor<RankedItem>()).map(ItemSnapshot.init)
            evidence = try context.fetch(FetchDescriptor<Comparison>()).map(ComparisonSnapshot.init)
            listNames = [primary.id: primary.name, other.id: other.name]; listDates = [primary.id: primary.createdAt, other.id: other.createdAt]
        }
        do {
            let container = try AppPersistence.open(url: url); let context = ModelContext(container)
            #expect(try CookingStore.prepare(context: context).id == primaryID)
            try CookingStore.prepare(context: context)
            let saved = try context.fetch(FetchDescriptor<RankedItem>()).map(ItemSnapshot.init)
            let comparisons = try context.fetch(FetchDescriptor<Comparison>()).map(ComparisonSnapshot.init)
            #expect(saved.count == items.count && items.allSatisfy(saved.contains))
            #expect(comparisons.count == evidence.count && evidence.allSatisfy(comparisons.contains))
            for list in try context.fetch(FetchDescriptor<RankingList>()) {
                #expect(list.name == listNames[list.id] && list.createdAt == listDates[list.id])
            }
            let attempts = try context.fetch(FetchDescriptor<CookingAttempt>())
            #expect(attempts.count == 4 && Set(attempts.map(\.rankedItemID)).count == 4)
            #expect(try context.fetchCount(FetchDescriptor<Dish>()) == 4)
            for attempt in attempts {
                #expect(attempt.isLegacyImport && attempt.cookedAt == nil && attempt.versionTitle == nil && attempt.notes == nil)
                #expect(attempt.category == .other && attempt.tags.isEmpty)
                #expect(attempt.dish?.name == attempt.rankedItem?.name)
                #expect(attempt.createdAt == attempt.rankedItem?.createdAt)
                #expect(attempt.dish?.attempts.count == 1)
            }
        }
        let reopened = try AppPersistence.open(url: url); let context = ModelContext(reopened)
        #expect(try CookingStore.prepare(context: context).id == primaryID)
        #expect(try context.fetchCount(FetchDescriptor<CookingAttempt>()) == 4)
        #expect(try context.fetchCount(FetchDescriptor<CookingLibrary>()) == 1)
        #expect(try context.fetch(FetchDescriptor<Comparison>()).map(ComparisonSnapshot.init).allSatisfy(evidence.contains))
    }

    private func removeStore(_ url: URL) {
        for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: url.path + suffix) }
    }
}
