#if DEBUG && targetEnvironment(simulator)
import Foundation
import SwiftData
import XCTest
@testable import Grub_Ranked

/// Outside all targets. Copy temporarily into unit tests for a single authorized
/// metadata update; never invoked by app startup or ordinary test discovery.
final class OneTimeDevelopmentAllergenUpdate: XCTestCase {
    struct Request: Decodable {
        let simulatorID: String; let globalRankingID: String
        let itemIDs: [String]; let attemptIDs: [String]; let comparisonIDs: [String]
        let dishIDs: [String]; let backupSHA256: String; let nonce: String
    }
    @MainActor func testUpdateExplicitlyAuthorizedSeedMetadata() throws {
        let support = try XCTUnwrap(FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first)
        let marker = support.appendingPathComponent("staygrubby-one-time-allergen-request.json")
        guard FileManager.default.fileExists(atPath: marker.path) else { throw XCTSkip("No one-time seed metadata request") }
        let request = try JSONDecoder().decode(Request.self, from: Data(contentsOf: marker))
        func require(_ value: Bool, _ message: String) throws {
            guard value else { throw NSError(domain: "SeedAllergens", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        let url = support.appendingPathComponent("default.store")
        try require(ProcessInfo.processInfo.environment["SIMULATOR_UDID"] == request.simulatorID, "Wrong Simulator")
        try require(Bundle.main.bundleIdentifier == "com.guyrettig.Grub-Ranked", "Wrong bundle")
        try require(url.path.contains("/CoreSimulator/Devices/\(request.simulatorID)/data/Containers/Data/Application/"), "Not local Simulator storage")
        try require(request.backupSHA256.count == 64 && UUID(uuidString: request.nonce) != nil, "Missing backup/one-time authorization")
        let container = try AppPersistence.open(url: url); let context = ModelContext(container)
        let list = try CookingStore.globalRanking(context: context)
        let attempts = try context.fetch(FetchDescriptor<CookingAttempt>())
        let dishes = try context.fetch(FetchDescriptor<Dish>())
        try require(try context.fetchCount(FetchDescriptor<RankingList>()) == 1 && list.id.uuidString == request.globalRankingID, "Ranking changed")
        try require(list.items.map { $0.id.uuidString }.sorted() == request.itemIDs, "Items changed")
        try require(attempts.map { $0.id.uuidString }.sorted() == request.attemptIDs && attempts.count == 15, "Cooks changed")
        try require(dishes.map { $0.id.uuidString }.sorted() == request.dishIDs && dishes.count == 12, "Dishes changed")
        try require(list.comparisons.map { $0.id.uuidString }.sorted() == request.comparisonIDs && list.comparisons.count == 356, "Evidence changed")
        let ingredients: [String: Set<Allergen>] = [
            "Herb-Crusted Lamb Chops": [], "Harissa Chicken Kabobs": [],
            "Sea Bass with Corn Velouté": [.fish, .milk], "Red Wine Braised Short Ribs": [],
            "Israeli Curried Couscous": [.wheat], "Matzo Ball Soup": [.wheat, .egg],
            "Butter Chicken": [.milk], "Persian Street Corn": [.milk],
            "Tuna Crispy Rice": [.fish, .soy, .wheat, .sesame], "Tomahawk Steak": [],
            "Moroccan Carrots": [], "Lemon Olive Oil Cake with Toasted Almonds": [.treeNuts, .egg, .wheat]
        ]
        try require(Set(dishes.map(\.name)) == Set(ingredients.keys), "Not the reviewed seed library")
        var tags = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<CookingTag>()).map { ($0.key, $0) })
        try FileManager.default.removeItem(at: marker) // consumed BEFORE any mutation
        for attempt in attempts {
            attempt.tags.removeAll { $0.kindCode == CookingTagKind.allergy.rawValue || $0.kindCode == CookingTagKind.contains.rawValue }
            for allergen in ingredients[attempt.dish!.name]!.sorted(by: { $0.rawValue < $1.rawValue }) {
                let key = "contains:\(allergen.rawValue)"
                let tag = tags[key] ?? CookingTag(kind: .contains, value: allergen.rawValue, label: allergen.label)
                if tags[key] == nil { context.insert(tag); tags[key] = tag }
                attempt.tags.append(tag)
            }
        }
        // Only disposable seed Free records are detached; ordinary editing preserves them.
        for tag in try context.fetch(FetchDescriptor<CookingTag>()) where tag.kindCode == CookingTagKind.allergy.rawValue && tag.attempts.isEmpty { context.delete(tag) }
        try context.save()
        XCTAssertTrue(attempts.allSatisfy { $0.allergyTags.isEmpty && $0.containedAllergens == ingredients[$0.dish!.name] })
        XCTAssertEqual(list.comparisons.count, 356)
        let report = attempts.map { ["dish": $0.dish!.name, "version": $0.versionLabel, "contains": $0.containedAllergens.map(\.label).sorted().joined(separator: ", ")] }
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: support.appendingPathComponent("staygrubby-allergen-update-report.json"))
    }
}
#endif
