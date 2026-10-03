import Foundation
import Testing
@testable import Grub_Ranked

private enum SimulationScenario: String, CaseIterable {
    case consistent, noisy, cyclic, frequentTies, closeClusters, separatedTiers, wrongReaction
}

private struct SimulationRandom {
    var state: UInt64
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / 9007199254740992.0
    }
}

struct RankingSimulationTests {
    private func id(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!
    }

    private func outcome(first: Double, second: Double, size: Int, scenario: SimulationScenario,
                         random: inout SimulationRandom) -> Double {
        let preference = first < second ? 1.0 : 0.0
        switch scenario {
        case .consistent, .wrongReaction: return preference
        case .noisy: return random.next() < 0.15 ? 1 - preference : preference
        case .cyclic:
            let a = Int(max(0, first)) % 3, b = Int(max(0, second)) % 3
            return a == b ? preference : ((a + 1) % 3 == b ? 1 : 0)
        case .frequentTies: return random.next() < 0.55 ? 0.5 : preference
        case .closeClusters:
            let width = max(2, size / 5)
            if Int(max(0, first)) / width == Int(max(0, second)) / width {
                return random.next() < 0.8 ? 0.5 : (random.next() < 0.5 ? 0 : 1)
            }
            return preference
        case .separatedTiers:
            return Int(max(0, first)) / max(1, size / 5) == Int(max(0, second)) / max(1, size / 5) ? 0.5 : preference
        }
    }

    @Test(arguments: [25, 50, 100, 250, 500])
    func stressMatrix(size: Int) throws {
        let ids = (0..<size).map(id)
        let trueIndices = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        for scenario in SimulationScenario.allCases {
            var counts: [Int] = []
            var confidences: [Double] = []
            var deviations: [Double] = []
            var stopReasons: [String: Int] = [:]
            for seed in 1...4 {
                var random = SimulationRandom(state: UInt64(seed * 7919 + size))
                var evidence: [PreferenceEvidence] = []
                // Local neighbors plus long-range anchors create established but imperfect
                // rankings. The same pair can legitimately appear more than once.
                for a in 0..<size {
                    for offset in [1, 2, 7, max(1, size / 3), max(1, size / 2)] {
                        let b = (a + offset) % size
                        let value = outcome(first: Double(a), second: Double(b), size: size, scenario: scenario, random: &random)
                        evidence.append(PreferenceEvidence(first: ids[a], second: ids[b], outcome: value))
                    }
                }
                let baseline = BradleyTerryModel.analyze(ids: ids, evidence: evidence)
                #expect(baseline.diagnostics.converged)
                let ordered = ids.sorted {
                    let lhs = baseline.estimates[$0]!.strength, rhs = baseline.estimates[$1]!.strength
                    return lhs == rhs ? $0.uuidString < $1.uuidString : lhs > rhs
                }
                if scenario == .consistent || scenario == .separatedTiers {
                    #expect(baseline.estimates[ids[0]]!.strength > baseline.estimates[ids[size - 1]]!.strength)
                    #expect(baseline.relationship(ids[0], ids[size - 1])!.probabilityFirstStronger > 0.95)
                }
                for position in [0, size / 2, size] {
                    let newID = id(size + position + seed * 10000)
                    var reaction: InitialReaction = position == 0 ? .liked : (position == size ? .disliked : .fine)
                    if scenario == .wrongReaction { reaction = position == 0 ? .disliked : .liked }
                    var session = RankingEngine(itemID: newID, orderedIDs: ordered, reaction: reaction)
                    while let opponent = session.nextOpponent {
                        let value = outcome(first: Double(position) - 0.5, second: Double(trueIndices[opponent]!), size: size,
                                            scenario: scenario, random: &random)
                        session.answer(value == 0.5 ? .tooTough : (value == 1 ? .newItem : .existingItem))
                        #expect(session.answers.count <= size)
                        if session.answers.count > size { break }
                    }
                    let model = BradleyTerryModel.analyze(ids: ids + [newID], evidence: evidence + session.evidence)
                    #expect(model.diagnostics.converged)
                    for estimate in model.estimates.values {
                        #expect(estimate.strength.isFinite && estimate.uncertainty.isFinite && estimate.uncertainty > 0)
                        #expect(estimate.score.isFinite && (1...10).contains(estimate.score))
                        #expect(estimate.scoreInterval95.lower <= estimate.score && estimate.score <= estimate.scoreInterval95.upper)
                    }
                    let metrics = session.diagnostics(analysis: model)
                    #expect(metrics.stopReason != nil)
                    // Generous logarithmic envelope; no assertion on an exact question count.
                    #expect(metrics.comparisonCount <= Int(6 * ceil(log2(Double(size + 1)))))
                    #expect(metrics.comparisonCount < size)
                    #expect(metrics.positionStandardDeviation.isFinite && metrics.positionStandardDeviation >= 0)
                    #expect(session.answers.count == Set(session.answers.map(\.opponent)).count)
                    counts.append(metrics.comparisonCount)
                    confidences.append(metrics.maximumSlotProbability)
                    deviations.append(metrics.positionStandardDeviation)
                    stopReasons[metrics.stopReason!.rawValue, default: 0] += 1
                }
                // Rank sampling and refinement on every size/scenario, not only small fixtures.
                let ranks = baseline.rankEstimates(sampleCount: 64)
                #expect(ranks.count == size)
                for rank in ranks.values {
                    #expect(rank.standardDeviation.isFinite)
                    #expect(rank.lower95 >= 1 && rank.upper95 <= size && rank.lower95 <= rank.upper95)
                }
                if let refinement = baseline.nextRefinement() {
                    #expect(refinement.relationship.informationGainBits >= 0.01)
                    #expect(refinement.relationship.orderConfidence < 0.975)
                }
            }
            let mean = Double(counts.reduce(0, +)) / Double(counts.count)
            #expect(mean < Double(size) * 0.5)
            print("SIMULATION|\(size)|\(scenario.rawValue)|\(counts.count)|\(mean)|\(counts.max()!)|\(confidences.reduce(0,+)/Double(confidences.count))|\(deviations.reduce(0,+)/Double(deviations.count))|\(stopReasons.sorted { $0.key < $1.key })")
        }
    }

