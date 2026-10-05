import Foundation
import SwiftData

@MainActor
enum AppPersistence {
    /// Existing model definitions are unchanged. New entities migrate additively;
    /// semantic legacy bridging is a separate idempotent transaction.
    static var schema: Schema {
        Schema([Item.self, RankingList.self, RankedItem.self, Comparison.self,
                Dish.self, DishSource.self, CookingAttempt.self, CookingMedia.self,
                CookingTag.self, CookingLibrary.self])
    }
    static func open(url: URL? = nil) throws -> ModelContainer {
        let schema = schema
        let config: ModelConfiguration
        if let url { config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none) }
        else { config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none) }
        return try ModelContainer(for: schema, configurations: [config])
    }
}
