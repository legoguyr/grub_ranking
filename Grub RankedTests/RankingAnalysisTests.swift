import Foundation
import Testing
import SwiftData
@testable import Grub_Ranked

struct RankingAnalysisTests {
    private let a = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let b = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let c = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    private let d = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!

    @Test func analyticCovarianceAndUnconnectedPrior() throws {
        let posterior = BradleyTerryModel.analyze(ids: [a, b, c], evidence: [PreferenceEvidence(first: a, second: b, outcome: 0.5)])
        // H = [[.5, -.25], [-.25, .5]], so H^-1 has diag 8/3, off-diag 4/3.
        #expect(abs(posterior.estimates[a]!.uncertainty * posterior.estimates[a]!.uncertainty - 8.0 / 3) < 1e-10)
        #expect(abs(try #require(posterior.relationship(a, b)).standardDeviation - sqrt(8.0 / 3)) < 1e-10)
        #expect(posterior.estimates[c]!.uncertainty == 2)
        #expect(posterior.relationship(a, a) == nil)
        #expect(posterior.relationship(a, UUID()) == nil)
        #expect(posterior.diagnostics.converged)
        #expect(BradleyTerryModel.analyze(ids: [], evidence: []).rankEstimates().isEmpty)
    }

    @Test func repeatedEvidenceReducesUncertaintyAndContradictionsRemainFinite() throws {
        let win = PreferenceEvidence(first: a, second: b, outcome: 1)
        let once = BradleyTerryModel.analyze(ids: [a, b], evidence: [win])
        let many = BradleyTerryModel.analyze(ids: [a, b], evidence: Array(repeating: win, count: 100))
        #expect(many.estimates[a]!.strength > once.estimates[a]!.strength)
        #expect(many.relationship(a, b)!.standardDeviation < once.relationship(a, b)!.standardDeviation)
        let loss = PreferenceEvidence(first: a, second: b, outcome: 0)
        let conflicting = BradleyTerryModel.analyze(ids: [a, b], evidence: Array(repeating: win, count: 100) + Array(repeating: loss, count: 100))
        #expect(abs(conflicting.estimates[a]!.strength) < 1e-7)
        #expect(conflicting.relationship(a, b)!.informationGainBits < once.relationship(a, b)!.informationGainBits)
        #expect(conflicting.diagnostics.converged)
    }

    @Test func refinementChoosesUncertainRegionAndAvoidsKnownTie() throws {
        var evidence: [PreferenceEvidence] = []
        for _ in 0..<200 {
            evidence += [PreferenceEvidence(first: a, second: b, outcome: 1),
                         PreferenceEvidence(first: a, second: c, outcome: 1),
                         PreferenceEvidence(first: b, second: d, outcome: 1),
                         PreferenceEvidence(first: c, second: d, outcome: 1)]
        }
        let model = BradleyTerryModel.analyze(ids: [a, b, c, d], evidence: evidence)
        #expect(model.relationship(a, d)!.orderConfidence > 0.975)
        #expect(try #require(model.nextRefinement()).pair == ComparisonPair(b, c))
        #expect(model.nextRefinement(excluding: [ComparisonPair(b, c)]) == nil)
        let uncertain = UUID()
        let knownTie = Array(repeating: PreferenceEvidence(first: b, second: c, outcome: 0.5), count: 1000)
        let updated = BradleyTerryModel.analyze(ids: [b, c, uncertain], evidence: knownTie)
        let suggestion = try #require(updated.nextRefinement())
        #expect(suggestion.pair.first == uncertain || suggestion.pair.second == uncertain)
        #expect(updated.relationship(b, c)!.informationGainBits < 0.01)
        #expect(BradleyTerryModel.analyze(ids: [b, c], evidence: knownTie).nextRefinement() == nil)
    }

