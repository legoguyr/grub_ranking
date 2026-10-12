import Foundation
import SwiftData

@Model
final class Comparison {
    var id: UUID
    var firstItemID: UUID
    var secondItemID: UUID
    var preferredItemID: UUID?
    var isTie: Bool
    var timestamp: Date
    var list: RankingList?
    init(evidence: PreferenceEvidence, id: UUID = UUID()) {
        self.id = id; firstItemID = evidence.first; secondItemID = evidence.second
        isTie = evidence.outcome == 0.5
        preferredItemID = evidence.outcome == 0.5 ? nil : (evidence.outcome == 1 ? evidence.first : evidence.second)
        timestamp = evidence.timestamp
    }
    var evidence: PreferenceEvidence {
        PreferenceEvidence(first: firstItemID, second: secondItemID,
                           outcome: isTie ? 0.5 : (preferredItemID == firstItemID ? 1 : 0), timestamp: timestamp)
    }
}
