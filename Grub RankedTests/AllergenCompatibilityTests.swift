import Foundation
import SwiftData
import Testing
@testable import Grub_Ranked

@MainActor struct AllergenCompatibilityTests {
    private func create(_ draft: CookingDraft, context: ModelContext, dish: Dish? = nil) throws -> CookingAttempt {
        let list = try CookingStore.globalRanking(context: context)
        var session = RankingEngine(itemID: UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: .liked)
        while session.nextOpponent != nil { session.answer(.newItem) }
        return try CookingStore.create(draft: draft, existingDish: dish, session: session, context: context)
    }
    @Test func containsAndLegacyFreeRemainDistinctThroughDiskReloadAndEdit() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("allergen-\(UUID()).store")
        var identifier: UUID!
        do {
            let container = try AppPersistence.open(url: url); let context = ModelContext(container)
            _ = try CookingStore.prepare(context: context)
            var draft = CookingDraft(); draft.dishName = "Fixture Curry"
            draft.allergy = [.peanutFree]; draft.contains = [.milk, .wheat]
            let cook = try create(draft, context: context); identifier = cook.id
            #expect(cook.tags.contains { $0.key == "allergy:peanutFree" })
            #expect(cook.tags.contains { $0.key == "contains:milk" })
            #expect(!cook.containedAllergens.contains(.peanuts))
        }
        let container = try AppPersistence.open(url: url); let context = ModelContext(container)
        let cook = try #require(context.fetch(FetchDescriptor<CookingAttempt>()).first { $0.id == identifier })
        let list = try CookingStore.globalRanking(context: context)
        let evidence = list.comparisons.map(\.id); let strengths = list.items.map(\.strength)
        var edit = CookingDraft(attempt: cook)
        #expect(edit.contains == [.milk, .wheat] && edit.allergy == [.peanutFree])
        edit.contains = [.fish]; try CookingStore.edit(cook, draft: edit, context: context)
        #expect(cook.containedAllergens == [.fish] && cook.allergyTags == [.peanutFree])
        #expect(CookingDiscovery.entries(in: list, attempts: [cook], filters: CookingFilters(avoidedAllergens: [.peanuts])).count == 1)
        #expect(CookingDiscovery.entries(in: list, attempts: [cook], filters: CookingFilters(avoidedAllergens: [.fish])).isEmpty)
        #expect(list.comparisons.map(\.id) == evidence && list.items.map(\.strength) == strengths)
        // Explicit removal is the only way the editor discards legacy claims.
        edit.allergy = []; try CookingStore.edit(cook, draft: edit, context: context)
        #expect(cook.allergyTags.isEmpty && cook.containedAllergens == [.fish])
    }
    @Test func legacyFreeAloneNeverInfersPresenceOrCertifiedAbsence() throws {
        let container = try ModelContainer(for: AppPersistence.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = ModelContext(container); let list = try CookingStore.prepare(context: context)
        var draft = CookingDraft(); draft.dishName = "Legacy"; draft.allergy = Set(AllergyTag.allCases)
        let cook = try create(draft, context: context)
        #expect(cook.containedAllergens.isEmpty)
        #expect(CookingDiscovery.entries(in: list, attempts: [cook], filters: CookingFilters(avoidedAllergens: Set(Allergen.allCases))).count == 1)
        #expect(CookingProductOptions.allergenSafetyText.contains("does not mean allergen-free"))
    }
    @Test func parentSearchIsNormalizedAndSelectionKeepsOneDishAndRanking() throws {
        let container = try ModelContainer(for: AppPersistence.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = ModelContext(container); let list = try CookingStore.prepare(context: context)
        var draft = CookingDraft(); draft.dishName = "Harissa Chicken"
        let first = try create(draft, context: context); let dish = try #require(first.dish)
        #expect(DishSelectionSearch.matches([dish], query: " ＨＡＲＩＳＳＡ   chicken ").map(\.id) == [dish.id])
        #expect(DishSelectionSearch.matches([dish], query: "cake").isEmpty)
        let second = try create(CookingDraft(dish: dish), context: context, dish: dish)
        #expect(second.dish?.id == dish.id && second.rankedItemID != first.rankedItemID)
        #expect(first.rankedItem?.list?.id == list.id && second.rankedItem?.list?.id == list.id)
        #expect(try context.fetchCount(FetchDescriptor<Dish>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<RankingList>()) == 1)
    }
}
