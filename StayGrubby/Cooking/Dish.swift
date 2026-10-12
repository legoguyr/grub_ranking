import Foundation
import SwiftData

@Model
final class Dish {
    @Attribute(.unique) var id: UUID
    var name: String
    var defaultCategoryCode: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \CookingAttempt.dish) var attempts: [CookingAttempt] = []
    @Relationship(deleteRule: .cascade, inverse: \DishSource.dish) var source: DishSource?
    var defaultCategory: DishCategory {
        get { DishCategory(rawValue: defaultCategoryCode) ?? .other }
        set { defaultCategoryCode = newValue.rawValue }
    }
    init(name: String, category: DishCategory = .other, createdAt: Date = .now, id: UUID = UUID()) {
        self.id = id; self.name = name; defaultCategoryCode = category.rawValue; self.createdAt = createdAt
    }
}
