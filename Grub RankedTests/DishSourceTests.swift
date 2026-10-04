import Foundation
import Testing
import SwiftData
@testable import Grub_Ranked

@MainActor
struct DishSourceTests {
    private func memory() throws -> ModelContainer {
        try ModelContainer(for: AppPersistence.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    }
    private func newCook(_ context: ModelContext, dish: Dish? = nil, draft: CookingDraft? = nil) throws -> CookingAttempt {
        let list = try CookingStore.globalRanking(context: context)
        var value = draft ?? CookingDraft()
        value.dishName = dish?.name ?? "Miso Salmon"
        value.cookedAt = Date(timeIntervalSince1970: 1_700_000_000)
        var session = RankingEngine(itemID: UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: .liked)
        while session.nextOpponent != nil { session.answer(.newItem) }
        return try CookingStore.create(draft: value, existingDish: dish, session: session, context: context)
    }
    private func filled(_ type: DishSourceType) -> DishSourceDraft {
        var source = DishSourceDraft(type: type)
        source.cookbookTitle = " Zahav "; source.cookbookAuthors = " Michael Solomonov "; source.cookbookRecipeName = " Hummus "; source.cookbookPage = " 43 "
        source.restaurantName = " Carbone "; source.restaurantDishName = " Spicy Rigatoni "; source.restaurantLocation = " New York "
        source.onlineRecipeName = " Roast Chicken "; source.onlineWebsite = " Example Kitchen "; source.onlineURL = " https://example.com/chicken "
        source.socialCreator = " Chef Jane "; source.socialPlatform = " Instagram "; source.socialURL = " https://example.com/post "; source.socialDishName = " Tomato Pasta "
        source.friendName = " Grandma "; source.friendNote = " From Sunday dinner "
        source.otherName = " Market "; source.otherDetails = " Inspired by a display "
        return source
    }
    private struct EvidenceSnapshot: Equatable {
        let id: UUID; let first: UUID; let second: UUID; let winner: UUID?; let tie: Bool; let date: Date
        init(_ value: Comparison) {
            id = value.id; first = value.firstItemID; second = value.secondItemID
            winner = value.preferredItemID; tie = value.isTie; date = value.timestamp
        }
    }
    private struct RankSnapshot: Equatable {
        let id: UUID; let strength: Double; let uncertainty: Double; let diagnostics: Data?
        init(_ item: RankedItem) {
            id = item.id; strength = item.strength; uncertainty = item.uncertainty
            diagnostics = item.sessionDiagnosticsData
        }
    }

    @Test func dishWithNoSourceAndLegacyBridgeStaySourceFree() throws {
        let container = try memory(); let context = ModelContext(container)
        let list = try CookingStore.prepare(context: context)
        let first = try newCook(context)
        #expect(first.dish?.source == nil)
        #expect(try context.fetchCount(FetchDescriptor<DishSource>()) == 0)
        var generic = RankingEngine(itemID: UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: .fine)
        while generic.nextOpponent != nil { generic.answer(.tooTough) }
        try RankingStore.save(name: "Older generic cook", session: generic, to: list, context: context)
        try CookingStore.prepare(context: context)
        let bridged = try #require(context.fetch(FetchDescriptor<CookingAttempt>()).first { $0.rankedItemID == generic.itemID })
        #expect(bridged.isLegacyImport && bridged.dish?.source == nil)
        #expect(try context.fetchCount(FetchDescriptor<DishSource>()) == 0)
    }

    @Test(arguments: DishSourceType.allCases)
    func everyTypePersistsOnlyItsRelevantFields(_ type: DishSourceType) throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("source-\(type.rawValue)-\(UUID()).store")
        defer { for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: url.path + suffix) } }
        var savedID = UUID()
        do {
            let container = try AppPersistence.open(url: url); let context = ModelContext(container)
            try CookingStore.prepare(context: context)
            var draft = CookingDraft(); draft.source = filled(type)
            let cook = try newCook(context, draft: draft)
            savedID = try #require(cook.dish?.source?.id)
            #expect(cook.dish?.source?.type == type)
            #expect(cook.dish?.source?.dish?.id == cook.dish?.id)
            #expect(try context.fetchCount(FetchDescriptor<DishSource>()) == 1)
        }
        let container = try AppPersistence.open(url: url); let context = ModelContext(container)
        let source = try #require(context.fetch(FetchDescriptor<DishSource>()).first { $0.id == savedID })
        #expect(source.type == type && source.dish?.source?.id == savedID)
        #expect(source.updatedAt >= source.createdAt)
        switch type {
        case .original:
            #expect(source.detailRows.isEmpty)
        case .cookbook:
            #expect(source.cookbookTitle == "Zahav" && source.cookbookAuthors == "Michael Solomonov")
            #expect(source.cookbookRecipeName == "Hummus" && source.cookbookPage == "43")
        case .restaurant:
            #expect(source.restaurantName == "Carbone" && source.restaurantDishName == "Spicy Rigatoni")
            #expect(source.restaurantLocation == "New York")
        case .onlineRecipe:
            #expect(source.onlineRecipeName == "Roast Chicken" && source.onlineWebsite == "Example Kitchen")
            #expect(source.onlineURL == "https://example.com/chicken")
        case .socialMedia:
            #expect(source.socialCreator == "Chef Jane" && source.socialPlatform == "Instagram")
            #expect(source.socialURL == "https://example.com/post" && source.socialDishName == "Tomato Pasta")
        case .friendFamily:
            #expect(source.friendName == "Grandma" && source.friendNote == "From Sunday dinner")
        case .other:
            #expect(source.otherName == "Market" && source.otherDetails == "Inspired by a display")
        }
        #expect(source.detailRows.count == [DishSourceType.original: 0, .cookbook: 4, .restaurant: 3,
            .onlineRecipe: 3, .socialMedia: 4, .friendFamily: 2, .other: 2][type])
        if type != .cookbook { #expect(source.cookbookTitle == nil && source.cookbookPage == nil) }
        if type != .restaurant { #expect(source.restaurantName == nil && source.restaurantLocation == nil) }
        if type != .onlineRecipe { #expect(source.onlineURL == nil) }
        if type != .socialMedia { #expect(source.socialURL == nil) }
        if type != .friendFamily { #expect(source.friendName == nil) }
        if type != .other { #expect(source.otherName == nil) }
    }

    @Test func newVersionInheritsOneSharedSourceWithoutCopyOrOverwrite() throws {
        let container = try memory(); let context = ModelContext(container)
        let list = try CookingStore.prepare(context: context)
        var draft = CookingDraft(); draft.source = filled(.cookbook)
        let first = try newCook(context, draft: draft)
        let dish = try #require(first.dish)
        let source = try #require(dish.source)
        var inherited = CookingDraft(dish: dish)
        #expect(inherited.source?.type == .cookbook && inherited.source?.cookbookTitle == "Zahav")
        inherited.source?.cookbookTitle = "A different book"
        let second = try newCook(context, dish: dish, draft: inherited)
        #expect(second.dish?.id == dish.id && second.dish?.source?.id == source.id)
        #expect(dish.source?.cookbookTitle == "Zahav")
        #expect(try context.fetchCount(FetchDescriptor<DishSource>()) == 1)
        #expect(first.rankedItemID != second.rankedItemID && list.items.count == 2)
        #expect(list.comparisons.count >= 1)
    }

    @Test func editingSwitchingAndRemovingSourcePreserveRankingEvidence() throws {
        let container = try memory(); let context = ModelContext(container)
        let list = try CookingStore.prepare(context: context)
        var draft = CookingDraft(); draft.source = filled(.cookbook)
        let first = try newCook(context, draft: draft)
        _ = try newCook(context, dish: first.dish)
        let dish = try #require(first.dish)
        let sourceID = try #require(dish.source?.id)
        let ranking = list.items.map(RankSnapshot.init)
        let evidence = list.comparisons.map(EvidenceSnapshot.init)
        let cookID = first.id; let itemID = first.rankedItemID
        var edit = CookingDraft(attempt: first)
        edit.source = filled(.restaurant)
        try CookingStore.edit(first, draft: edit, context: context)
        #expect(dish.source?.id == sourceID && dish.source?.type == .restaurant)
        #expect(dish.source?.restaurantName == "Carbone" && dish.source?.cookbookTitle == nil)
        #expect(dish.attempts.allSatisfy { $0.dish?.source?.id == sourceID })
        #expect(first.id == cookID && first.rankedItemID == itemID)
        #expect(list.items.map(RankSnapshot.init) == ranking)
        #expect(list.comparisons.map(EvidenceSnapshot.init) == evidence)
        edit.source = filled(.cookbook)
        edit.source?.cookbookTitle = "New Book"
        try CookingStore.edit(first, draft: edit, context: context)
        #expect(dish.source?.id == sourceID && dish.source?.cookbookTitle == "New Book")
        #expect(dish.source?.restaurantName == nil)
        edit.source = nil
        try CookingStore.edit(first, draft: edit, context: context)
        #expect(dish.source == nil)
        #expect(try context.fetchCount(FetchDescriptor<DishSource>()) == 0)
        #expect(list.items.map(RankSnapshot.init) == ranking)
        #expect(list.comparisons.map(EvidenceSnapshot.init) == evidence)
    }

    @Test func deleteFinalCookCleansDishOwnedSourceButKeepsSharedSourceUntilThen() throws {
        let container = try memory(); let context = ModelContext(container)
        try CookingStore.prepare(context: context)
        var draft = CookingDraft(); draft.source = filled(.friendFamily)
        let first = try newCook(context, draft: draft)
        let second = try newCook(context, dish: first.dish)
        try CookingStore.delete(second, context: context)
        #expect(first.dish?.source?.friendName == "Grandma")
        #expect(try context.fetchCount(FetchDescriptor<DishSource>()) == 1)
        try CookingStore.delete(first, context: context)
        #expect(try context.fetchCount(FetchDescriptor<Dish>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<DishSource>()) == 0)
    }

    @Test func canceledSourceDraftHasNoPersistentEffect() throws {
        let container = try memory(); let context = ModelContext(container)
        try CookingStore.prepare(context: context)
        var draft = CookingDraft(); draft.source = filled(.onlineRecipe)
        let cook = try newCook(context, draft: draft)
        var editing = CookingDraft(attempt: cook)
        editing.source = filled(.socialMedia)
        #expect(cook.dish?.source?.type == .onlineRecipe)
        #expect(try context.fetchCount(FetchDescriptor<DishSource>()) == 1)
        #expect(!context.hasChanges)
    }

    @Test func deletingFinalCookLeavesNoSourceAfterDiskReload() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("source-delete-\(UUID()).store")
        defer { for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: url.path + suffix) } }
        do {
            let container = try AppPersistence.open(url: url); let context = ModelContext(container)
            try CookingStore.prepare(context: context)
            var draft = CookingDraft(); draft.source = filled(.restaurant)
            let cook = try newCook(context, draft: draft)
            try CookingStore.delete(cook, context: context)
        }
        let container = try AppPersistence.open(url: url); let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<Dish>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<DishSource>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<CookingAttempt>()) == 0)
    }
}
