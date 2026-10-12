import Foundation

/// Beta-editable product selections. Persisted enum codes remain stable.
nonisolated enum CookingProductOptions {
    static let courseTitle = "Course"
    static let courses = DishCategory.allCases
    static let dietary = DietaryTag.allCases
    static let allergens = Allergen.allCases
    static let allergenSafetyText = "Based on the allergens you’ve marked. Not marked contains does not mean allergen-free. Always verify ingredients for allergy safety."
    static let sources = SourceChoice.allCases
}

/// Six presentation choices over seven compatible persisted Source codes.
nonisolated enum SourceChoice: String, CaseIterable, Identifiable {
    case myOwn, online, cookbook, restaurant, friendFamily, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .myOwn: "My Own"
        case .online: "Online"
        case .cookbook: "Cookbook"
        case .restaurant: "Restaurant"
        case .friendFamily: "Friend / Family"
        case .other: "Other"
        }
    }
    var storedType: DishSourceType {
        switch self {
        case .myOwn: .original
        case .online: .onlineRecipe
        case .cookbook: .cookbook
        case .restaurant: .restaurant
        case .friendFamily: .friendFamily
        case .other: .other
        }
    }
    init(type: DishSourceType) {
        switch type {
        case .original: self = .myOwn
        case .onlineRecipe, .socialMedia: self = .online
        case .cookbook: self = .cookbook
        case .restaurant: self = .restaurant
        case .friendFamily: self = .friendFamily
        case .other: self = .other
        }
    }
}
