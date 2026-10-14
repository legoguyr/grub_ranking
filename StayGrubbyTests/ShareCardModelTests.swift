import Foundation
import SwiftData
import Testing
@testable import StayGrubby

@MainActor
struct ShareCardModelTests {
    private struct Fixture {
        let container: ModelContainer
        let context: ModelContext
        let list: RankingList
        let attempts: [CookingAttempt]
    }

    private func add(_ name: String, context: ModelContext, dish: Dish? = nil,
                     title: String? = nil) throws -> CookingAttempt {
        let list = try CookingStore.globalRanking(context: context)
        var draft = CookingDraft()
        draft.dishName = name; draft.versionTitle = title ?? ""; draft.category = .main
        var session = RankingEngine(itemID: UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: .liked)
        while session.nextOpponent != nil { session.answer(.newItem) }
        return try CookingStore.create(draft: draft, existingDish: dish, session: session, context: context)
    }

    private func fixture(_ count: Int = 6) throws -> Fixture {
        let container = try ModelContainer(for: AppPersistence.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let list = try CookingStore.prepare(context: context)
        var attempts: [CookingAttempt] = []
        for index in 0..<count { attempts.append(try add("Dish \(index)", context: context)) }
        return Fixture(container: container, context: context, list: list, attempts: attempts)
    }

    @Test func photoAndNoPhotoModelsCopyOnlyPermittedPresentationData() throws {
        let f = try fixture(1)
        let attempt = try #require(f.attempts.first)
        attempt.notes = "Private preparation notes"
        let noPhoto = ShareCardModel.make(for: attempt)
        #expect(noPhoto.title == "Dish 0" && noPhoto.photo == nil)
        #expect(noPhoto.versionSubtitle == nil && noPhoto.scoreText == nil && noPhoto.achievement == nil)
        #expect(attempt.rankedItem?.score == 5.5)
        let media = CookingMedia(id: UUID(), displayFilename: "display.jpg", thumbnailFilename: "thumb.jpg",
                                 pixelWidth: 800, pixelHeight: 600)
        f.context.insert(media); attempt.media.append(media)
        let photo = ShareCardModel.make(for: attempt)
        #expect(photo.photo == MediaTransfer(media))
        #expect(photo.title == noPhoto.title && photo.scoreText == noPhoto.scoreText)
        #expect(Set(Mirror(reflecting: photo).children.compactMap(\.label)) ==
            ["title", "versionSubtitle", "scoreText", "achievement", "photo"])
    }

    @Test func versionSubtitleAppearsOnlyForCustomTitleOrActualVersionHistory() throws {
        let f = try fixture(1)
        let original = try #require(f.attempts.first)
        #expect(ShareCardModel.make(for: original).versionSubtitle == nil)
        original.versionTitle = "  Sunday roast  "
        #expect(ShareCardModel.make(for: original).versionSubtitle == "Sunday roast")
        original.versionTitle = " \n "
        #expect(ShareCardModel.make(for: original).versionSubtitle == nil)
        let second = try add("Dish 0", context: f.context, dish: original.dish)
        #expect(ShareCardModel.make(for: original).versionSubtitle == "Version 1")
        #expect(ShareCardModel.make(for: second).versionSubtitle == "Version 2")
        second.versionTitle = "Extra crispy"
        #expect(ShareCardModel.make(for: second).versionSubtitle == "Extra crispy")
    }

    @Test(arguments: [(0.0, "5.5"), (2 * log(5.0), "8.5"), (-2 * log(5.0), "2.5")])
    func scoreUsesExistingMappingAndStableOneDecimal(strength: Double, expected: String) throws {
        let f = try fixture(ScoreUnlockPolicy.requiredRankedEntryCount)
        let attempt = try #require(f.attempts.first)
        let item = try #require(attempt.rankedItem)
        item.strength = strength
        let before = item.score
        #expect(ShareCardModel.make(for: attempt).scoreText == expected)
        #expect(item.score == before && item.strength == strength)
    }

    @Test func firstDishDoesNotInventAnAchievementEvenAtPositionOne() throws {
        let f = try fixture(0)
        let event = RankingCompletionSnapshot.capture(from: f.list)
        let first = try add("Roasted cauliflower", context: f.context)
        #expect(f.list.orderedItems.first?.id == first.rankedItemID)
        #expect(ShareCardModel.make(for: first, event: event).achievement == nil)
        #expect(ShareCardModel.make(for: first).achievement == nil)
    }

