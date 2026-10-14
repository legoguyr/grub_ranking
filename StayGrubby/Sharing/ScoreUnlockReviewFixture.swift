#if DEBUG
import Foundation
import SwiftData
import UIKit

/// Explicit temporary store/media UUID only; cannot seed the demo/account store.
@MainActor enum ScoreUnlockReviewFixture {
    static func seed(container: ModelContainer, mediaRoot: URL, count: Int) throws {
        guard DebugReviewConfiguration.current.storeID != nil,
              DebugReviewConfiguration.current.mediaRoot(in: FileManager.default.temporaryDirectory) == mediaRoot else { return }
        let context = container.mainContext
        let list = try CookingStore.prepare(context: context)
        guard list.items.isEmpty else { return }
        let names = ["Matzo Ball Soup", "Duck Breast", "Butter Chicken", "Persian Street Corn",
                     "Tuna Crispy Rice", "Tomahawk Steak", "Moroccan Carrots", "Roasted Cauliflower",
                     "Sea Bass with Corn Velouté", "Harissa Chicken Kabobs", "Roasted Pepper Tartare", "Apple Cake"]
        func add(_ draft: CookingDraft, dish: Dish? = nil) throws -> CookingAttempt {
            var session = RankingEngine(itemID: UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: .liked)
            while session.nextOpponent != nil { session.answer(.newItem) }
            return try CookingStore.create(draft: draft, existingDish: dish, session: session,
                context: context, mediaDirectory: mediaRoot)
        }
        var last: CookingAttempt?
        for index in 0..<(count > 1 ? count - 1 : count) {
            var draft = CookingDraft()
            draft.dishName = index < names.count ? names[index] : "Roasted vegetable variation \(index + 1)"
            draft.category = .main
            last = try add(draft)
        }
        if count > 1, let last, let dish = last.dish {
            var draft = CookingDraft(dish: dish); draft.versionTitle = "Crispier Sunday version"
            let bytes = UIGraphicsImageRenderer(size: CGSize(width: 360, height: 240)).pngData { context in
                UIColor.systemBlue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 360, height: 240))
            }
            draft.pendingPhoto = try LocalPhotoStore.prepare(data: bytes)
            _ = try add(draft, dish: dish)
        }
    }
}
#endif
