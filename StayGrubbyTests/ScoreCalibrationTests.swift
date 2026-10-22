import Foundation
import SwiftData
import Testing
@testable import StayGrubby

@MainActor struct ScoreCalibrationTests {
    private func metadata(_ reaction: InitialReaction) -> Data { Data("{\"initialReaction\":\"\(reaction.rawValue)\"}".utf8) }
    private func score(_ s: Double, _ r: InitialReaction) -> Double { ScoreCalibration.score(strength: s, reaction: r) }

    @Test func candidatesExposeClampPlateausAndUnsafeBlending() {
        let strengths = [-4.0, -2, 0, 2, 4]
        let clamp = strengths.map { max(7.0, min(10.0, ScoreCalibration.score(strength: $0, reaction: nil))) }
        #expect(Set(clamp.prefix(3)).count == 1) // Three distinct estimates collapse at the floor.
        let blend = 0.55 * 8.5 + 0.45 * ScoreCalibration.score(strength: -4, reaction: nil)
        #expect(blend < 6) // A liked cook still communicates mediocrity.
        let selected = strengths.map { score($0, .liked) }
        #expect(Set(selected.map { String(format: "%.1f", $0) }).count == 5)
        #expect(selected.first! >= 7 && selected.last! < 10)
    }
    @Test(arguments: InitialReaction.allCases)
    func smoothMonotoneOverlappingRegions(_ reaction: InitialReaction) {
        let values = stride(from: -12.0, through: 12, by: 0.01).map { score($0, reaction) }
        let bounds: ClosedRange<Double> = reaction == .liked ? 7...10 : reaction == .fine ? 4.8...7.8 : 1...5.8
        #expect(values.allSatisfy { bounds.contains($0) })
        #expect(zip(values, values.dropFirst()).allSatisfy { $1 > $0 && $1 - $0 < 0.008 })
        #expect(score(4, .fine) > score(-4, .liked)) // Intentional overlap, not reaction-based ordering.
        #expect(score(4, .disliked) < 5.8)
        #expect(abs(score(0, .liked) - 8.203937019662644) < 1e-12)
        #expect(abs(score(0, .fine) - 6.3) < 1e-12)
        #expect(abs(score(0, .disliked) - 3.4) < 1e-12)
    }
    @Test(arguments: [1, 2, 9, 10, 15, 40])
    func realBradleyTerryCollectionsAndReactionChangesKeepOrdering(count: Int) {
        let ids = (1...count).map { UUID(uuidString: String(format: "90000000-0000-0000-0000-%012d", $0))! }
        var evidence: [PreferenceEvidence] = []
        for i in ids.indices { for j in ids.indices where i < j {
            for outcome in [1.0, 1, 0, 1] { evidence.append(.init(first: ids[i], second: ids[j], outcome: outcome, timestamp: Date(timeIntervalSince1970: 1000))) }
        } }
        let analysis = BradleyTerryModel.analyze(ids: ids, evidence: evidence)
        let list = RankingList(name: "Isolated calibration simulation")
        list.items = ids.map { id in let item = RankedItem(id: id, name: "Simulation"); item.strength = analysis.estimates[id]!.strength; return item }
        let order = list.orderedItems.map(\.id), strengths = list.items.map(\.strength)
        for reaction in InitialReaction.allCases {
            for item in list.items { item.sessionDiagnosticsData = metadata(reaction) }
            #expect(list.orderedItems.map(\.id) == order)
            #expect(list.items.map(\.strength) == strengths)
            let scores = list.orderedItems.map(\.score)
            #expect(scores.first! < 10 && scores.last! > 1)
            if count >= 10 { #expect(scores.first! - scores.last! > 0.5) }
            if reaction == .liked { #expect(scores.min()! >= 7) }
            if reaction == .disliked { #expect(scores.max()! < 5.8) }
            if count >= 15 && reaction == .liked {
                // Strong library, #11 explicitly liked: still a positive food-review score.
                #expect(scores[10] >= 7)
            }
        }
        for (n, item) in list.items.enumerated() { item.sessionDiagnosticsData = metadata(InitialReaction.allCases[n % 3]) }
        #expect(list.orderedItems.map(\.id) == order) // Mixed/contradictory reactions never reorder BT.
        let refit = BradleyTerryModel.analyze(ids: ids, evidence: evidence)
        #expect(ids.allSatisfy { analysis.estimates[$0]?.strength == refit.estimates[$0]?.strength })
    }
    @Test func sameDisplayedScoreDistinctRanksAndNoForcedEndpoint() {
        let list = RankingList(name: "Equal displayed scores")
        for s in [0.1, 0.1001] { let item = RankedItem(name: "Cook"); item.strength = s; item.sessionDiagnosticsData = metadata(.liked); list.items.append(item) }
        #expect(list.orderedItems[0].strength > list.orderedItems[1].strength)
        #expect(String(format: "%.1f", list.items[0].score) == String(format: "%.1f", list.items[1].score))
        #expect(list.orderedItems[0].score < 10)
    }
    @Test func reactionFallbackAndMetadataPreservation() throws {
        #expect(ScoreCalibration.reaction(in: nil) == nil)
        #expect(ScoreCalibration.reaction(in: Data("legacy".utf8)) == nil)
        let original = Data(#"{"initialReaction":"Liked it","unknownFutureField":{"keep":42},"latestSemanticReaction":"invalid"}"#.utf8)
        #expect(ScoreCalibration.reaction(in: original) == .liked)
        let updated = try ScoreCalibration.recording(.disliked, in: original)
        #expect(ScoreCalibration.reaction(in: updated) == .disliked)
        let fields = try #require(JSONSerialization.jsonObject(with: updated) as? [String: Any])
        #expect(fields["initialReaction"] as? String == InitialReaction.liked.rawValue)
        #expect((fields["unknownFutureField"] as? [String: Int])?["keep"] == 42)
        #expect(ScoreCalibration.score(strength: 0, metadata: nil) == 5.5)
        #expect(ScoreCalibration.score(strength: -2, metadata: original) > 7)
        #expect(ScoreCalibration.score(strength: 2, metadata: updated) < 5.8)
    }
    @Test func repeatedContradictionsAndDeletionUseUnchangedRefitWithPersistedReaction() throws {
        let container = try ModelContainer(for: AppPersistence.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext, list = try CookingStore.prepare(context: context)
        var cooks: [CookingAttempt] = []
        for n in 0..<10 {
            var draft = CookingDraft(); draft.dishName = "Simulated cook \(n)"
            var session = RankingEngine(itemID: UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: .liked)
            while session.nextOpponent != nil { session.answer(.newItem) }
            cooks.append(try CookingStore.create(draft: draft, session: session, context: context))
        }
        let first = cooks[0].rankedItem!, opponent = cooks[1].rankedItem!
        let metadata = first.sessionDiagnosticsData, original = Set(list.comparisons.map(\.id))
        let before = first.score
        let observations = (0..<24).map { PreferenceEvidence(first: first.id, second: opponent.id, outcome: $0 % 3 == 0 ? 0 : 1, timestamp: Date(timeIntervalSince1970: Double($0))) }
        try RankingStore.record(observations, in: list, context: context)
        #expect(first.score != before && first.score >= 7)
        #expect(first.sessionDiagnosticsData == metadata)
        #expect(original.isSubset(of: Set(list.comparisons.map(\.id))))
        let expected = BradleyTerryModel.analyze(ids: list.items.map(\.id), evidence: list.comparisons.map(\.evidence))
        #expect(list.items.allSatisfy { abs($0.strength - expected.estimates[$0.id]!.strength) < 1e-12 })
        try CookingStore.delete(cooks[9], context: context)
        #expect(ScoreUnlockPolicy.state(in: context).rankedEntryCount == 9)
        #expect(ShareCardModel.make(for: cooks[0]).scoreText == nil)
        #expect(first.sessionDiagnosticsData == metadata && first.score >= 7)
        let refit = BradleyTerryModel.analyze(ids: list.items.map(\.id), evidence: list.comparisons.map(\.evidence))
        #expect(list.items.allSatisfy { abs($0.strength - refit.estimates[$0.id]!.strength) < 1e-12 })
    }

}
