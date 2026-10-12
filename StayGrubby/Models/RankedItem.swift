import Foundation
import SwiftData

@Model
final class RankedItem {
    var id: UUID
    var name: String
    var createdAt: Date
    var strength: Double = 0
    var uncertainty: Double = 2
    var sessionDiagnosticsData: Data?
    var sessionDiagnostics: SessionDiagnostics? {
        guard let sessionDiagnosticsData else { return nil }
        return try? JSONDecoder().decode(SessionDiagnostics.self, from: sessionDiagnosticsData)
    }
    var list: RankingList?
    var score: Double { PreferenceEstimate(strength: strength, uncertainty: uncertainty).score }
    init(id: UUID = UUID(), name: String) {
        self.id = id; self.name = name; createdAt = .now
    }
}
