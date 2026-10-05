import Foundation
import SwiftData

@Model
final class CookingAttempt {
    @Attribute(.unique) var id: UUID
    /// A unique bridge key enforces one cooking attempt per generic ranking item.
    @Attribute(.unique) var rankedItemID: UUID
    var dish: Dish?
    @Relationship(deleteRule: .nullify) var rankedItem: RankedItem?
    /// Nil means unknown, used for legacy items; creation time is not a cooking date.
    var cookedAt: Date?
    var versionTitle: String?
    var notes: String?
    var categoryCode: String
    var sequenceNumber: Int
    var createdAt: Date
    var updatedAt: Date
    var isLegacyImport: Bool
    @Relationship(deleteRule: .nullify) var tags: [CookingTag] = []
    @Relationship(deleteRule: .cascade, inverse: \CookingMedia.attempt) var media: [CookingMedia] = []

    var category: DishCategory {
        get { DishCategory(rawValue: categoryCode) ?? .other }
        set { categoryCode = newValue.rawValue }
    }
    var versionLabel: String { versionTitle ?? "Version \(sequenceNumber)" }
    var displayName: String { "\(dish?.name ?? rankedItem?.name ?? "Dish") — \(versionLabel)" }
    var dietaryTags: Set<DietaryTag> { Set(tags.filter { $0.kindCode == CookingTagKind.dietary.rawValue }.compactMap { DietaryTag(rawValue: $0.value) }) }
    var allergyTags: Set<AllergyTag> { Set(tags.filter { $0.kindCode == CookingTagKind.allergy.rawValue }.compactMap { AllergyTag(rawValue: $0.value) }) }
    var customTags: [String] { tags.filter { $0.kindCode == CookingTagKind.custom.rawValue }.map(\.label).sorted() }
    var primaryImage: CookingMedia? {
        media.filter { $0.kind == .image }.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.createdAt < $1.createdAt
        }.first
    }

    init(item: RankedItem, sequence: Int, category: DishCategory, cookedAt: Date?, legacy: Bool = false) {
        id = UUID(); rankedItemID = item.id; rankedItem = item
        sequenceNumber = sequence; categoryCode = category.rawValue; self.cookedAt = cookedAt
        createdAt = item.createdAt; updatedAt = .now; isLegacyImport = legacy
    }
}
