import Foundation
import SwiftData

@Model
final class RankingList {
    var id: UUID
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \RankedItem.list) var items: [RankedItem] = []
    @Relationship(deleteRule: .cascade, inverse: \Comparison.list) var comparisons: [Comparison] = []
    init(name: String) { id = UUID(); self.name = name; createdAt = .now }

    var orderedItems: [RankedItem] {
        items.sorted {
            // Quantized keys give a strict weak ordering. An abs(a-b) epsilon
            // comparator can form a cycle for three nearly equal strengths.
            let first = ($0.strength * 1e7).rounded(), second = ($1.strength * 1e7).rounded()
            if first != second { return first > second }
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
    @discardableResult
    func recompute() -> RankingAnalysis {
        let analysis = BradleyTerryModel.analyze(ids: items.map(\.id), evidence: comparisons.map(\.evidence))
        let estimates = analysis.estimates
        for item in items {
            if let estimate = estimates[item.id] {
                item.strength = estimate.strength
                item.uncertainty = estimate.uncertainty
            }
        }
        return analysis
    }
}
