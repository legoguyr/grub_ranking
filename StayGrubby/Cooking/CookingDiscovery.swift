import Foundation

/// Presentation state only. Discovery never writes models or invokes inference.
nonisolated struct CookingFilters: Equatable {
    var category: DishCategory?
    var dietary: Set<DietaryTag> = []
    var avoidedAllergens: Set<Allergen> = []

    var count: Int { (category == nil ? 0 : 1) + dietary.count + avoidedAllergens.count }
    var isActive: Bool { count > 0 }
}

@MainActor
enum CookingDiscovery {
    struct Entry: Identifiable {
        var id: UUID { attempt.id }
        let globalRank: Int
        let attempt: CookingAttempt
    }

    /// Build the bridge once, then walk the authoritative global order.
    /// Keep original ranks even when intervening entries do not match.
    static func entries(in list: RankingList, attempts: [CookingAttempt],
                        query: String = "", filters: CookingFilters = CookingFilters()) -> [Entry] {
        let byItem = Dictionary(attempts.map { ($0.rankedItemID, $0) }, uniquingKeysWith: { first, _ in first })
        let search = TagNormalization.key(query)
        return list.orderedItems.enumerated().compactMap { index, item in
            guard let attempt = byItem[item.id], matches(attempt, search: search, filters: filters) else { return nil }
            return Entry(globalRank: index + 1, attempt: attempt)
        }
    }

    private static func matches(_ attempt: CookingAttempt, search: String, filters: CookingFilters) -> Bool {
        if let category = filters.category, attempt.category != category { return false }
        let dietary = attempt.dietaryTags
        let allergies = attempt.allergyTags
        if !filters.dietary.isEmpty && dietary.isDisjoint(with: filters.dietary) { return false }
        if !attempt.containedAllergens.isDisjoint(with: filters.avoidedAllergens) { return false }
        guard !search.isEmpty else { return true }
        let fields = [attempt.dish?.name ?? attempt.rankedItem?.name ?? "", attempt.versionLabel,
                      attempt.category.label] + attempt.customTags + dietary.map(\.label) + allergies.map(\.label) + attempt.containedAllergens.map { "Contains \($0.label)" }
        return fields.contains { TagNormalization.key($0).contains(search) }
    }
}
