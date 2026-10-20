import Foundation
import SwiftData
import Testing
@testable import StayGrubby

@MainActor struct CuisineTests {
    @Test func catalogHasStableUniqueIDsSeparateFromTags() {
        #expect(CuisineCatalog.predefined.count == 26)
        #expect(Set(CuisineCatalog.predefined.map(\.id)).count == 26)
        #expect(CuisineCatalog.resolve("Italian") == Cuisine(id: "italian", label: "Italian"))
        #expect(CuisineCatalog.resolve("Not a catalog cuisine")?.id.hasPrefix("custom:") == true)
    }

    @Test(arguments: ["Italian", " italian ", "ITALIAN", "Italain", "Italian!"])
    func catalogNormalization(_ input: String) {
        #expect(CuisineCatalog.resolve(input)?.id == "italian")
    }

    @Test func customNormalizationPreservesDistinctIntentAndReusesSavedLabels() throws {
        let value = try #require(CuisineCatalog.resolve("  Basque   Home-Cooking  "))
        #expect(value.label == "Basque Home-Cooking")
        #expect(CuisineCatalog.resolve("BASQUE home cooking", saved: [value]) == value)
        #expect(CuisineCatalog.resolve("Basque Home Cooking")?.id == value.id)
        #expect(CuisineCatalog.resolve("Tex Mex")?.id != CuisineCatalog.resolve("Mexican")?.id)
        #expect(CuisineCatalog.resolve("Sicilian")?.id != CuisineCatalog.resolve("Italian")?.id)
        #expect(CuisineCatalog.resolve("---") == nil)
        #expect(CuisineCatalog.resolve(String(repeating: "a", count: 81)) == nil)
        #expect(CuisineCatalog.resolve("Cajun & Creole")?.id == "cajun-creole")
        #expect(CuisineCatalog.options(saved: [value, value]).count == 27)
    }

    @Test func dishEditsInheritanceAndFiltersNeverChangeRankingEvidence() throws {
        let f = try CookingReRankingWorkflowTests().fixture(3)
        defer { withExtendedLifetime(f) {} }
        let cook = f.cooks[0], dish = try #require(cook.dish)
        let before = try CookingGraphExport.snapshot(context: f.context)
        var draft = CookingDraft(attempt: cook)
        draft.cuisine = CuisineCatalog.resolve("Italian")
        try CookingStore.edit(cook, draft: draft, context: f.context)
        #expect(CookingDraft(dish: dish).cuisine == draft.cuisine)
        #expect(CookingDraft(attempt: cook).cuisine == draft.cuisine)
        let after = try CookingGraphExport.snapshot(context: f.context)
        #expect(before.items == after.items && before.comparisons == after.comparisons)
        #expect(before.attempts.count == after.attempts.count && before.dishes.count == after.dishes.count)
        let matches = CookingDiscovery.entries(in: f.list, attempts: f.cooks, filters: .init(cuisineID: "italian"))
        #expect(matches.map(\.id) == [cook.id])
        let originalRank = try #require(f.list.orderedItems.firstIndex { $0.id == cook.rankedItemID }) + 1
        #expect(matches.first?.globalRank == originalRank)
        #expect(originalRank > 1) // This filtered row must not become #1.
        for mode in RankingsDisplayMode.allCases {
            #expect(RankingsPresentation.entries(CookingDiscovery.entries(in: f.list, attempts: f.cooks), matching: matches, mode: mode).map(\.globalRank) == [originalRank])
        }
        #expect(CookingDiscovery.entries(in: f.list, attempts: f.cooks, query: "does not match", filters: .init(cuisineID: "italian")).isEmpty)
        #expect(CookingDiscovery.entries(in: f.list, attempts: f.cooks, filters: .init(cuisineID: "italian", category: .dessert)).isEmpty)
        #expect(try CookingGraphExport.snapshot(context: f.context) == after)
        draft.cuisine = nil
        try CookingStore.edit(cook, draft: draft, context: f.context)
        #expect(dish.cuisine == nil)
        #expect(try CookingGraphExport.snapshot(context: f.context).items == before.items)
    }

