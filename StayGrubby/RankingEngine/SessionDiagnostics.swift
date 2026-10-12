import Foundation

nonisolated enum SessionStopReason: String, Codable {
    case firstItem
    case singleSlotConfidence
    case adjacentTieConfidence
    case lowInformation
    case opponentsExhausted
}

/// Persisted at completion for internal evaluation; no primary UI or analytics service.
/// Position fields are zero-based insertion slots, conditional on the old ordering.
/// modelRank is one-based and uses the joint strength posterior after recomputation.
nonisolated struct SessionDiagnostics: Codable {
    let version: Int
    let startedAt: Date
    let initialReaction: String
    let existingItemCount: Int
    let comparisonCount: Int
    let skipCount: Int
    let totalAnswerActions: Int
    let undoCount: Int
    let stopReason: SessionStopReason?
    let maximumSlotProbability: Double
    let positionMean: Double
    let positionStandardDeviation: Double
    let positionLower95: Int
    let positionUpper95: Int
    let positionEntropyBits: Double
    let strengthStandardDeviation: Double?
    let scoreInterval95: ScoreInterval?
    let modelRank: RankEstimate?
    let modelConverged: Bool?
    let modelMaximumGradient: Double?
}
