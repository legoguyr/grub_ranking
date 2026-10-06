import Foundation
import SwiftData
import Testing
import UIKit
@testable import Grub_Ranked

@MainActor
struct CookingDiscoveryTests {
    @MainActor private struct Fixture {
        let container: ModelContainer
        let context: ModelContext
        let list: RankingList
        let chicken: CookingAttempt
        let sunday: CookingAttempt
        let pasta: CookingAttempt
        let cake: CookingAttempt
        var attempts: [CookingAttempt] { [cake, sunday, pasta, chicken] }
        func results(_ query: String = "", _ filters: CookingFilters = CookingFilters()) -> [CookingDiscovery.Entry] {
            CookingDiscovery.entries(in: list, attempts: attempts, query: query, filters: filters)
        }
    }

    private func create(_ draft: CookingDraft, context: ModelContext, dish: Dish? = nil,
                        mediaDirectory: URL? = nil) throws -> CookingAttempt {
        let list = try CookingStore.globalRanking(context: context)
        var session = RankingEngine(itemID: UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: .liked)
        while session.nextOpponent != nil { session.answer(.newItem) }
        return try CookingStore.create(draft: draft, existingDish: dish, session: session,
                                       context: context, mediaDirectory: mediaDirectory)
    }

    private func fixture() throws -> Fixture {
        let container = try ModelContainer(for: AppPersistence.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let list = try CookingStore.prepare(context: context)
        var draft = CookingDraft(); draft.dishName = "Apple Cake"; draft.category = .dessert
        draft.dietary = [.vegetarian]; draft.allergy = [.peanutFree]
        let cake = try create(draft, context: context)
        draft = CookingDraft(); draft.dishName = "Lemon Pasta"; draft.category = .pastaNoodles
        draft.dietary = [.vegan]; draft.allergy = [.milkFree, .sesameFree]; draft.customTags = ["Weeknight"]
        let pasta = try create(draft, context: context)
        draft = CookingDraft(); draft.dishName = "Harissa Chicken"; draft.versionTitle = "Golden sear"
        draft.category = .main; draft.dietary = [.kosher, .dairyFree]; draft.allergy = [.sesameFree]
        draft.customTags = ["  Date   Night "]
        var source = DishSourceDraft(type: .cookbook); source.cookbookTitle = "Zahav"
        draft.source = source
        let chicken = try create(draft, context: context)
        draft = CookingDraft(dish: try #require(chicken.dish)); draft.versionTitle = "Smoky Sunday"
        draft.dietary = [.halal]; draft.allergy = [.peanutFree]
        let sunday = try create(draft, context: context, dish: chicken.dish)
        return Fixture(container: container, context: context, list: list, chicken: chicken,
                       sunday: sunday, pasta: pasta, cake: cake)
    }

    @Test(arguments: ["Harissa Chicken", "chick", "CHICKEN", "  harissa   CHICKEN\n", "ＨＡＲＩＳＳＡ"])
    func dishSearchNormalizesCaseWhitespaceAndWidth(query: String) throws {
        let f = try fixture()
        #expect(f.results(query).map(\.id) == [f.sunday.id, f.chicken.id])
    }

    @Test func searchesVersionsAndEachTagKindWithoutIndexingSourceOrNotes() throws {
        let f = try fixture()
        #expect(f.results("smoky").map(\.id) == [f.sunday.id])
        #expect(f.results("date  NIGHT").map(\.id) == [f.chicken.id])
        #expect(f.results("kosher").map(\.id) == [f.chicken.id])
        #expect(f.results("sesame-free").map(\.id) == [f.chicken.id, f.pasta.id])
        #expect(f.results("Pasta/Noodles").map(\.id) == [f.pasta.id])
        #expect(f.results("Zahav").isEmpty)
        f.chicken.notes = "secret notes"
        #expect(f.results("secret").isEmpty)
    }

    @Test func noMatchAndClearingQueryRestoreTheGlobalOrderAndRanks() throws {
        let f = try fixture()
        #expect(f.results("ramen").isEmpty)
        let all = f.results()
        #expect(all.map(\.attempt.rankedItemID) == f.list.orderedItems.map(\.id))
        #expect(f.results("  \n ").map(\.id) == all.map(\.id))
        #expect(f.results("chicken").map(\.globalRank) == [1, 2])
        #expect(f.results("pasta").map(\.globalRank) == [3])
    }

    @Test func categoryDietaryAndAllergyUseCanonicalValues() throws {
        let f = try fixture()
        #expect(f.results("", CookingFilters(category: .main)).map(\.id) == [f.sunday.id, f.chicken.id])
        #expect(f.results("", CookingFilters(dietary: [.vegan])).map(\.id) == [f.pasta.id])
        #expect(f.results("", CookingFilters(allergies: [.peanutFree])).map(\.id) == [f.sunday.id, f.cake.id])
        #expect(f.results("", CookingFilters(category: .soup)).isEmpty)
    }

    @Test func groupsAndSearchCombineWithANDAndValuesWithinGroupsUseOR() throws {
        let f = try fixture()
        #expect(f.results("", CookingFilters(dietary: [.vegan, .vegetarian])).map(\.id) == [f.pasta.id, f.cake.id])
        #expect(f.results("", CookingFilters(allergies: [.peanutFree, .sesameFree])).count == 4)
        let combined = CookingFilters(category: .main, dietary: [.kosher, .vegan], allergies: [.sesameFree, .milkFree])
        #expect(f.results("chicken", combined).map(\.id) == [f.chicken.id])
        #expect(f.results("pasta", combined).isEmpty)
        #expect(f.results("", CookingFilters(category: .dessert, dietary: [.vegan])).isEmpty)
    }

    @Test func individualRemovalAndResetKeepTheOtherSelections() throws {
        let f = try fixture()
        var filters = CookingFilters(category: .main, dietary: [.kosher], allergies: [.peanutFree])
        #expect(filters.count == 3 && filters.isActive)
        #expect(f.results("", filters).isEmpty)
        filters.allergies.remove(.peanutFree)
        #expect(filters.category == .main && filters.dietary == [.kosher])
        #expect(f.results("", filters).map(\.id) == [f.chicken.id])
        filters = CookingFilters()
        #expect(!filters.isActive && filters.count == 0)
        #expect(f.results("", filters).count == 4)
    }

    private struct RankingSnapshot: Equatable {
        let id: UUID; let strength: Double; let uncertainty: Double; let score: Double
        let diagnostics: Data?; let createdAt: Date; let listID: UUID?
        init(_ item: RankedItem) {
            id = item.id; strength = item.strength; uncertainty = item.uncertainty; score = item.score
            diagnostics = item.sessionDiagnosticsData; createdAt = item.createdAt; listID = item.list?.id
        }
    }
    private struct EvidenceSnapshot: Equatable {
        let id: UUID; let evidence: PreferenceEvidence; let listID: UUID?
        init(_ comparison: Comparison) { id = comparison.id; evidence = comparison.evidence; listID = comparison.list?.id }
    }

    @Test func everyDiscoveryOperationLeavesScoresEvidenceAndRelationshipsUnchanged() throws {
        let f = try fixture()
        let items = f.list.orderedItems.map(RankingSnapshot.init)
        let evidence = f.list.comparisons.map(EvidenceSnapshot.init)
        let updated = f.attempts.map(\.updatedAt)
        for query in ["", "chicken", "date night", "kosher", "sesame-free", "nothing"] {
            for filters in [CookingFilters(), CookingFilters(category: .main), CookingFilters(dietary: [.vegan, .kosher])] {
                let results = f.results(query, filters)
                #expect(results.map(\.globalRank) == results.map(\.globalRank).sorted())
                for entry in results {
                    #expect(items[entry.globalRank - 1].id == entry.attempt.rankedItemID)
                    #expect(items[entry.globalRank - 1].score == entry.attempt.rankedItem?.score)
                }
            }
        }
        #expect(items == f.list.orderedItems.map(RankingSnapshot.init))
        #expect(evidence == f.list.comparisons.map(EvidenceSnapshot.init))
        #expect(updated == f.attempts.map(\.updatedAt))
        #expect(!f.context.hasChanges)
        #expect(try f.context.fetchCount(FetchDescriptor<RankingList>()) == 1)
    }

    @Test func creationAndVersionsRemainIndependentlyDiscoverable() throws {
        let f = try fixture()
        var draft = CookingDraft(); draft.dishName = "Soup"; draft.category = .soup; draft.dietary = [.vegan]
        let soup = try create(draft, context: f.context)
        var version = CookingDraft(dish: try #require(soup.dish)); version.versionTitle = "Extra ginger"
        let second = try create(version, context: f.context, dish: soup.dish)
        let all = try f.context.fetch(FetchDescriptor<CookingAttempt>())
        let entries = CookingDiscovery.entries(in: f.list, attempts: all, query: "Soup")
        #expect(Set(entries.map(\.id)) == [soup.id, second.id])
        #expect(entries.map(\.globalRank) == [1, 2])
        #expect(CookingDiscovery.entries(in: f.list, attempts: all, filters: CookingFilters(dietary: [.vegan])).map(\.id) == [soup.id, f.pasta.id])
    }

    @Test func editsUpdateEveryDiscoveryFieldWithoutChangingRankIdentityOrEvidence() throws {
        let f = try fixture()
        let items = f.list.orderedItems.map(RankingSnapshot.init)
        let evidence = f.list.comparisons.map(EvidenceSnapshot.init)
        var edit = CookingDraft(attempt: f.chicken)
        edit.dishName = "Roast Lamb"; edit.versionTitle = "Crispy"; edit.category = .side
        edit.dietary = [.vegetarian]; edit.allergy = [.eggFree]; edit.customTags = ["Picnic"]
        try CookingStore.edit(f.chicken, draft: edit, context: f.context)
        #expect(f.results("chicken").isEmpty)
        #expect(f.results("lamb").map(\.id) == [f.sunday.id, f.chicken.id])
        for query in ["crispy", "picnic", "vegetarian", "egg-free"] { #expect(f.results(query).contains { $0.id == f.chicken.id }) }
        #expect(f.results("date night").isEmpty && f.results("kosher").isEmpty)
        #expect(f.results("", CookingFilters(category: .side, dietary: [.vegetarian], allergies: [.eggFree])).map(\.id) == [f.chicken.id])
        #expect(items == f.list.orderedItems.map(RankingSnapshot.init))
        #expect(evidence == f.list.comparisons.map(EvidenceSnapshot.init))
        #expect(f.chicken.dish?.source?.cookbookTitle == "Zahav")
    }

    @Test func rerankAndDeletePreserveDiscoverySemanticsAndOtherVersions() throws {
        let f = try fixture()
        let filters = CookingFilters(category: .main)
        let before = f.list.comparisons.map(EvidenceSnapshot.init)
        try CookingStore.rerank(f.chicken, evidence: [PreferenceEvidence(first: f.chicken.rankedItemID,
            second: f.sunday.rankedItemID, outcome: 1, timestamp: .now)], context: f.context)
        #expect(f.list.comparisons.count == before.count + 1)
        let retained = f.list.comparisons.map(EvidenceSnapshot.init)
        #expect(before.allSatisfy { retained.contains($0) })
        let results = f.results("chicken", filters)
        #expect(Set(results.map(\.id)) == [f.chicken.id, f.sunday.id])
        #expect(results.map(\.attempt.rankedItemID) == f.list.orderedItems.filter { [f.chicken.rankedItemID, f.sunday.rankedItemID].contains($0.id) }.map(\.id))
        let deletedID = f.sunday.id
        try CookingStore.delete(f.sunday, context: f.context)
        let remaining = try f.context.fetch(FetchDescriptor<CookingAttempt>())
        let after = CookingDiscovery.entries(in: f.list, attempts: remaining, query: "chicken", filters: filters)
        #expect(after.map(\.id) == [f.chicken.id] && !remaining.contains { $0.id == deletedID })
        #expect(f.chicken.dish?.source?.cookbookTitle == "Zahav")
        #expect(try f.context.fetchCount(FetchDescriptor<RankingList>()) == 1)
    }

    @Test func discoveryKeepsPhotoReferencesAndNoPhotoAttempts() throws {
        let f = try fixture()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("discovery-photo-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let data = UIGraphicsImageRenderer(size: CGSize(width: 60, height: 60)).pngData { context in
            UIColor.systemOrange.setFill(); context.fill(CGRect(x: 0, y: 0, width: 60, height: 60))
        }
        var draft = CookingDraft(attempt: f.chicken); draft.pendingPhoto = try LocalPhotoStore.prepare(data: data)
        try CookingStore.edit(f.chicken, draft: draft, context: f.context, mediaDirectory: directory)
        let mediaID = try #require(f.chicken.primaryImage?.id)
        let results = f.results("chicken")
        #expect(results.count == 2 && results.first?.attempt.primaryImage == nil)
        #expect(results.last?.attempt.primaryImage?.id == mediaID)
        #expect(LocalPhotoStore.fileExists(for: try #require(f.chicken.primaryImage), thumbnail: true, rootURL: directory))
    }

    @Test func hundredsOfAttemptsUseGlobalOrderWithNoPersistenceWrites() throws {
        let container = try ModelContainer(for: AppPersistence.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = ModelContext(container); let list = try CookingStore.prepare(context: context)
        for index in 0..<500 {
            let dish = Dish(name: "Dish \(index)")
            let item = RankedItem(name: dish.name)
            item.strength = Double(index) / 100
            let attempt = CookingAttempt(item: item, sequence: 1, category: index.isMultiple(of: 2) ? .main : .side, cookedAt: nil)
            context.insert(dish); context.insert(item); context.insert(attempt)
            list.items.append(item); dish.attempts.append(attempt)
        }
        try context.save()
        let attempts = try context.fetch(FetchDescriptor<CookingAttempt>())
        let before = list.orderedItems.map(RankingSnapshot.init)
        let clock = ContinuousClock(); let start = clock.now
        for _ in 0..<20 {
            let entries = CookingDiscovery.entries(in: list, attempts: attempts, query: "dish", filters: CookingFilters(category: .main))
            #expect(entries.count == 250 && entries.first?.globalRank == 2 && entries.last?.globalRank == 500)
        }
        print("DISCOVERY|500 attempts|20 evaluations|\(start.duration(to: clock.now))")
        #expect(before == list.orderedItems.map(RankingSnapshot.init) && !context.hasChanges)
    }
}