    @Test func newVersionsInheritDishCuisineWithoutReplacingIt() throws {
        let f = try CookingReRankingWorkflowTests().fixture(1)
        defer { withExtendedLifetime(f) {} }
        let original = f.cooks[0], dish = try #require(original.dish)
        var edit = CookingDraft(attempt: original); edit.cuisine = CuisineCatalog.resolve("Italian")
        try CookingStore.edit(original, draft: edit, context: f.context)
        var draft = CookingDraft(dish: dish)
        #expect(draft.cuisine == edit.cuisine)
        draft.cuisine = CuisineCatalog.resolve("Thai") // Inherited shared metadata isn't edited by New Version.
        var session = RankingEngine(itemID: UUID(), orderedIDs: f.list.orderedItems.map(\.id), reaction: .fine)
        while session.nextOpponent != nil { session.answer(.existingItem) }
        let version = try CookingStore.create(draft: draft, existingDish: dish, session: session, context: f.context)
        #expect(version.dish?.cuisine == edit.cuisine && original.dish?.cuisine == edit.cuisine)
        var sharedEdit = CookingDraft(attempt: version); sharedEdit.cuisine = nil
        let before = try CookingGraphExport.snapshot(context: f.context)
        try CookingStore.edit(version, draft: sharedEdit, context: f.context)
        let after = try CookingGraphExport.snapshot(context: f.context)
        #expect(original.dish?.cuisine == nil && version.dish?.cuisine == nil)
        #expect(before.items == after.items && before.comparisons == after.comparisons)
    }

    @Test func selectionPersistsAcrossDiskReopenAndNilIsValid() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("cuisine-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("cooking.store")
        let id = UUID()
        func save(_ cuisine: Cuisine?, create: Bool = false) throws {
            let container = try AppPersistence.open(url: url), context = container.mainContext
            let dish: Dish
            if create { dish = Dish(name: "Soup", id: id); context.insert(dish) }
            else { dish = try #require(context.fetch(FetchDescriptor<Dish>()).first) }
            dish.cuisine = cuisine
            try context.save()
        }
        func read() throws -> Cuisine? {
            let container = try AppPersistence.open(url: url)
            return try #require(container.mainContext.fetch(FetchDescriptor<Dish>()).first).cuisine
        }
        try save(nil, create: true); #expect(try read() == nil)
        let predefined = CuisineCatalog.resolve("Italian")
        try save(predefined); #expect(try read() == predefined)
        let custom = CuisineCatalog.resolve("Basque Home Cooking")
        try save(custom); #expect(try read() == custom)
        try save(nil); #expect(try read() == nil)
    }

    @Test func legacySnapshotsAndCuisineRestoreRetainAccountIsolation() throws {
        let f = try CookingReRankingWorkflowTests().fixture(2)
        defer { withExtendedLifetime(f) {} }
        var graph = try CookingGraphExport.snapshot(context: f.context)
        let owner = UUID(); graph.accountID = owner
        var json = try #require(JSONSerialization.jsonObject(with: graph.encoded()) as? [String: Any])
        var dishes = try #require(json["dishes"] as? [[String: Any]])
        for i in dishes.indices { dishes[i].removeValue(forKey: "cuisine") }
        json["dishes"] = dishes
        let legacy = try JSONSerialization.data(withJSONObject: json, options: .sortedKeys)
        #expect(try CookingGraph.decode(legacy) == graph)
        let target = try ModelContainer(for: AppPersistence.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = target.mainContext
        let binding = SyncStoreBinding(accountID: owner); context.insert(binding); try context.save()
        try CookingGraphHydration.apply(graph, revision: 1, context: context)
        binding.acceptedSnapshotData = legacy; try context.save()
        try CookingGraphHydration.apply(graph, revision: 1, context: context) // Missing and null are equivalent.
        graph.dishes[0].cuisine = CuisineCatalog.resolve("Basque Home Cooking")
        try CookingGraphHydration.apply(graph, revision: 2, context: context)
        #expect(try CookingGraphExport.snapshot(context: context) == graph)
        var wrong = graph; wrong.accountID = UUID()
        #expect(throws: SyncFoundationError.wrongAccount) { try CookingGraphHydration.apply(wrong, revision: 3, context: context) }
        var collision = graph; collision.dishes[0].cuisine = nil
        #expect(throws: SyncFoundationError.revisionCollision) { try CookingGraphHydration.apply(collision, revision: 2, context: context) }
        try CookingGraphHydration.apply(collision, revision: 3, context: context)
        #expect(try CookingGraphExport.snapshot(context: context).dishes[0].cuisine == nil)
    }
}
