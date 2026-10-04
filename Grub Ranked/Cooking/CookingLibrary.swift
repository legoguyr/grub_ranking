import Foundation
import SwiftData

/// Application routing only. RankingList and the engine do not know about cooking.
@Model
final class CookingLibrary {
    @Attribute(.unique) var key: String
    var globalRankingID: UUID
    var bridgeVersion: Int
    init(globalRankingID: UUID) { key = "local"; self.globalRankingID = globalRankingID; bridgeVersion = 1 }
}
