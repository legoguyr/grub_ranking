import Foundation
import SwiftData
import Testing
import UIKit
@testable import StayGrubby

@MainActor struct ScoreUnlockPolicyTests {
    private struct Fixture {
        let container: ModelContainer
        let context: ModelContext
        let list: RankingList
        let cooks: [CookingAttempt]
    }
    private func fixture(_ count: Int = 0) throws -> Fixture {
        let container = try ModelContainer(for: AppPersistence.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext
        let list = try CookingStore.prepare(context: context)
        let attempts = try (0..<count).map { try add("Dish \($0)", context: context) }
        return Fixture(container: container, context: context, list: list, cooks: attempts)
    }
    private func add(_ name: String, context: ModelContext, dish: Dish? = nil) throws -> CookingAttempt {
        let list = try CookingStore.globalRanking(context: context)
        var draft = CookingDraft(); draft.dishName = name; draft.category = .main
        var session = RankingEngine(itemID: UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: .liked)
        while session.nextOpponent != nil { session.answer(.newItem) }
        return try CookingStore.create(draft: draft, existingDish: dish, session: session, context: context)
    }

    @Test(arguments: Array(0...12)) func currentRankedEntryCountControlsVisibility(count: Int) throws {
        let f = try fixture(count)
        let (context, list, _) = (f.context, f.list, f.cooks)
        defer { withExtendedLifetime(f) {} }
        let before = try CookingGraphExport.snapshot(context: context)
        let state = ScoreUnlockPolicy.state(in: context, list: list)
        #expect(state.rankedEntryCount == count)
        #expect(state.isUnlocked == (count >= ScoreUnlockPolicy.requiredRankedEntryCount))
        #expect(state.remainingEntryCount == max(0, ScoreUnlockPolicy.requiredRankedEntryCount - count))
        #expect(state.progress == min(1, Double(count) / Double(ScoreUnlockPolicy.requiredRankedEntryCount)))
        #expect(try CookingGraphExport.snapshot(context: context) == before)
        #expect(!context.hasChanges)
    }

    @Test func nineDishesWithSecondVersionUnlockAndVersionDeletionRelocks() throws {
        let f = try fixture(9)
        defer { withExtendedLifetime(f) {} }
        let first = try #require(f.cooks.first)
        #expect(!ScoreUnlockPolicy.state(in: f.context).isUnlocked)
        let second = try add("Dish 0", context: f.context, dish: first.dish)
        #expect(f.list.items.count == 10)
        #expect(ScoreUnlockPolicy.state(in: f.context).rankedEntryCount == 10)
        #expect(ShareCardModel.make(for: second).scoreText != nil)
        try CookingStore.delete(second, context: f.context)
        #expect(ScoreUnlockPolicy.state(in: f.context).rankedEntryCount == 9)
        #expect(!ScoreUnlockPolicy.state(in: f.context).isUnlocked)
        #expect(first.dish != nil && first.rankedItem != nil)
    }

    @Test func crossingDoesNotRefitAndAllExistingValuesRevealThenRelock() throws {
        let f = try fixture(9)
        let (context, list, _) = (f.context, f.list, f.cooks)
        defer { withExtendedLifetime(f) {} }
        let beforeEvent = RankingCompletionSnapshot.capture(from: list)
        #expect(beforeEvent.eligibleRankedEntryCount == 9)
        let tenth = try add("Tenth", context: context)
        let graph = try CookingGraphExport.snapshot(context: context)
        let order = list.orderedItems.map(\.id), evidence = list.comparisons.map(\.id)
        let values = list.items.map { ($0.id, $0.strength, $0.uncertainty, $0.score) }
        #expect(ScoreUnlockPolicy.crossed(from: 9, to: ScoreUnlockPolicy.state(in: context)))
        for cook in try context.fetch(FetchDescriptor<CookingAttempt>()) {
            #expect(ShareCardModel.make(for: cook).scoreText != nil)
        }
        #expect(TopThreeShareCardModel.make(in: list) != nil)
        #expect(try CookingGraphExport.snapshot(context: context) == graph)
        #expect(list.orderedItems.map(\.id) == order && list.comparisons.map(\.id) == evidence)
        for (id, strength, uncertainty, score) in values {
            let item = try #require(list.items.first { $0.id == id })
            #expect(item.strength == strength && item.uncertainty == uncertainty && item.score == score)
        }
        try CookingStore.delete(tenth, context: context)
        #expect(!ScoreUnlockPolicy.state(in: context).isUnlocked)
        #expect(TopThreeShareCardModel.make(in: list) == nil)
        #expect(try context.fetch(FetchDescriptor<CookingAttempt>()).allSatisfy { ShareCardModel.make(for: $0).scoreText == nil })
    }

    @Test func draftsUnrankedHistoricalAndTombstonedBridgesDoNotCount() throws {
        let f = try fixture(9)
        let (context, list, cooks) = (f.context, f.list, f.cooks)
        defer { withExtendedLifetime(f) {} }
        let dish = Dish(name: "Unranked draft")
        let item = RankedItem(name: "Draft")
        let cook = CookingAttempt(item: item, sequence: 1, category: .main, cookedAt: .now)
        context.insert(dish); context.insert(item); context.insert(cook); dish.attempts.append(cook)
        list.items.append(item)
        #expect(ScoreUnlockPolicy.state(in: context).rankedEntryCount == 9)
        list.items.removeAll { $0.id == item.id }
        let historical = RankingList(name: "Historical"); context.insert(historical); historical.items.append(item)
        try context.save()
        #expect(ScoreUnlockPolicy.state(in: context).rankedEntryCount == 9)
        #expect(!ScoreUnlockPolicy.state(in: context, list: historical).isUnlocked)
        let existing = try #require(cooks.first?.dish)
        context.insert(SyncTombstone(SyncReference(entity: .dish, key: existing.id.uuidString.lowercased())))
        try context.save()
        #expect(ScoreUnlockPolicy.state(in: context).rankedEntryCount == 8)
    }

    @Test func remainingCopyUsesSingularAndThresholdConfiguration() {
        #expect(ScoreUnlockState(rankedEntryCount: 9).remainingText == "Rank 1 more dish or version to reveal your numerical scores.")
        #expect(ScoreUnlockState(rankedEntryCount: 0).remainingText.contains("10 more dishes or versions"))
        #expect(ScoreUnlockState(rankedEntryCount: 6).progressText == "6 / 10 dishes & versions ranked")
        #expect(ScoreUnlockState(rankedEntryCount: 9).scoreText(5.5) == nil)
        #expect(ScoreUnlockState(rankedEntryCount: 10).scoreText(5.5) == "5.5")
    }

    @Test(arguments: [SyncEntity.dish, .attempt, .rankedItem])
    func tombstonesExcludeEveryEligibleBridge(entity: SyncEntity) throws {
        let f = try fixture(10)
        defer { withExtendedLifetime(f) {} }
        let cook = try #require(f.cooks.first)
        let id = entity == .dish ? try #require(cook.dish).id : entity == .attempt ? cook.id : cook.rankedItemID
        f.context.insert(SyncTombstone(SyncReference(entity: entity, key: id.uuidString.lowercased())))
        try f.context.save()
        #expect(ScoreUnlockPolicy.state(in: f.context).rankedEntryCount == 9)
        #expect(ShareCardModel.make(for: cook).scoreText == nil)
    }

    @Test func unacceptedAccountStoreCannotExposeExistingScores() throws {
        let f = try fixture(10)
        defer { withExtendedLifetime(f) {} }
        let binding = SyncStoreBinding(accountID: UUID(), restorationRequired: true)
        f.context.insert(binding); try f.context.save()
        #expect(!ScoreUnlockPolicy.state(in: f.context).isUnlocked)
        #expect(TopThreeShareCardModel.make(in: f.list) == nil)
    }

    @Test func unsavedSelectedCookCannotBorrowUnlockedLibraryVisibility() throws {
        let f = try fixture(10)
        defer { withExtendedLifetime(f) {} }
        let dish = Dish(name: "Unsaved draft"), item = RankedItem(name: "Unsaved draft")
        let cook = CookingAttempt(item: item, sequence: 1, category: .main, cookedAt: .now)
        f.context.insert(dish); f.context.insert(item); f.context.insert(cook)
        dish.attempts.append(cook); f.list.items.append(item)
        #expect(ScoreUnlockPolicy.state(in: f.context).rankedEntryCount == 10)
        #expect(ShareCardModel.make(for: cook).scoreText == nil)
    }

    #if DEBUG
    @Test func scoreReviewRequiresIsolatedUUIDAndSupportedCount() {
        for args in [["--score-unlock-fixture", "10"], ["--ui-test-store", "invalid", "--score-unlock-fixture", "10"],
                     ["--ui-test-store", UUID().uuidString, "--score-unlock-fixture", "999"]] {
            #expect(DebugReviewConfiguration(arguments: args).scoreUnlockCount == nil)
        }
        #expect(DebugReviewConfiguration(arguments: ["--ui-test-store", UUID().uuidString, "--score-unlock-fixture", "10"]).scoreUnlockCount == 10)
    }
    #endif

    @Test func milestoneReceiptSurvivesRelaunchRelockAndAccountSwitchWithoutHydrationReplay() throws {
        let suite = "score-unlock-tests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let unlocked = ScoreUnlockState(rankedEntryCount: 10)
        #expect(!ScoreUnlockMilestones.claim(scope: "account.A", previous: nil, current: unlocked, defaults: defaults))
        #expect(!ScoreUnlockMilestones.claim(scope: "account.A", previous: 10, current: unlocked, defaults: defaults))
        #expect(ScoreUnlockMilestones.claim(scope: "account.A", previous: 9, current: unlocked, defaults: defaults))
        let reopened = try #require(UserDefaults(suiteName: suite))
        #expect(!ScoreUnlockMilestones.claim(scope: "account.A", previous: 9, current: .init(rankedEntryCount: 9), defaults: reopened))
        #expect(!ScoreUnlockMilestones.claim(scope: "account.A", previous: 9, current: unlocked, defaults: reopened))
        #expect(ScoreUnlockMilestones.claim(scope: "account.B", previous: 9, current: unlocked, defaults: reopened))
        #expect(ScoreUnlockMilestones.claim(scope: "development.A", previous: 9, current: unlocked, defaults: reopened))
        #expect(!ScoreUnlockMilestones.claim(scope: nil, previous: 9, current: unlocked, defaults: reopened))
    }

    @Test func localMilestonePreferencesHaveOwnAppRequiredReasonDeclaration() throws {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let manifest = try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
        let apis = try #require(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let defaults = try #require(apis.first { $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults" })
        #expect(defaults["NSPrivacyAccessedAPITypeReasons"] as? [String] == ["CA92.1"])
    }

    @Test func lockedFactoryCannotRenderIndividualOrTopThreeDespiteInternalCalibration() throws {
        let f = try fixture(1)
        let (context, list, cooks) = (f.context, f.list, f.cooks)
        defer { withExtendedLifetime(f) {} }
        let first = try #require(cooks.first)
        let model = ShareCardModel.make(for: first)
        #expect(model.scoreText == nil && abs((first.rankedItem?.score ?? 0) - 8.203937019662644) < 1e-12)
        #expect(throws: ShareCardRenderer.RenderError.scoresLocked) { try ShareCardRenderer.render(model: model, mediaRoot: nil) }
        #expect(TopThreeShareCardModel.make(in: list) == nil)
        #expect(!context.hasChanges)
    }

    @Test func topThreePreservesActualOrderAndTwoVersionsOfOneDish() throws {
        let f = try fixture(9)
        let (context, list, _) = (f.context, f.list, f.cooks)
        defer { withExtendedLifetime(f) {} }
        let first = try add("The tenth dish", context: context)
        _ = try add("The tenth dish", context: context, dish: first.dish)
        let model = try #require(TopThreeShareCardModel.make(in: list))
        let entries = ScoreUnlockPolicy.entries(in: context).prefix(3)
        #expect(model.rows.map(\.dish.title) == entries.map { $0.attempt.dish!.name })
        #expect(model.rows.prefix(2).allSatisfy { $0.dish.title == "The tenth dish" })
        #expect(model.rows.prefix(2).map(\.dish.versionSubtitle) == ["Version 2", "Version 1"])
        #expect(model.rows.map(\.position) == [1, 2, 3])
        #expect(model.rows.map(\.dish.scoreText) == entries.map { ScoreUnlockPolicy.state(in: context).scoreText($0.attempt.rankedItem!.score) })
    }

    @Test func acceptedHydrationDeterminesVisibilityWithoutGraphWrites() throws {
        let f = try fixture(10)
        let (context, _, _) = (f.context, f.list, f.cooks)
        defer { withExtendedLifetime(f) {} }
        let graph = try CookingGraphExport.snapshot(context: context)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("score-restore-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let owner = UUID()
        var accountGraph = graph; accountGraph.accountID = owner
        let store = try LocalStoreStartup.openAccount(owner, root: root)
        try store.restore(accountGraph, revision: 1)
        #expect(ScoreUnlockPolicy.state(in: store.container.mainContext).isUnlocked)
        #expect(try SyncJournal.pending(store.container.mainContext).isEmpty)
        #expect(try CookingGraphExport.snapshot(context: store.container.mainContext) == accountGraph.canonicalized())
    }
}
