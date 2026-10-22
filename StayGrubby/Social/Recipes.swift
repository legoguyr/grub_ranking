import Foundation

/// A makeable recipe, never a Dish, ranked item, or private cooking graph.
nonisolated struct RecipeContent: Codable, Equatable, Sendable {
    var title = ""
    var description: String? = nil
    var ingredients: [String] = []
    var steps: [String] = []
    var course: String? = nil
    var cuisine: String? = nil
    var source: String? = nil
    var externalURL: String? = nil
}
nonisolated struct Recipe: Codable, Identifiable, Sendable {
    var id: UUID
    var isOwner: Bool
    var creator: SocialPerson?
    var content: RecipeContent
    var visibility: String
    var revision: Int
    var createdAt: Double
    var updatedAt: Double
    var saved: Bool
}
nonisolated struct RecipesPage: Codable { var recipes: [Recipe] }
nonisolated struct RecipeTicket: Codable, Identifiable { var id: UUID; var createdAt: Double; var recipe: Recipe? }
nonisolated struct TicketsPage: Codable { var tickets: [RecipeTicket] }
nonisolated struct RecipeCookSnapshot: Codable, Identifiable {
    var id: UUID
    var recipeID: UUID?
    var snapshot: RecipeContent
    var revision: Int
}
nonisolated struct RecipeCooksPage: Codable { var cooks: [RecipeCookSnapshot] }

@MainActor enum RecipeService {
    static func recipe(_ action: String, id: UUID, request: SocialRequest) async throws -> Recipe {
        try JSONDecoder().decode(Recipe.self, from: await request("recipes", action, .init(recipeID: id)))
    }
    static func begin(id: UUID, reservation: UUID, request: SocialRequest) async throws -> SocialCookingClaim {
        try JSONDecoder().decode(SocialCookingClaim.self, from: await request("recipes", "begin", .init(originID: reservation, recipeID: id)))
    }
}
