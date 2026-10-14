import Foundation
import SwiftData

/// Only the content permitted on an exported card. Rank and movement stay in the
/// results screen; source, notes, account details and tags never enter this model.
nonisolated struct ShareCardModel: Equatable, Sendable {
    let title: String
    let versionSubtitle: String?
    let scoreText: String?
    let achievement: ShareAchievement?
    /// A value copy of the existing local file reference, never a network URL.
    let photo: MediaTransfer?

    @MainActor
    static func make(for attempt: CookingAttempt, event: RankingCompletionSnapshot? = nil) -> Self {
        let customTitle = attempt.versionTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitle: String?
        if let customTitle, !customTitle.isEmpty {
            subtitle = customTitle
        } else if attempt.sequenceNumber > 1 || (attempt.dish?.attempts.count ?? 0) > 1 {
            subtitle = "Version \(attempt.sequenceNumber)"
        } else {
            subtitle = nil
        }
        let visibility = ScoreUnlockPolicy.state(for: attempt)
        let score = attempt.rankedItem?.score
        return Self(title: attempt.dish?.name ?? attempt.rankedItem?.name ?? "Dish",
                    versionSubtitle: subtitle,
                    scoreText: score.flatMap(visibility.scoreText),
                    achievement: ShareAchievement.eligible(for: attempt, event: event),
                    photo: attempt.primaryImage.map(MediaTransfer.init))
    }
}

nonisolated enum ShareAchievement: String, Equatable, Sendable {
    case newNumberOne, topFive, bestVersion

    var title: String {
        switch self {
        case .newNumberOne: "NEW #1 DISH"
        case .topFive: "TOP 5"
        case .bestVersion: "BEST VERSION YET"
        }
    }
    var symbol: String {
        switch self {
        case .newNumberOne, .bestVersion: "trophy.fill"
        case .topFive: "star.fill"
        }
    }

    /// Conservative presentation rules over the saved order and actual evidence.
    /// We never refit the model, write an achievement, or change comparison policy.
    @MainActor
    static func eligible(for attempt: CookingAttempt, event: RankingCompletionSnapshot? = nil) -> Self? {
        guard let item = attempt.rankedItem, item.id == attempt.rankedItemID,
              let list = item.list, list.items.contains(where: { $0.id == item.id }),
              item.strength.isFinite else { return nil }
        let ordered = list.orderedItems
        guard let index = ordered.firstIndex(where: { $0.id == item.id }) else { return nil }
        let ids = Set(ordered.map(\.id))
        let observations = list.comparisons.filter {
            !$0.isTie && $0.firstItemID != $0.secondItemID &&
            ids.contains($0.firstItemID) && ids.contains($0.secondItemID) &&
            ($0.preferredItemID == $0.firstItemID || $0.preferredItemID == $0.secondItemID)
        }
        guard observations.contains(where: { $0.firstItemID == item.id || $0.secondItemID == item.id }) else { return nil }

        // Strict strength keys match RankingList's numeric ordering and exclude
        // an ordinal result that exists only because of its date/UUID tie breaks.
        func isStrictlyAbove(_ other: RankedItem) -> Bool {
            other.strength.isFinite && (item.strength * 1e7).rounded() > (other.strength * 1e7).rounded()
        }
        var connected: Set<UUID> = [item.id]
        var grew = true
        while grew {
            let before = connected.count
            for observation in observations {
                if connected.contains(observation.firstItemID) { connected.insert(observation.secondItemID) }
                if connected.contains(observation.secondItemID) { connected.insert(observation.firstItemID) }
            }
            grew = connected.count > before
        }

        // NEW is transient: a prior snapshot plus new saved evidence must prove
        // this event displaced an existing leader. Later re-sharing has no event.
        if let event, event.rankingID == list.id, index == 0, ordered.count > 1,
           let oldLeader = event.leadingItemID, oldLeader != item.id, ids.contains(oldLeader), connected.contains(oldLeader),
           event.position(of: item.id) != 1,
           ordered.dropFirst().allSatisfy(isStrictlyAbove),
           observations.contains(where: {
               !event.comparisonIDs.contains($0.id) && ($0.firstItemID == item.id || $0.secondItemID == item.id)
           }) {
            return .newNumberOne
        }

        // Only the latest retained version can say "yet". Missing/unranked,
        // disconnected, tied, or later siblings prevent a historical overclaim.
        if let dish = attempt.dish, dish.attempts.contains(where: { $0.id == attempt.id }) {
            let siblings = dish.attempts.filter { $0.id != attempt.id }
            let sequences = Set(dish.attempts.map(\.sequenceNumber))
            let completeHistory = sequences.count == dish.attempts.count &&
                sequences.count == attempt.sequenceNumber &&
                sequences.allSatisfy { $0 > 0 && $0 <= attempt.sequenceNumber }
            if completeHistory && !siblings.isEmpty && siblings.allSatisfy({ sibling in
                guard sibling.sequenceNumber < attempt.sequenceNumber,
                      let other = sibling.rankedItem, other.list?.id == list.id,
                      other.id == sibling.rankedItemID, ids.contains(other.id),
                      connected.contains(other.id) else { return false }
                return isStrictlyAbove(other)
            }) {
                return .bestVersion
            }
        }

        // Avoid a badge on a nearly empty or disconnected library. At least five
        // cooks must have a real comparison path to this one. The sixth-place
        // boundary, when present, must not be decided by an equal-strength tie.
        if ordered.count >= 5, connected.count >= 5, index < 5,
           ordered.count == 5 || isStrictlyAbove(ordered[5]) {
            return .topFive
        }
        return nil
    }
}

/// Ephemeral before-save facts. No schema/history write is needed for a truthful
/// ranking event. This is deliberately separate from the exported card model.
nonisolated struct RankingCompletionSnapshot: Equatable, Sendable {
    let rankingID: UUID
    let orderedItemIDs: [UUID]
    let comparisonIDs: Set<UUID>
    var eligibleRankedEntryCount: Int? = nil
    var leadingItemID: UUID? { orderedItemIDs.first }
    func position(of itemID: UUID) -> Int? { orderedItemIDs.firstIndex(of: itemID).map { $0 + 1 } }

    @MainActor
    static func capture(from list: RankingList) -> Self {
        Self(rankingID: list.id, orderedItemIDs: list.orderedItems.map(\.id), comparisonIDs: Set(list.comparisons.map(\.id)),
             eligibleRankedEntryCount: list.modelContext.map { ScoreUnlockPolicy.state(in: $0, list: list).rankedEntryCount })
    }
}
