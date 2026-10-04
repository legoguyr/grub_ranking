import Foundation

nonisolated enum DishCategory: String, CaseIterable, Identifiable {
    case main, appetizer, side, soup, salad, pastaNoodles, sandwich, breakfastBrunch, snack, dessert, bakedGood, sauceCondiment, drink, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .main: "Main"
        case .appetizer: "Appetizer"
        case .side: "Side"
        case .soup: "Soup"
        case .salad: "Salad"
        case .pastaNoodles: "Pasta/Noodles"
        case .sandwich: "Sandwich"
        case .breakfastBrunch: "Breakfast/Brunch"
        case .snack: "Snack"
        case .dessert: "Dessert"
        case .bakedGood: "Baked Good"
        case .sauceCondiment: "Sauce/Condiment"
        case .drink: "Drink"
        case .other: "Other"
        }
    }
}

nonisolated enum DietaryTag: String, CaseIterable, Identifiable {
    case kosher, vegetarian, vegan, dairyFree, glutenFree, halal
    var id: String { rawValue }
    var label: String {
        switch self {
        case .kosher: "Kosher"
        case .vegetarian: "Vegetarian"
        case .vegan: "Vegan"
        case .dairyFree: "Dairy-Free"
        case .glutenFree: "Gluten-Free"
        case .halal: "Halal"
        }
    }
}

nonisolated enum AllergyTag: String, CaseIterable, Identifiable {
    case peanutFree, treeNutFree, sesameFree, milkFree, eggFree, wheatFree, soyFree, fishFree, shellfishFree
    var id: String { rawValue }
    var label: String {
        switch self {
        case .peanutFree: "Peanut-Free"
        case .treeNutFree: "Tree-Nut-Free"
        case .sesameFree: "Sesame-Free"
        case .milkFree: "Milk-Free"
        case .eggFree: "Egg-Free"
        case .wheatFree: "Wheat-Free"
        case .soyFree: "Soy-Free"
        case .fishFree: "Fish-Free"
        case .shellfishFree: "Shellfish-Free"
        }
    }
}

nonisolated enum CookingTagKind: String { case dietary, allergy, custom }

nonisolated enum TagNormalization {
    static func display(_ text: String) -> String { text.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
    static func key(_ text: String) -> String {
        display(text).folding(options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
    static func deduplicated(_ labels: [String]) -> [String] {
        var seen = Set<String>()
        return labels.map(display).filter { !$0.isEmpty && seen.insert(key($0)).inserted }
    }
}
