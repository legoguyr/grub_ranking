import Foundation
import SwiftData
import Testing
@testable import StayGrubby

@MainActor struct RecipesLinksTests {
    @Test func routesAreExactAndDoNotAcceptPrivateObjectsOrRedirects() throws {
        let good = try #require(URL(string: "https://staygrubby.com/@friendly_cook"))
        #expect(AppRoute(url: good) == .profile("friendly_cook"))
        for value in ["http://staygrubby.com/@friendly_cook", "https://staygrubby.com.evil/@friendly_cook", "https://evil@staygrubby.com/@friendly_cook", "https://staygrubby.com:443/@friendly_cook", "https://staygrubby.com/@friendly_cook?next=private", "https://staygrubby.com/@friendly_cook#private", "https://staygrubby.com/@Friendly_Cook", "https://staygrubby.com/@ab", "https://staygrubby.com/@friendly_cook/private", "https://staygrubby.com/recipe/secret", "https://staygrubby.com/%40friendly_cook"] {
            #expect(AppRoute(url: try #require(URL(string: value))) == .invalid)
        }
        #expect(AppRoute.profileURL(username: "friendly_cook") == good)
        #expect(AppRoute.profileURL(username: "../private") == nil)
    }
    @Test func routerRetainsOnlyDestinationUntilAuthenticationReady() {
        let router = AppLinkRouter()
        router.receive(URL(string: "https://staygrubby.com/@first_cook")!)
        #expect(router.pending == .profile("first_cook"))
        router.receive(URL(string: "https://staygrubby.com/@second_cook")!)
        #expect(router.pending == .profile("second_cook"))
        router.pending = nil; #expect(router.pending == nil)
    }
    @Test func recipePrefillHasNoPrivateCookingFields() throws {
        let snapshot = RecipeContent(title: "Lemon soup", ingredients: ["Lemon"], steps: ["Simmer"], course: "soup", cuisine: "Italian", source: "Recipe author", externalURL: "https://example.com/soup")
        let claim = SocialCookingClaim(id: UUID(), itemID: UUID(), kind: "recipe", completed: false, metadata: .init(title: snapshot.title, course: snapshot.course), recipeOriginID: UUID(), recipeSnapshot: snapshot)
        let draft = claim.draft()
        #expect(draft.dishName == "Lemon soup" && draft.category == .soup && draft.cuisine?.id == "italian")
        #expect(draft.source?.onlineWebsite == "Recipe author" && draft.source?.onlineURL == "https://example.com/soup")
        #expect(draft.notes.isEmpty && draft.dietary.isEmpty && draft.contains.isEmpty && draft.allergy.isEmpty && !draft.hasPhoto)
    }
    @Test func recipeIntentSurvivesRelaunchAndNeverCreatesCookingUntilExistingSave() async throws {
        let container = try ModelContainer(for: AppPersistence.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext, list = try CookingStore.prepare(context: context)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), owner = UUID(), item = UUID(), claim = UUID()
        defer { try? FileManager.default.removeItem(at: root) }
        var calls = 0
        let request: SocialRequest = { endpoint, action, payload in
            #expect(endpoint == "recipes" && action == "complete" && payload.originID == claim)
            calls += 1; return Data("{}".utf8)
        }
        let worker = SharedCookingCoordinator(); worker.connect(context: context, root: root, owner: owner, request: request, sync: nil)
        let before = try CookingGraphExport.snapshot(context: context)
        try worker.record(itemID: item, participants: [], originID: nil, recipeOriginID: claim)
        await worker.retryNow(); #expect(calls == 0 && list.items.isEmpty)
        #expect(try CookingGraphExport.snapshot(context: context) == before)
        worker.disconnect()
        var draft = CookingDraft(); draft.dishName = "My recipe cook"
        _ = try CookingStore.create(draft: draft, session: RankingEngine(itemID: item, orderedIDs: [], reaction: .fine), context: context)
        let saved = try CookingGraphExport.snapshot(context: context)
        worker.connect(context: context, root: root, owner: owner, request: request, sync: nil)
        await worker.retryNow(); await worker.retryNow()
        #expect(calls == 1 && worker.intents.isEmpty && list.items.count == 1 && list.comparisons.isEmpty)
        #expect(try CookingGraphExport.snapshot(context: context) == saved)
        worker.disconnect()
    }
    @Test func legacySocialClaimDecodesWithoutRecipe() throws {
        let bytes = Data("{\"id\":\"\(UUID())\",\"itemID\":\"\(UUID())\",\"kind\":\"recreated\",\"completed\":false,\"metadata\":{\"title\":\"Legacy soup\"}}".utf8)
        let claim = try JSONDecoder().decode(SocialCookingClaim.self, from: bytes)
        #expect(claim.recipeOriginID == nil && claim.recipeSnapshot == nil && claim.draft().dishName == "Legacy soup")
    }
}
