import Foundation

@MainActor struct CookingDraft {
    var dishName = ""
    var category: DishCategory = .main
    var cookedAt: Date? = .now
    var versionTitle = ""
    var notes = ""
    var dietary: Set<DietaryTag> = []
    var allergy: Set<AllergyTag> = []
    var customTags: [String] = []
    var source: DishSourceDraft?
    var existingPhoto: CookingMedia?
    var pendingPhoto: PreparedCookingPhoto?
    var removeExistingPhoto = false

    init() {}
    init(dish: Dish) {
        dishName = dish.name; category = dish.defaultCategory
        source = dish.source.map(DishSourceDraft.init(source:))
    }
    init(attempt: CookingAttempt) {
        dishName = attempt.dish?.name ?? attempt.rankedItem?.name ?? ""
        category = attempt.category; cookedAt = attempt.cookedAt
        versionTitle = attempt.versionTitle ?? ""; notes = attempt.notes ?? ""
        dietary = attempt.dietaryTags; allergy = attempt.allergyTags; customTags = attempt.customTags
        source = attempt.dish?.source.map(DishSourceDraft.init(source:))
        existingPhoto = attempt.primaryImage
    }
    var hasPhoto: Bool { pendingPhoto != nil || (existingPhoto != nil && !removeExistingPhoto) }
    var cleanDishName: String { dishName.trimmingCharacters(in: .whitespacesAndNewlines) }
    var cleanTitle: String? { Self.optional(versionTitle) }
    static func optional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
