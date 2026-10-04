import Foundation
import SwiftData

/// Value-only form state; a new version reads the Dish's source without saving a copy.
@MainActor struct DishSourceDraft {
    var type: DishSourceType = .original
    var cookbookTitle = ""
    var cookbookAuthors = ""
    var cookbookRecipeName = ""
    var cookbookPage = ""
    var restaurantName = ""
    var restaurantDishName = ""
    var restaurantLocation = ""
    var onlineRecipeName = ""
    var onlineWebsite = ""
    var onlineURL = ""
    var socialCreator = ""
    var socialPlatform = ""
    var socialURL = ""
    var socialDishName = ""
    var friendName = ""
    var friendNote = ""
    var otherName = ""
    var otherDetails = ""

    init(type: DishSourceType = .original) { self.type = type }
    init(source: DishSource) {
        type = source.type
        cookbookTitle = source.cookbookTitle ?? ""
        cookbookAuthors = source.cookbookAuthors ?? ""
        cookbookRecipeName = source.cookbookRecipeName ?? ""
        cookbookPage = source.cookbookPage ?? ""
        restaurantName = source.restaurantName ?? ""
        restaurantDishName = source.restaurantDishName ?? ""
        restaurantLocation = source.restaurantLocation ?? ""
        onlineRecipeName = source.onlineRecipeName ?? ""
        onlineWebsite = source.onlineWebsite ?? ""
        onlineURL = source.onlineURL ?? ""
        socialCreator = source.socialCreator ?? ""
        socialPlatform = source.socialPlatform ?? ""
        socialURL = source.socialURL ?? ""
        socialDishName = source.socialDishName ?? ""
        friendName = source.friendName ?? ""
        friendNote = source.friendNote ?? ""
        otherName = source.otherName ?? ""
        otherDetails = source.otherDetails ?? ""
    }
    var summary: String {
        switch type {
        case .original: type.label
        case .cookbook: label(type.label, cookbookTitle)
        case .restaurant: label(type.label, restaurantName)
        case .onlineRecipe: label(type.label, onlineWebsite)
        case .socialMedia: label(type.label, socialCreator)
        case .friendFamily: label(type.label, friendName)
        case .other: label(type.label, otherName)
        }
    }
    private func label(_ type: String, _ name: String) -> String {
        guard let name = CookingDraft.optional(name) else { return type }
        return "\(type) · \(name)"
    }

    /// Clear fields from other types before applying the selected attribution.
    func apply(to source: DishSource) {
        source.type = type
        source.cookbookTitle = nil; source.cookbookAuthors = nil
        source.cookbookRecipeName = nil; source.cookbookPage = nil
        source.restaurantName = nil; source.restaurantDishName = nil; source.restaurantLocation = nil
        source.onlineRecipeName = nil; source.onlineWebsite = nil; source.onlineURL = nil
        source.socialCreator = nil; source.socialPlatform = nil; source.socialURL = nil; source.socialDishName = nil
        source.friendName = nil; source.friendNote = nil
        source.otherName = nil; source.otherDetails = nil
        switch type {
        case .original: break
        case .cookbook:
            source.cookbookTitle = CookingDraft.optional(cookbookTitle)
            source.cookbookAuthors = CookingDraft.optional(cookbookAuthors)
            source.cookbookRecipeName = CookingDraft.optional(cookbookRecipeName)
            source.cookbookPage = CookingDraft.optional(cookbookPage)
        case .restaurant:
            source.restaurantName = CookingDraft.optional(restaurantName)
            source.restaurantDishName = CookingDraft.optional(restaurantDishName)
            source.restaurantLocation = CookingDraft.optional(restaurantLocation)
        case .onlineRecipe:
            source.onlineRecipeName = CookingDraft.optional(onlineRecipeName)
            source.onlineWebsite = CookingDraft.optional(onlineWebsite)
            source.onlineURL = CookingDraft.optional(onlineURL)
        case .socialMedia:
            source.socialCreator = CookingDraft.optional(socialCreator)
            source.socialPlatform = CookingDraft.optional(socialPlatform)
            source.socialURL = CookingDraft.optional(socialURL)
            source.socialDishName = CookingDraft.optional(socialDishName)
        case .friendFamily:
            source.friendName = CookingDraft.optional(friendName)
            source.friendNote = CookingDraft.optional(friendNote)
        case .other:
            source.otherName = CookingDraft.optional(otherName)
            source.otherDetails = CookingDraft.optional(otherDetails)
        }
        source.updatedAt = .now
    }
}

@MainActor
enum DishSourceStore {
    /// Called inside CookingStore's existing create/edit transaction.
    static func apply(_ draft: DishSourceDraft?, to dish: Dish, context: ModelContext) {
        guard let draft else {
            if let source = dish.source {
                dish.source = nil
                context.delete(source)
            }
            return
        }
        let source: DishSource
        if let existing = dish.source { source = existing }
        else { source = DishSource(type: draft.type); context.insert(source); dish.source = source }
        draft.apply(to: source)
    }
}