    @Test func globalRecomputePropagatesThroughGraph() {
        let evidence = [PreferenceEvidence(first: a, second: b, outcome: 1),
                        PreferenceEvidence(first: b, second: c, outcome: 1)]
        let before = BradleyTerryModel.analyze(ids: [a, b, c, d], evidence: evidence)
        let new = Array(repeating: PreferenceEvidence(first: c, second: b, outcome: 1), count: 30)
        let after = BradleyTerryModel.analyze(ids: [a, b, c, d], evidence: evidence + new)
        #expect(abs(before.estimates[a]!.strength - after.estimates[a]!.strength) > 0.01)
        #expect(after.estimates[c]!.strength > after.estimates[b]!.strength)
        #expect(after.estimates[d] == before.estimates[d])
        let replay = BradleyTerryModel.analyze(ids: [d, c, b, a], evidence: evidence + new)
        #expect(after.estimates == replay.estimates)
    }

    @Test func jointRankIntervalsAreBoundedAndContractWithEvidence() {
        let prior = BradleyTerryModel.analyze(ids: [a, b, c], evidence: [])
        let wide = prior.rankEstimates()
        #expect(abs(wide[a]!.expectedRank - 2) < 1e-10)
        #expect(wide[a]!.lower95 == 1 && wide[a]!.upper95 == 3)
        let observations = (0..<100).flatMap { _ in [PreferenceEvidence(first: a, second: b, outcome: 1), PreferenceEvidence(first: b, second: c, outcome: 1)] }
        let model = BradleyTerryModel.analyze(ids: [a, b, c], evidence: observations)
        let ranks = model.rankEstimates()
        #expect(ranks == model.rankEstimates())
        #expect(ranks[a]!.upper95 == 1)
        #expect(ranks[c]!.lower95 == 3)
        #expect(ranks[a]!.standardDeviation < wide[a]!.standardDeviation)
        for rank in ranks.values { #expect((1...3).contains(rank.lower95) && (1...3).contains(rank.upper95)) }
    }

    @Test func timestampsHaveNoWeightAndMalformedEvidenceIsDiagnosed() {
        let old = PreferenceEvidence(first: a, second: b, outcome: 1, timestamp: Date(timeIntervalSince1970: 0))
        let fresh = PreferenceEvidence(first: a, second: b, outcome: 1, timestamp: .now)
        #expect(BradleyTerryModel.fit(ids: [a, b], evidence: [old]) == BradleyTerryModel.fit(ids: [a, b], evidence: [fresh]))
        let model = BradleyTerryModel.analyze(ids: [a, b], evidence: [old,
            PreferenceEvidence(first: a, second: a, outcome: 1),
            PreferenceEvidence(first: a, second: UUID(), outcome: 1),
            PreferenceEvidence(first: a, second: b, outcome: .nan),
            PreferenceEvidence(first: a, second: b, outcome: 2)])
        #expect(model.diagnostics.ignoredEvidenceCount == 4)
        #expect(model.estimates == BradleyTerryModel.fit(ids: [a, b], evidence: [old]))
    }

    @Test func anchoredScoreScalingAndRounding() {
        #expect(PreferenceEstimate.score(for: 0) == 5.5)
        let threshold = 2 * log(179.0)
        #expect(abs(PreferenceEstimate.score(for: threshold) - 9.95) < 1e-12)
        #expect(PreferenceEstimate.score(for: threshold + 0.01).formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US_POSIX"))) == "10.0")
        #expect(PreferenceEstimate.score(for: 2.795364881337627).formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US_POSIX"))) == "8.2")
        for strength in [-10000.0, -100, -10, 0, 10, 100, 10000] {
            let score = PreferenceEstimate.score(for: strength)
            #expect(score.isFinite && (1...10).contains(score))
        }
    }

    @Test func sessionDiagnosticsTrackStoppingTimestampSkipAndUndo() throws {
        var session = RankingEngine(itemID: c, orderedIDs: [a, b], reaction: .fine)
        let original = session.diagnostics()
        session.answer(.skip)
        #expect(session.diagnostics().comparisonCount == 0)
        #expect(session.diagnostics().skipCount == 1)
        #expect(session.diagnostics().positionStandardDeviation == original.positionStandardDeviation)
        session.undo()
        let timestamp = Date(timeIntervalSince1970: 12345)
        session.answer(.tooTough, at: timestamp)
        #expect(session.evidence[0].timestamp == timestamp)
        #expect(session.evidence == session.evidence)
        let diagnostics = session.diagnostics()
        #expect(diagnostics.totalAnswerActions == 2 && diagnostics.undoCount == 1)
        #expect(diagnostics.stopReason == .adjacentTieConfidence)
        #expect(diagnostics.positionLower95 <= diagnostics.positionUpper95)
        #expect(diagnostics.positionStandardDeviation.isFinite)
        #expect(try JSONDecoder().decode(SessionDiagnostics.self, from: JSONEncoder().encode(diagnostics)).stopReason == diagnostics.stopReason)
        var exhausted = RankingEngine(itemID: c, orderedIDs: [a], reaction: .liked)
        exhausted.answer(.skip)
        #expect(exhausted.stopReason == .opponentsExhausted)
        #expect(!exhausted.placementResolved)
        var resolved = RankingEngine(itemID: c, orderedIDs: [a], reaction: .liked)
        resolved.answer(.newItem)
        #expect(resolved.stopReason == .singleSlotConfidence)
        #expect(RankingEngine(itemID: c, orderedIDs: [], reaction: .fine).stopReason == .firstItem)
    }

    @MainActor @Test func persistenceAppendsRepeatedEvidenceAndKeepsMetrics() throws {
        let schema = Schema([RankingList.self, RankedItem.self, Comparison.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let list = RankingList(name: "Refinement")
        context.insert(list)
        try RankingStore.save(name: "A", session: RankingEngine(itemID: a, orderedIDs: [], reaction: .liked), to: list, context: context)
        var session = RankingEngine(itemID: b, orderedIDs: [a], reaction: .fine)
        session.answer(.newItem, at: Date(timeIntervalSince1970: 100))
        try RankingStore.save(name: "B", session: session, to: list, context: context)
        let diagnostics = try #require(list.items.first { $0.id == b }?.sessionDiagnostics)
        #expect(diagnostics.comparisonCount == 1)
        #expect(diagnostics.scoreInterval95 != nil && diagnostics.modelRank != nil)
        for i in 0..<10 {
            try RankingStore.record(PreferenceEvidence(first: a, second: b, outcome: i % 2 == 0 ? 1 : 0.5,
                                                       timestamp: Date(timeIntervalSince1970: Double(200 + i))), in: list, context: context)
        }
        #expect(list.comparisons.count == 11)
        #expect(Set(list.comparisons.map(\.id)).count == 11)
        #expect(Set(list.comparisons.map(\.timestamp)).count == 11)
        #expect(list.orderedItems.first?.id == a)
        #expect(list.comparisons.map(\.evidence).contains(session.evidence[0]))
        #expect(throws: RankingStore.EvidenceError.self) {
            try RankingStore.removeSession(session, from: list, context: context)
        }
        #expect(list.comparisons.count == 11 && list.items.count == 2)
        #expect(throws: RankingStore.EvidenceError.self) {
            try RankingStore.record(PreferenceEvidence(first: a, second: UUID(), outcome: 1), in: list, context: context)
        }
    }
    @MainActor @Test func nearlyEqualOrderingIsDeterministic() {
        let list = RankingList(name: "Close")
        let items = [RankedItem(id: a, name: "A"), RankedItem(id: b, name: "B"), RankedItem(id: c, name: "C")]
        for (index, item) in items.enumerated() {
            item.strength = Double(index) * 0.8e-7
            item.createdAt = Date(timeIntervalSince1970: Double(index))
        }
        list.items = items
        let expected = list.orderedItems.map(\.id)
        list.items = [items[2], items[0], items[1]]
        #expect(list.orderedItems.map(\.id) == expected)
        list.items = items.reversed()
        #expect(list.orderedItems.map(\.id) == expected)
    }

}