    @Test func sequentialHistoriesAndGrowth() {
        var means: [Int: Double] = [:]
        for size in [25, 50, 100, 250, 500] {
            var ids: [UUID] = []
            var evidence: [PreferenceEvidence] = []
            var model = BradleyTerryModel.analyze(ids: [], evidence: [])
            var counts: [Int] = []
            // Multiplicative permutation supplies an interleaved insertion order.
            let order = (0..<size).sorted { ($0 * 137) % (size + 1) < ($1 * 137) % (size + 1) }
            for truth in order {
                let newID = id(truth)
                let ordered = ids.sorted {
                    let lhs = model.estimates[$0]!.strength, rhs = model.estimates[$1]!.strength
                    return lhs == rhs ? $0.uuidString < $1.uuidString : lhs > rhs
                }
                var session = RankingEngine(itemID: newID, orderedIDs: ordered, reaction: .fine)
                while let opponent = session.nextOpponent {
                    session.answer(newID.uuidString < opponent.uuidString ? .newItem : .existingItem)
                }
                counts.append(session.evidence.count)
                evidence += session.evidence
                ids.append(newID)
                model = BradleyTerryModel.analyze(ids: ids, evidence: evidence)
                #expect(model.diagnostics.converged)
            }
            let mean = Double(counts.reduce(0, +)) / Double(size)
            means[size] = mean
            #expect(counts.max()! < Int(6 * ceil(log2(Double(size + 1)))))
            #expect(mean < Double(size) * 0.5)
            #expect(model.estimates[id(0)]!.score > model.estimates[id(size - 1)]!.score)
            // Freeze nothing: rebuilding just from history reproduces every estimate.
            #expect(model.estimates == BradleyTerryModel.fit(ids: ids.reversed(), evidence: evidence))
            print("HISTORY|\(size)|\(mean)|\(counts.max()!)|\(evidence.count)")
        }
        // 20x list growth must be far less than 20x question growth.
        #expect(means[500]! / means[25]! < 4)
    }
}
