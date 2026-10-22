import Foundation

/// Presentation only. Never supplies a prior, comparison outcome, or sorting key to BT.
nonisolated enum ScoreCalibration {
    static let version = 1
    enum MetadataError: Error { case invalidDiagnostics }

    static func reaction(in data: Data?) -> InitialReaction? {
        guard let data, let record = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        return (record["latestSemanticReaction"] as? String).flatMap(InitialReaction.init(rawValue:))
            ?? (record["initialReaction"] as? String).flatMap(InitialReaction.init(rawValue:))
    }
    static func score(strength: Double, metadata: Data?) -> Double {
        score(strength: strength, reaction: reaction(in: metadata))
    }
    static func score(strength: Double, reaction: InitialReaction?) -> Double {
        let s = strength.isFinite ? strength : 0
        switch reaction {
        case .liked: return 7 + 3 * sigmoid(s / 1.6 - 0.4)
        case .fine: return 4.8 + 3 * sigmoid(s / 1.6)
        case .disliked: return 1 + 4.8 * sigmoid(s / 1.6)
        case nil: return 1 + 9 * sigmoid(s / 2) // Unknown legacy assessment: preserve the old mapping.
        }
    }
    private static func sigmoid(_ value: Double) -> Double {
        if value >= 0 { return 1 / (1 + exp(-value)) }
        let e = exp(value); return e / (1 + e)
    }

    /// Preserve original diagnostics and unknown future fields. Called only inside a completed
    /// re-rank transaction; cancellation, comparisons and passive restore never write this key.
    static func recording(_ reaction: InitialReaction, in data: Data?) throws -> Data {
        var fields: [String: Any] = [:]
        if let data {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw MetadataError.invalidDiagnostics }
            fields = object
        }
        fields["latestSemanticReaction"] = reaction.rawValue
        fields["scoreCalibrationVersion"] = version
        return try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
    }
}
