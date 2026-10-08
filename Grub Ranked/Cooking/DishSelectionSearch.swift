import Foundation

@MainActor enum DishSelectionSearch {
    /// Value-only projection: selecting/searching a parent never creates records.
    static func matches(_ dishes: [Dish], query: String) -> [Dish] {
        let normalized = TagNormalization.key(query)
        return dishes.filter { normalized.isEmpty || TagNormalization.key($0.name).contains(normalized) }
    }
}