    @Test func newNumberOneIsAnEvidenceBackedEventAndDoesNotSurviveResharing() throws {
        let f = try fixture()
        let event = RankingCompletionSnapshot.capture(from: f.list)
        let winner = try add("Herb-Crusted Lamb Chops", context: f.context)
        #expect(event.leadingItemID != winner.rankedItemID && event.position(of: winner.rankedItemID) == nil)
        #expect(ShareCardModel.make(for: winner, event: event).achievement == .newNumberOne)
        #expect(ShareCardModel.make(for: winner).achievement == .topFive)
        let afterEvent = RankingCompletionSnapshot.capture(from: f.list)
        #expect(ShareCardModel.make(for: winner, event: afterEvent).achievement == .topFive)
    }

    @Test func rerankingAnExistingCookCanBecomeNewNumberOneButAnExistingLeaderCannot() throws {
        let f = try fixture()
        let lowest = try #require(f.attempts.first)
        let event = RankingCompletionSnapshot.capture(from: f.list)
        #expect(try #require(event.position(of: lowest.rankedItemID)) > 1)
        let wins = f.list.items.filter { $0.id != lowest.rankedItemID }.flatMap { opponent in
            (0..<24).map { _ in PreferenceEvidence(first: lowest.rankedItemID, second: opponent.id, outcome: 1) }
        }
        try CookingStore.rerank(lowest, evidence: wins, context: f.context)
        #expect(f.list.orderedItems.first?.id == lowest.rankedItemID)
        #expect(ShareCardModel.make(for: lowest, event: event).achievement == .newNumberOne)
        let alreadyFirst = RankingCompletionSnapshot.capture(from: f.list)
        try CookingStore.rerank(lowest, evidence: [try #require(wins.first)], context: f.context)
        #expect(ShareCardModel.make(for: lowest, event: alreadyFirst).achievement != .newNumberOne)
    }

    @Test func snapshotFromAnotherRankingCannotClaimNewNumberOne() throws {
        let f = try fixture()
        let wrong = RankingCompletionSnapshot(rankingID: UUID(), orderedItemIDs: f.list.orderedItems.map(\.id), comparisonIDs: [])
        let winner = try add("Duck Breast", context: f.context)
        #expect(ShareCardModel.make(for: winner, event: wrong).achievement == .topFive)
    }

    @Test func topFiveRequiresMeaningfulCurrentPositionAndEstablishedLibrary() throws {
        let small = try fixture(4)
        #expect(ShareCardModel.make(for: try #require(small.attempts.last)).achievement == nil)
        let f = try fixture()
        for attempt in f.attempts {
            let rank = try #require(f.list.orderedItems.firstIndex { $0.id == attempt.rankedItemID }) + 1
            #expect(ShareCardModel.make(for: attempt).achievement == (rank <= 5 ? .topFive : nil))
        }
    }

    @Test func bestVersionIsSpecificAndSupersedesTopFive() throws {
        let f = try fixture()
        let original = try #require(f.attempts.last)
        let second = try add(original.dish?.name ?? "Dish", context: f.context, dish: original.dish, title: "Sunday sear")
        #expect(ShareCardModel.make(for: second).achievement == .bestVersion)
        #expect(ShareCardModel.make(for: original).achievement != .bestVersion)
        let third = try add(original.dish?.name ?? "Dish", context: f.context, dish: original.dish)
        #expect(ShareCardModel.make(for: second).achievement != .bestVersion)
        #expect(ShareCardModel.make(for: third).achievement == .bestVersion)
    }

    @Test func eventNumberOneSupersedesBestVersionAndLaterShareUsesCurrentBestVersion() throws {
        let f = try fixture()
        let original = try #require(f.attempts.last)
        let event = RankingCompletionSnapshot.capture(from: f.list)
        let second = try add(original.dish?.name ?? "Dish", context: f.context, dish: original.dish)
        #expect(ShareCardModel.make(for: second, event: event).achievement == .newNumberOne)
        #expect(ShareCardModel.make(for: second).achievement == .bestVersion)
    }

    @Test func equalStrengthTieBreakDoesNotProveNewLeaderOrBestVersion() throws {
        let f = try fixture()
        let original = try #require(f.attempts.last)
        let event = RankingCompletionSnapshot.capture(from: f.list)
        let second = try add(original.dish?.name ?? "Dish", context: f.context, dish: original.dish)
        second.rankedItem?.strength = try #require(original.rankedItem).strength
        #expect(ShareCardModel.make(for: second, event: event).achievement != .newNumberOne)
        #expect(ShareCardModel.make(for: second).achievement != .bestVersion)
    }

    @Test func absentOrOnlyTieEvidenceCannotGenerateAnyBadge() throws {
        let f = try fixture()
        let attempt = try #require(f.attempts.last)
        let event = RankingCompletionSnapshot.capture(from: f.list)
        f.list.comparisons.removeAll()
        f.list.recompute()
        #expect(ShareCardModel.make(for: attempt, event: event).achievement == nil)
        let opponent = try #require(f.attempts.first)
        f.list.comparisons.append(Comparison(evidence: PreferenceEvidence(first: attempt.rankedItemID,
            second: opponent.rankedItemID, outcome: 0.5)))
        f.list.recompute()
        #expect(ShareCardModel.make(for: attempt, event: event).achievement == nil)
    }

    @Test func bestVersionCannotUseUnrankedOrLaterSiblingHistory() throws {
        let f = try fixture(1)
        let original = try #require(f.attempts.first)
        let second = try add("Dish 0", context: f.context, dish: original.dish)
        #expect(ShareCardModel.make(for: second).achievement == .bestVersion)
        let originalItem = original.rankedItem
        original.rankedItem = nil
        #expect(ShareCardModel.make(for: second).achievement == nil)
        original.rankedItem = originalItem
        original.sequenceNumber = second.sequenceNumber + 1
        #expect(ShareCardModel.make(for: second).achievement == nil)
    }

    @Test func missingVersionHistoryDoesNotProveBestVersionYet() throws {
        let f = try fixture(1)
        let original = try #require(f.attempts.first)
        let second = try add("Dish 0", context: f.context, dish: original.dish)
        let third = try add("Dish 0", context: f.context, dish: original.dish)
        #expect(ShareCardModel.make(for: third).achievement == .bestVersion)
        try CookingStore.delete(second, context: f.context)
        #expect(third.sequenceNumber == 3 && original.sequenceNumber == 1)
        #expect(ShareCardModel.make(for: third).achievement == nil)
    }

    @Test func buildingModelsAndSnapshotsDoesNotWriteOrRefitDomainData() throws {
        let f = try fixture()
        let graph = try CookingGraphExport.snapshot(context: f.context)
        let analysis = BradleyTerryModel.analyze(ids: f.list.items.map(\.id), evidence: f.list.comparisons.map(\.evidence))
        let snapshot = RankingCompletionSnapshot.capture(from: f.list)
        for _ in 0..<4 {
            for attempt in f.attempts {
                _ = ShareCardModel.make(for: attempt)
                _ = ShareCardModel.make(for: attempt, event: snapshot)
            }
        }
        #expect(try CookingGraphExport.snapshot(context: f.context) == graph)
        #expect(!f.context.hasChanges)
        let after = BradleyTerryModel.analyze(ids: f.list.items.map(\.id), evidence: f.list.comparisons.map(\.evidence))
        #expect(after.estimates == analysis.estimates)
        #expect(f.list.orderedItems.map(\.id) == snapshot.orderedItemIDs)
    }

    @Test func failedCookingSaveAndRetryKeepEventFactsAndPersistOnlyOneCompletion() throws {
        let f = try fixture()
        let before = try CookingGraphExport.snapshot(context: f.context)
        let failedEvent = RankingCompletionSnapshot.capture(from: f.list)
        var draft = CookingDraft(); draft.dishName = ""
        var session = RankingEngine(itemID: UUID(), orderedIDs: f.list.orderedItems.map(\.id), reaction: .liked)
        while session.nextOpponent != nil { session.answer(.newItem) }
        do {
            _ = try CookingStore.create(draft: draft, session: session, context: f.context)
            Issue.record("An invalid cook must not reach a persisted ranking result")
        } catch CookingStore.StoreError.invalidDraft { }
        #expect(try CookingGraphExport.snapshot(context: f.context) == before)
        #expect(RankingCompletionSnapshot.capture(from: f.list) == failedEvent)
        draft.dishName = "Harissa Chicken Kabobs"
        let retryEvent = RankingCompletionSnapshot.capture(from: f.list)
        let saved = try CookingStore.create(draft: draft, session: session, context: f.context)
        #expect(ShareCardModel.make(for: saved, event: retryEvent).achievement == .newNumberOne)
        #expect(f.list.items.count == before.items.count + 1)
        #expect(f.list.comparisons.count == before.comparisons.count + session.evidence.count)
        #expect(try f.context.fetchCount(FetchDescriptor<CookingAttempt>()) == f.attempts.count + 1)
    }

    @Test func skippedComparisonSessionDoesNotInventRankingEvidenceOrAnEvent() throws {
        let f = try fixture()
        let target = try #require(f.attempts.first)
        let before = try CookingGraphExport.snapshot(context: f.context)
        let snapshot = RankingCompletionSnapshot.capture(from: f.list)
        var session = ReRankingSession(itemID: target.rankedItemID,
            ids: f.list.items.map(\.id), history: f.list.comparisons.map(\.evidence))
        while session.nextOpponent != nil { session.answer(.skip) }
        #expect(!session.answers.isEmpty && session.evidence.isEmpty)
        #expect(ShareCardModel.make(for: target, event: snapshot).achievement != .newNumberOne)
        #expect(try CookingGraphExport.snapshot(context: f.context) == before)
        #expect(!f.context.hasChanges)
    }
}
