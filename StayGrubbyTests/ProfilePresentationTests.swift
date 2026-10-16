import Foundation
import SwiftData
import Testing
@testable import StayGrubby

@MainActor struct ProfilePresentationTests {
    @Test(arguments: [0, 1, 2, 3, 9, 10, 12])
    func snapshotUsesRealGlobalEntriesAndProtectsScores(count: Int) throws {
        let f = try CookingReRankingWorkflowTests().fixture(count)
        defer { withExtendedLifetime(f) {} }
        let before = try CookingGraphExport.snapshot(context: f.context)
        let snapshot = ProfileSnapshot(context: f.context, list: f.list)
        let eligible = ScoreUnlockPolicy.entries(in: f.context, list: f.list)
        #expect(snapshot.rankedEntryCount == count)
        #expect(snapshot.dishCount == count)
        #expect(snapshot.topFoods.map(\.id) == Array(eligible.prefix(3)).map(\.id))
        #expect(snapshot.topFoods.map(\.rank) == Array(1...max(1, min(count, 3))).prefix(min(count, 3)).map { $0 })
        #expect(snapshot.scores == ScoreUnlockPolicy.state(in: f.context, list: f.list))
        for food in snapshot.topFoods {
            if count < 10 {
                #expect(food.scoreText == nil)
                #expect(food.accessibilityLabel.contains("score locked"))
            } else {
                let item = try #require(food.attempt.rankedItem)
                #expect(food.scoreText == snapshot.scores.scoreText(item.score))
                #expect(food.accessibilityLabel.contains("score \(try #require(food.scoreText))"))
            }
        }
        #expect((TopThreeShareCardModel.make(in: f.list) != nil) == snapshot.scores.isUnlocked)
        if count == 0 {
            #expect(snapshot.topFoods.isEmpty && snapshot.lastCookedAt == nil)
        }
        #expect(try CookingGraphExport.snapshot(context: f.context) == before)
        #expect(!f.context.hasChanges)
    }

    @Test func separatelyRankedVersionsCountAndUnlockRegardlessOfRankingsDisplayModeThenRelock() throws {
        let f = try CookingReRankingWorkflowTests().fixture(9)
        defer { withExtendedLifetime(f) {} }
        let dish = try #require(f.cooks.first?.dish)
        var draft = CookingDraft(dish: dish); draft.versionTitle = "Second version"
        var ranking = RankingEngine(itemID: UUID(), orderedIDs: f.list.orderedItems.map(\.id), reaction: .liked)
        while ranking.nextOpponent != nil { ranking.answer(.newItem) }
        let added = try CookingStore.create(draft: draft, existingDish: dish, session: ranking, context: f.context)
        let eligible = ScoreUnlockPolicy.entries(in: f.context)
        #expect(RankingsPresentation.entries(eligible, matching: eligible, mode: .topVersion).count == 9)
        let before = try CookingGraphExport.snapshot(context: f.context)
        let snapshot = ProfileSnapshot(context: f.context, list: f.list)
        #expect(snapshot.rankedEntryCount == 10 && snapshot.dishCount == 9)
        #expect(snapshot.scores.isUnlocked && snapshot.topFoods.allSatisfy { $0.scoreText != nil })
        #expect(snapshot.topFoods.map(\.id) == Array(eligible.prefix(3)).map(\.id))
        #expect(TopThreeShareCardModel.make(in: f.list) != nil)
        #expect(try CookingGraphExport.snapshot(context: f.context) == before)
        try CookingStore.delete(added, context: f.context)
        let relocked = ProfileSnapshot(context: f.context, list: f.list)
        #expect(relocked.rankedEntryCount == 9 && !relocked.scores.isUnlocked)
        #expect(relocked.topFoods.allSatisfy { $0.scoreText == nil && $0.accessibilityLabel.contains("score locked") })
        #expect(TopThreeShareCardModel.make(in: f.list) == nil)
    }

    @Test func retiredFoodAndUnknownCookingDatesDoNotInventActivity() throws {
        let f = try CookingReRankingWorkflowTests().fixture(3)
        defer { withExtendedLifetime(f) {} }
        for cook in f.cooks { cook.cookedAt = nil }
        let retired = try #require(f.cooks.first?.dish)
        f.context.insert(SyncTombstone(SyncReference(entity: .dish, key: retired.id.uuidString.lowercased())))
        try f.context.save()
        let before = try CookingGraphExport.snapshot(context: f.context)
        let snapshot = ProfileSnapshot(context: f.context, list: f.list)
        #expect(snapshot.rankedEntryCount == 2 && snapshot.dishCount == 2)
        #expect(!snapshot.topFoods.contains { $0.attempt.dish?.id == retired.id })
        #expect(snapshot.lastCookedAt == nil)
        #expect(snapshot.topFoods.allSatisfy { $0.attempt.primaryImage == nil && $0.scoreText == nil })
        #expect(try CookingGraphExport.snapshot(context: f.context) == before)
    }
}
