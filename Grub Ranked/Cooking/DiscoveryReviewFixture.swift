#if DEBUG
import Foundation
import SwiftData
import UIKit

/// Opt-in review data, permitted only by the app's explicit isolated-store path.
@MainActor
enum DiscoveryReviewFixture {
    static func seed(container: ModelContainer) throws {
        let context = ModelContext(container)
        let list = try CookingStore.prepare(context: context)
        guard list.items.isEmpty else { return }

        func create(_ draft: CookingDraft, dish: Dish? = nil) throws -> CookingAttempt {
            var session = RankingEngine(itemID: UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: .liked)
            while session.nextOpponent != nil { session.answer(.newItem) }
            return try CookingStore.create(draft: draft, existingDish: dish, session: session, context: context)
        }

        var cake = CookingDraft(); cake.dishName = "Apple Cake"; cake.category = .dessert
        cake.dietary = [.vegetarian]; cake.allergy = [.peanutFree]
        _ = try create(cake)
        var pasta = CookingDraft(); pasta.dishName = "Lemon Pasta"; pasta.category = .pastaNoodles
        pasta.dietary = [.vegan]; pasta.allergy = [.milkFree, .sesameFree]; pasta.customTags = ["Weeknight"]
        _ = try create(pasta)
        var bass = CookingDraft(); bass.dishName = "Sea Bass"; bass.category = .main
        bass.dietary = [.kosher]; bass.allergy = [.peanutFree]
        _ = try create(bass)
        var chicken = CookingDraft(); chicken.dishName = "Harissa Chicken"; chicken.category = .main
        chicken.versionTitle = "Golden sear"; chicken.dietary = [.kosher, .dairyFree]
        chicken.allergy = [.sesameFree]; chicken.customTags = ["Date Night"]
        var source = DishSourceDraft(type: .cookbook); source.cookbookTitle = "Zahav"
        chicken.source = source
        let first = try create(chicken)
        chicken.versionTitle = "Smoky Sunday"
        chicken.dietary = [.halal]; chicken.allergy = [.peanutFree]
        let data = UIGraphicsImageRenderer(size: CGSize(width: 360, height: 240)).jpegData(withCompressionQuality: 0.8) { context in
            UIColor.systemOrange.setFill(); context.fill(CGRect(x: 0, y: 0, width: 360, height: 240))
        }
        chicken.pendingPhoto = try LocalPhotoStore.prepare(data: data)
        _ = try create(chicken, dish: first.dish)
    }
}
#endif
