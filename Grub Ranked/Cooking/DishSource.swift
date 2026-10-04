import Foundation
import SwiftData

/// Attribution for the dish idea. A future Recipe remains a separate entity.
nonisolated enum DishSourceType: String, CaseIterable, Identifiable {
    case original, cookbook, restaurant, onlineRecipe, socialMedia, friendFamily, other

    var id: String { rawValue }
    var label: String {
        switch self {
        case .original: "Original / My Recipe"
        case .cookbook: "Cookbook"
        case .restaurant: "Restaurant"
        case .onlineRecipe: "Online Recipe"
        case .socialMedia: "Social Media"
        case .friendFamily: "Friend / Family"
        case .other: "Other"
        }
    }
}

@Model
final class DishSource {
    @Attribute(.unique) var id: UUID
    var typeCode: String
    var dish: Dish?
    var createdAt: Date
    var updatedAt: Date

    // Manual attribution only. A canonical Cookbook relationship can be added
    // later without changing these already saved source records.
    var cookbookTitle: String?
    var cookbookAuthors: String?
    var cookbookRecipeName: String?
    var cookbookPage: String?

    var restaurantName: String?
    var restaurantDishName: String?
    var restaurantLocation: String?

    var onlineRecipeName: String?
    var onlineWebsite: String?
    var onlineURL: String?

    var socialCreator: String?
    var socialPlatform: String?
    var socialURL: String?
    var socialDishName: String?

    var friendName: String?
    var friendNote: String?

    var otherName: String?
    var otherDetails: String?

    var type: DishSourceType {
        get { DishSourceType(rawValue: typeCode) ?? .other }
        set { typeCode = newValue.rawValue }
    }

    var summary: String {
        switch type {
        case .original: type.label
        case .cookbook: cookbookTitle.map { "Cookbook · \($0)" } ?? type.label
        case .restaurant: restaurantName.map { "Restaurant · \($0)" } ?? type.label
        case .onlineRecipe: onlineWebsite.map { "Online Recipe · \($0)" } ?? type.label
        case .socialMedia: socialCreator.map { "Social Media · \($0)" } ?? type.label
        case .friendFamily: friendName.map { "Friend / Family · \($0)" } ?? type.label
        case .other: otherName.map { "Other · \($0)" } ?? type.label
        }
    }

    var detailRows: [(label: String, value: String)] {
        let fields: [(String, String?)]
        switch type {
        case .original: fields = []
        case .cookbook: fields = [("Title", cookbookTitle), ("Authors", cookbookAuthors),
                                  ("Recipe", cookbookRecipeName), ("Page", cookbookPage)]
        case .restaurant: fields = [("Restaurant", restaurantName), ("Original dish", restaurantDishName),
                                    ("Location", restaurantLocation)]
        case .onlineRecipe: fields = [("Recipe", onlineRecipeName), ("Website / creator", onlineWebsite),
                                      ("URL", onlineURL)]
        case .socialMedia: fields = [("Creator", socialCreator), ("Platform", socialPlatform),
                                     ("Post / video URL", socialURL), ("Dish", socialDishName)]
        case .friendFamily: fields = [("Person", friendName), ("Note", friendNote)]
        case .other: fields = [("Name", otherName), ("Details", otherDetails)]
        }
        return fields.compactMap { label, value in value.map { (label: label, value: $0) } }
    }

    init(type: DishSourceType) {
        id = UUID(); typeCode = type.rawValue; createdAt = .now; updatedAt = .now
    }
}
