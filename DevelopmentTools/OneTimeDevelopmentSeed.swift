#if DEBUG && targetEnvironment(simulator)
import Foundation
import SwiftData
import XCTest
@testable import Grub_Ranked

/// Manual XCTest utility. This directory is outside every application/test target.
/// Temporarily copy into Grub RankedTests ONLY for the explicitly requested reset.
final class OneTimeDevelopmentSeed: XCTestCase {
    struct Request: Decodable {
        let nonce: String
        let simulatorID: String
        let bundleID: String
        let globalRankingID: String
        let itemIDs: [String]
        let comparisonIDs: [String]
        let attemptIDs: [String]
        let dishIDs: [String]
        let tagCount: Int
        let backupSHA256: String
    }
    @MainActor func testReplaceExplicitlyAuthorizedSimulatorLibrary() throws {
        continueAfterFailure = false
        let support = try XCTUnwrap(FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first)
        let requestURL = support.appendingPathComponent("staygrubby-one-time-seed-request.json")
        guard FileManager.default.fileExists(atPath: requestURL.path) else {
            throw XCTSkip("No explicit, one-use development reset request")
        }
        let request = try JSONDecoder().decode(Request.self, from: Data(contentsOf: requestURL))
        func require(_ condition: Bool, _ message: String) throws {
            guard condition else { throw NSError(domain: "DevelopmentSeed", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        try require(UUID(uuidString: request.nonce) != nil && request.backupSHA256.count == 64, "Missing one-time authorization/backup")
        try require(ProcessInfo.processInfo.environment["SIMULATOR_UDID"] == request.simulatorID,
                    "Wrong Simulator: refusing to reset")
        try require(Bundle.main.bundleIdentifier == request.bundleID && request.bundleID == "com.guyrettig.Grub-Ranked",
                    "Wrong application: refusing to reset")
        let store = support.appendingPathComponent("default.store")
        try require(store.path.contains("/CoreSimulator/Devices/\(request.simulatorID)/data/Containers/Data/Application/"),
                    "Not the explicitly selected local Simulator store")
        let container = try AppPersistence.open(url: store) // Existing schema, CloudKit disabled.
        let context = ModelContext(container)
        let lists = try context.fetch(FetchDescriptor<RankingList>())
        try require(lists.count == 1 && lists[0].id.uuidString == request.globalRankingID, "Global ranking mismatch")
        let list = try CookingStore.globalRanking(context: context)
        let oldAttempts = try context.fetch(FetchDescriptor<CookingAttempt>())
        let oldDishes = try context.fetch(FetchDescriptor<Dish>())
        try require(list.items.map { $0.id.uuidString }.sorted() == request.itemIDs, "Ranked items changed since backup")
        try require(list.comparisons.map { $0.id.uuidString }.sorted() == request.comparisonIDs, "Evidence changed since backup")
        try require(oldAttempts.map { $0.id.uuidString }.sorted() == request.attemptIDs, "Cooks changed since backup")
        try require(oldDishes.map { $0.id.uuidString }.sorted() == request.dishIDs, "Dishes changed since backup")
        try require(Set(oldAttempts.map(\.rankedItemID)) == Set(list.items.map(\.id)), "Unrelated/orphan ranking data exists")
        try require(try context.fetchCount(FetchDescriptor<CookingTag>()) == request.tagCount, "Tags changed since backup")
        try require(try context.fetchCount(FetchDescriptor<CookingMedia>()) == 0, "Unexpected saved media; stop for inspection")
        try require(try context.fetchCount(FetchDescriptor<DishSource>()) == 0, "Unexpected saved Sources; stop for inspection")
        let unrelatedItems = try context.fetchCount(FetchDescriptor<Item>())
        let libraryID = try XCTUnwrap(context.fetch(FetchDescriptor<CookingLibrary>()).first?.globalRankingID)

        // Prove the complete seed works in an isolated store before deleting anything.
        let trial = try ModelContainer(for: AppPersistence.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let trialContext = ModelContext(trial)
        let trialList = try CookingStore.prepare(context: trialContext)
        _ = try seed(context: trialContext, list: trialList)
        try validate(context: trialContext, list: trialList)

        // Consume BEFORE mutation: retries/ordinary test runs cannot repeat the reset.
        try FileManager.default.removeItem(at: requestURL)
        for cook in oldAttempts { try CookingStore.delete(cook, context: context) }
        // Domain deletion nullifies tags. Remove only the now-unused old cooking tags.
        for tag in try context.fetch(FetchDescriptor<CookingTag>()) where tag.attempts.isEmpty { context.delete(tag) }
        try context.save()
        try require(list.items.isEmpty && list.comparisons.isEmpty, "Domain cleanup did not finish")
        _ = try seed(context: context, list: list)
        try validate(context: context, list: list)
        try require(list.id.uuidString == request.globalRankingID && libraryID == list.id, "Global identity changed")
        try require(try context.fetchCount(FetchDescriptor<Item>()) == unrelatedItems, "Unrelated sample items changed")
        let attempts = try context.fetch(FetchDescriptor<CookingAttempt>())
        let indexed = Dictionary(uniqueKeysWithValues: attempts.map { ($0.rankedItemID, $0) })
        let order = list.orderedItems.enumerated().map { rank, item -> [String: Any] in
            let cook = indexed[item.id]!
            return ["rank": rank + 1, "dish": cook.dish!.name, "version": cook.versionLabel,
                    "score": item.score, "strength": item.strength, "uncertainty": item.uncertainty,
                    "itemID": item.id.uuidString, "attemptID": cook.id.uuidString,
                    "course": cook.category.label, "source": cook.dish?.source?.summary ?? "No source",
                    "dietary": cook.dietaryTags.map(\.label).sorted(), "contains": cook.containedAllergens.map(\.label).sorted(),
                    "tags": cook.customTags, "notes": cook.notes ?? ""]
        }
        let report: [String: Any] = ["nonce": request.nonce, "globalRankingID": list.id.uuidString,
            "deleted": ["dishes": oldDishes.count, "attempts": oldAttempts.count, "rankedItems": request.itemIDs.count,
                        "comparisons": request.comparisonIDs.count, "orphanTags": request.tagCount, "sources": 0, "media": 0],
            "created": ["dishes": 12, "attempts": 15, "rankedItems": list.items.count, "comparisons": list.comparisons.count,
                        "sources": try context.fetchCount(FetchDescriptor<DishSource>()),
                        "tags": try context.fetchCount(FetchDescriptor<CookingTag>()), "media": 0], "order": order]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: support.appendingPathComponent("staygrubby-seed-report.json"), options: .atomic)
    }

    struct Random {
        var state: UInt64 = 0x57A96B8B
        mutating func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / Double(UInt64(1) << 53)
        }
    }
    @MainActor private func seed(context: ModelContext, list: RankingList) throws -> [CookingAttempt] {
        func source(_ type: DishSourceType, _ text: String = "") -> DishSourceDraft {
            var value = DishSourceDraft(type: type)
            switch type {
            case .cookbook: value.cookbookTitle = text
            case .restaurant: value.restaurantName = text
            case .onlineRecipe: value.onlineURL = text
            case .friendFamily: value.friendName = text
            case .other: value.otherName = text
            default: break
            }
            return value
        }
        struct Recipe {
            var name: String; var course: DishCategory; var title: String; var quality: Double
            var source: DishSourceDraft?; var dietary: Set<DietaryTag> = []; var contains: Set<Allergen> = []
            var tags: [String] = []; var notes = ""; var parent: Int?
        }
        // Attribution and allergen-presence tags are illustrative local review data.
        // Example.com is a reserved demo URL; no remote requests or safety claims.
        let recipes: [Recipe] = [
            Recipe(name: "Herb-Crusted Lamb Chops", course: .main, title: "Rosemary & Lemon", quality: 2.2,
                   source: source(.original), dietary: [.dairyFree], tags: ["Date Night", "Grilled"],
                   notes: "Rosemary, lemon zest and olive oil crust. Rested eight minutes before slicing."),
            Recipe(name: "Harissa Chicken Kabobs", course: .main, title: "Smoky Sunday", quality: 1.3,
                   source: source(.cookbook, "Weeknight Cooking"), dietary: [.dairyFree], tags: ["Weekend", "Grilled"],
                   notes: "Review fixture: olive-oil marinade with no milk ingredients; label is not a verified allergy guarantee. Charred peppers on the side."),
            Recipe(name: "Sea Bass with Corn Velouté", course: .main, title: "Summer Corn", quality: 1.6,
                   source: source(.restaurant, "Neighborhood Bistro"), contains: [.fish, .milk], tags: ["Dinner Party"],
                   notes: "Silky corn sauce, crisp skin and a squeeze of lemon."),
            Recipe(name: "Red Wine Braised Short Ribs", course: .main, title: "Sunday Braise", quality: 1.8,
                   source: source(.onlineRecipe, "https://example.com/cooking/short-ribs?method=slow-braise"), tags: ["Comfort Food", "Make Ahead"],
                   notes: "Reduced the sauce separately. Better after a night in the fridge."),
            Recipe(name: "Israeli Curried Couscous", course: .pastaNoodles, title: "", quality: -0.6,
                   source: nil, dietary: [.vegetarian, .vegan, .dairyFree], contains: [.wheat], tags: ["Weeknight"]),
            Recipe(name: "Matzo Ball Soup", course: .soup, title: "Family Friday", quality: -0.3,
                   source: source(.friendFamily, "Aunt Ruth"), contains: [.wheat, .egg], tags: ["Comfort Food"], notes: "Light matzo balls, plenty of dill. Use a wider pot next time."),
            Recipe(name: "Butter Chicken", course: .main, title: "Weeknight Curry", quality: 0.6,
                   source: source(.onlineRecipe, "https://example.com/cooking/butter-chicken?variant=weeknight#method"), contains: [.milk], tags: ["Weeknight", "Comfort Food"]),
            Recipe(name: "Persian Street Corn", course: .side, title: "Lime & Saffron", quality: -0.7,
                   source: source(.original), dietary: [.vegetarian], contains: [.milk], tags: ["Share Plates"], notes: "Saffron yogurt, lime and a little smoked paprika."),
            Recipe(name: "Tuna Crispy Rice", course: .appetizer, title: "First Try", quality: -1.0,
                   source: source(.restaurant, "Corner Sushi Bar"), contains: [.fish, .soy, .wheat, .sesame], tags: ["Test Kitchen"], notes: "Rice rectangles were too thick. Make a thinner layer next time."),
            Recipe(name: "Tomahawk Steak", course: .main, title: "Cast-Iron Finish", quality: 1.0,
                   source: nil, tags: ["Date Night"]),
            Recipe(name: "Moroccan Carrots", course: .salad, title: "Cumin & Orange", quality: -0.9,
                   source: source(.friendFamily, "Sam"), dietary: [.vegetarian, .vegan, .dairyFree], tags: ["Vegetable Forward"],
                   notes: "Review fixture ingredients: carrots, cumin, orange, parsley and olive oil, with no milk or egg ingredients. Labels do not verify cross-contact safety."),
            Recipe(name: "Lemon Olive Oil Cake with Toasted Almonds", course: .dessert, title: "Weekend Bake", quality: 0.2,
                   source: source(.cookbook, "The Baking Notebook"), dietary: [.vegetarian, .dairyFree], contains: [.treeNuts, .egg, .wheat], tags: ["Baking"],
                   notes: "Review fixture: olive oil in place of butter, no milk ingredients. Contains almonds, eggs and wheat; labels are not a verified allergy guarantee."),
            Recipe(name: "Herb-Crusted Lamb Chops", course: .main, title: "Mint & Garlic", quality: 0.9,
                   source: nil, dietary: [.dairyFree], tags: ["Date Night"], notes: "Softer crust than the lemon batch. More mint next time.", parent: 0),
            Recipe(name: "Harissa Chicken Kabobs", course: .main, title: "Oven-Roasted Batch", quality: -0.2,
                   source: nil, dietary: [.dairyFree], tags: ["Weeknight"],
                   notes: "Review fixture: milk-free ingredient list, not a safety certification. Marinade was too wet for browning.", parent: 1),
            Recipe(name: "Sea Bass with Corn Velouté", course: .main, title: "Brown Butter & Charred Corn", quality: 0.5,
                   source: nil, contains: [.fish, .milk], tags: ["Dinner Party"], parent: 2)
        ]
        var attempts: [CookingAttempt] = [], preferences: [UUID: Double] = [:]
        for (index, recipe) in recipes.enumerated() {
            let parent = recipe.parent.map { attempts[$0].dish! }
            var draft = parent.map(CookingDraft.init(dish:)) ?? CookingDraft()
            draft.dishName = recipe.name; draft.category = recipe.course; draft.versionTitle = recipe.title
            draft.cookedAt = Date(timeIntervalSince1970: 1_791_158_400 - Double((14 - index) * 86_400))
            if parent == nil { draft.source = recipe.source }
            draft.dietary = recipe.dietary; draft.contains = recipe.contains; draft.customTags = recipe.tags; draft.notes = recipe.notes
            var session = RankingEngine(itemID: UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: recipe.quality > 0 ? .liked : .fine)
            while let opponent = session.nextOpponent {
                let difference = recipe.quality - preferences[opponent]!
                session.answer(abs(difference) < 0.15 ? .tooTough : (difference > 0 ? .newItem : .existingItem))
            }
            let attempt = try CookingStore.create(draft: draft, existingDish: parent, session: session, context: context)
            attempts.append(attempt); preferences[attempt.rankedItemID] = recipe.quality
        }
        // Simulated preferences only; never assign strengths, uncertainty, scores or ranks.
        // Three rounds over every pair establish coverage and include close ties/upsets.
        var random = Random(); var evidence: [PreferenceEvidence] = []
        for round in 0..<3 {
            for first in 0..<attempts.count {
                for second in (first + 1)..<attempts.count {
                    let difference = recipes[first].quality - recipes[second].quality
                    let outcome = abs(difference) < 0.25 && random.next() < 0.3 ? 0.5 :
                        (random.next() < 1 / (1 + exp(-difference)) ? 1.0 : 0.0)
                    evidence.append(PreferenceEvidence(first: attempts[first].rankedItemID, second: attempts[second].rankedItemID,
                        outcome: outcome, timestamp: .now.addingTimeInterval(-Double(315 - evidence.count) * 60 - Double(2 - round))))
                }
            }
        }
        try RankingStore.record(evidence, in: list, context: context)
        return attempts
    }
    @MainActor private func validate(context: ModelContext, list: RankingList) throws {
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RankingList>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Dish>()), 12)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CookingAttempt>()), 15)
        XCTAssertEqual(list.items.count, 15)
        XCTAssertGreaterThanOrEqual(list.comparisons.count, 315)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Dish>()).filter { $0.attempts.count == 2 }.count, 3)
        let analysis = BradleyTerryModel.analyze(ids: list.items.map(\.id), evidence: list.comparisons.map(\.evidence))
        XCTAssertTrue(analysis.diagnostics.converged)
        XCTAssertEqual(analysis.diagnostics.ignoredEvidenceCount, 0)
        for item in list.items {
            let estimate = try XCTUnwrap(analysis.estimates[item.id])
            XCTAssertEqual(item.strength, estimate.strength, accuracy: 1e-7)
            XCTAssertEqual(item.score, estimate.score, accuracy: 1e-7)
            XCTAssertEqual(item.uncertainty, estimate.uncertainty, accuracy: 1e-7)
            XCTAssertLessThan(item.uncertainty, 1)
        }
        XCTAssertGreaterThan(list.orderedItems.first!.score - list.orderedItems.last!.score, 2)
    }
}
#endif
