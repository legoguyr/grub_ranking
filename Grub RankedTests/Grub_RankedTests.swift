import Foundation
import Testing
import SwiftData
@testable import Grub_Ranked

@MainActor
struct Grub_RankedTests {
    private func ids(_ count: Int) -> [UUID] {
        (0..<count).map { UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", $0 + 1))! }
    }
    private func chain(_ ids: [UUID], repeats: Int = 1) -> [PreferenceEvidence] {
        (0..<repeats).flatMap { _ in zip(ids, ids.dropFirst()).map { PreferenceEvidence(first: $0, second: $1, outcome: 1) } }
    }
    private func insert(_ ordered: [UUID], position: Int, reaction: InitialReaction) -> RankingEngine {
        var session = RankingEngine(itemID: UUID(), orderedIDs: ordered, reaction: reaction)
        while let opponent = session.nextOpponent {
            let index = ordered.firstIndex(of: opponent)!
            session.answer(position <= index ? .newItem : .existingItem)
            if session.answers.count > ordered.count { break }
        }
        return session
    }

    @Test func firstItem() {
        for reaction in InitialReaction.allCases {
            let session = RankingEngine(itemID: UUID(), orderedIDs: [], reaction: reaction)
            #expect(session.isComplete)
            #expect(session.evidence.isEmpty)
            #expect(BradleyTerryModel.fit(ids: [session.itemID], evidence: [])[session.itemID]?.score == 5.5)
        }
    }

    @Test func secondItem() {
        let existing = UUID()
        for reaction in InitialReaction.allCases {
            var session = RankingEngine(itemID: UUID(), orderedIDs: [existing], reaction: reaction)
            #expect(session.nextOpponent == existing)
            session.answer(.newItem)
            #expect(session.isComplete)
            #expect(session.answers.count == 1)
            let fit = BradleyTerryModel.fit(ids: [existing, session.itemID], evidence: session.evidence)
            #expect(fit[session.itemID]!.score > fit[existing]!.score)
        }
    }

    @Test func strongAndWeakItems() {
        let ordered = ids(128)
        let strong = insert(ordered, position: 0, reaction: .liked)
        let weak = insert(ordered, position: 128, reaction: .disliked)
        #expect(strong.answers.count < 12)
        #expect(weak.answers.count < 12)
        #expect(strong.placementProbabilities.first! > 0.9)
        #expect(weak.placementProbabilities.last! > 0.9)
        #expect(strong.answers.allSatisfy { ordered.firstIndex(of: $0.opponent)! < 64 })
        #expect(weak.answers.allSatisfy { ordered.firstIndex(of: $0.opponent)! > 64 })
    }

    @Test func nearbyAndLargeList() {
        let ordered = ids(1024)
        for position in [0, 1, 250, 511, 800, 1024] {
            let session = insert(ordered, position: position, reaction: .fine)
            #expect(session.answers.count < 25)
            #expect(session.placementProbabilities[position] > 0.9)
            let lastIndex = ordered.firstIndex(of: session.answers.last!.opponent)!
            #expect(abs(lastIndex - position) <= 1)
        }
    }

    @Test func transitiveOrderingAndSelection() {
        let ordered = ids(3)
        let fit = BradleyTerryModel.fit(ids: ordered, evidence: chain(ordered, repeats: 4))
        #expect(fit[ordered[0]]!.strength > fit[ordered[1]]!.strength)
        #expect(fit[ordered[1]]!.strength > fit[ordered[2]]!.strength)
        var session = RankingEngine(itemID: UUID(), orderedIDs: ordered, reaction: .fine)
        #expect(session.nextOpponent == ordered[1])
        session.answer(.newItem)
        #expect(session.nextOpponent == ordered[0])
        session.answer(.newItem)
        #expect(session.isComplete)
        #expect(!session.answers.contains { $0.opponent == ordered[2] })
    }

    @Test func contradictoryCycle() {
        let ordered = ids(3)
        let evidence = chain(ordered) + [PreferenceEvidence(first: ordered[2], second: ordered[0], outcome: 1)]
        let fit = BradleyTerryModel.fit(ids: ordered, evidence: evidence)
        #expect(fit.count == 3)
        for estimate in fit.values {
            #expect(estimate.strength.isFinite)
            #expect(abs(estimate.score - 5.5) < 0.00001)
            #expect(estimate.uncertainty > 0)
        }
    }

    @Test func tooToughReducesGap() {
        let ordered = ids(2)
        let wins = chain(ordered, repeats: 3)
        let before = BradleyTerryModel.fit(ids: ordered, evidence: wins)
        let ties = (0..<4).map { _ in PreferenceEvidence(first: ordered[0], second: ordered[1], outcome: 0.5) }
        let after = BradleyTerryModel.fit(ids: ordered, evidence: wins + ties)
        #expect(abs(after[ordered[0]]!.strength - after[ordered[1]]!.strength) < abs(before[ordered[0]]!.strength - before[ordered[1]]!.strength))
        var session = RankingEngine(itemID: UUID(), orderedIDs: ordered, reaction: .fine)
        session.answer(.tooTough)
        #expect(session.evidence.first?.outcome == 0.5)
    }

    @Test func skipAndUndoRestoreExactState() {
        let ordered = ids(20)
        var session = RankingEngine(itemID: UUID(), orderedIDs: ordered, reaction: .liked)
        let probabilities = session.placementProbabilities
        let opponent = session.nextOpponent
        session.answer(.skip)
        #expect(session.evidence.isEmpty)
        #expect(session.placementProbabilities == probabilities)
        #expect(session.nextOpponent != opponent)
        session.undo()
        #expect(session.nextOpponent == opponent)
        session.answer(.newItem)
        session.undo()
        #expect(session.evidence.isEmpty)
        #expect(session.placementProbabilities == probabilities)
        #expect(session.nextOpponent == opponent)
    }

    @Test func allSkippedRemainsUncertain() {
        var session = RankingEngine(itemID: UUID(), orderedIDs: ids(5), reaction: .fine)
        while session.nextOpponent != nil { session.answer(.skip) }
        #expect(session.isComplete)
        #expect(!session.placementResolved)
        #expect(session.evidence.isEmpty)
        session.undo()
        #expect(session.nextOpponent != nil)
    }

    @Test func scoreRangeStabilityAndRecomputation() {
        let ordered = ids(20)
        let evidence = chain(ordered, repeats: 8)
        let before = BradleyTerryModel.fit(ids: ordered, evidence: evidence)
        let extra = UUID()
        let unrelated = BradleyTerryModel.fit(ids: ordered + [extra], evidence: evidence)
        for id in ordered { #expect(abs(before[id]!.score - unrelated[id]!.score) < 0.00001) }
        let added = evidence + [PreferenceEvidence(first: extra, second: ordered[10], outcome: 0.5)]
        let after = BradleyTerryModel.fit(ids: ordered + [extra], evidence: added)
        for id in ordered {
            #expect(abs(before[id]!.score - after[id]!.score) < 0.5)
            #expect((1...10).contains(after[id]!.score))
        }
        let replay = BradleyTerryModel.fit(ids: (ordered + [extra]).reversed(), evidence: added)
        #expect(after == replay)
        let gaps = zip(ordered, ordered.dropFirst()).map { before[$0]!.score - before[$1]!.score }
        #expect(gaps.max()! - gaps.min()! > 0.01)
    }

    @Test func persistenceIsolationReopenAndUndo() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ranking-\(UUID()).store")
        defer {
            for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: url.path + suffix) }
        }
        let schema = Schema([RankingList.self, RankedItem.self, Comparison.self])
        let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        var firstID: UUID!
        var listID: UUID!
        var savedSession: RankingEngine!
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            context.autosaveEnabled = false
            let list = RankingList(name: "Any items")
            let other = RankingList(name: "Independent")
            context.insert(list); context.insert(other)
            let first = RankingEngine(itemID: UUID(), orderedIDs: [], reaction: .liked)
            try RankingStore.save(name: "First", session: first, to: list, context: context)
            firstID = first.itemID; listID = list.id
            var second = RankingEngine(itemID: UUID(), orderedIDs: [first.itemID], reaction: .fine)
            second.answer(.newItem)
            try RankingStore.save(name: "Second", session: second, to: list, context: context)
            savedSession = second
            #expect(other.items.isEmpty && other.comparisons.isEmpty)
        }
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let lists = try context.fetch(FetchDescriptor<RankingList>())
        let list = try #require(lists.first { $0.id == listID })
        #expect(list.items.count == 2)
        #expect(list.comparisons.count == 1)
        #expect(list.comparisons.first?.timestamp == savedSession.evidence.first?.timestamp)
        #expect(list.items.first { $0.id == savedSession.itemID }?.sessionDiagnostics?.comparisonCount == 1)
        #expect(list.items.first { $0.id == savedSession.itemID }?.sessionDiagnostics?.scoreInterval95 != nil)
        #expect(list.comparisons.first?.preferredItemID == savedSession.itemID)
        let scores = list.orderedItems.map(\.score)
        list.recompute()
        #expect(list.orderedItems.map(\.score) == scores)
        try RankingStore.removeSession(savedSession, from: list, context: context)
        #expect(list.items.count == 1)
        #expect(list.items.first?.id == firstID)
        #expect(list.items.first?.score == 5.5)
        #expect(try context.fetchCount(FetchDescriptor<Comparison>()) == 0)
    }
}
