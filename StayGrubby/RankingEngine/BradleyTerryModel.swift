import Foundation

nonisolated struct PreferenceEvidence: Equatable {
    let first: UUID
    let second: UUID
    /// 1 = first wins, 0 = second wins, 0.5 = approximately equal.
    let outcome: Double
    var timestamp: Date = .now
}

nonisolated struct PreferenceEstimate: Equatable {
    var strength: Double
    var uncertainty: Double
    // Fixed logistic scale, never rescaled by list size or ordinal rank.
    // Zero strength is 5.5; a singleton stays neutral regardless of reaction.
    var score: Double { Self.score(for: strength) }
    static func score(for strength: Double) -> Double { 1 + 9 * BradleyTerryModel.logistic(strength / 2) }
    var scoreInterval95: ScoreInterval {
        ScoreInterval(lower: Self.score(for: strength - 1.96 * uncertainty),
                      upper: Self.score(for: strength + 1.96 * uncertainty))
    }
}

nonisolated enum BradleyTerryModel {
    /// MAP Bradley–Terry with N(0, 4) regularization. Fractional tie outcomes
    /// pull strengths together. Cycles remain finite because the objective is convex.
    /// Coordinate Newton updates avoid a dense O(n³) solve.
    static func fit(ids: [UUID], evidence: [PreferenceEvidence]) -> [UUID: PreferenceEstimate] {
        analyze(ids: ids, evidence: evidence).estimates
    }

    static func logistic(_ value: Double) -> Double {
        if value >= 0 { return 1 / (1 + exp(-value)) }
        let exponential = exp(value)
        return exponential / (1 + exponential)
    }

    static func analyze(ids: [UUID], evidence: [PreferenceEvidence]) -> RankingAnalysis {
        let ids = Array(Set(ids)).sorted { $0.uuidString < $1.uuidString }
        let indices = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        var edges = Array(repeating: [(Int, Double)](), count: ids.count)
        var ignored = 0
        for e in evidence {
            guard let a = indices[e.first], let b = indices[e.second], a != b,
                  e.outcome.isFinite, [0.0, 0.5, 1.0].contains(e.outcome) else { ignored += 1; continue }
            edges[a].append((b, e.outcome))
            edges[b].append((a, 1 - e.outcome))
        }
        var values = Array(repeating: 0.0, count: ids.count)
        var iterations = 0
        for iteration in 0..<250 {
            iterations = iteration + 1
            var largestChange = 0.0
            for i in ids.indices {
                var gradient = -0.25 * values[i]
                var precision = 0.25
                for (j, result) in edges[i] {
                    let p = 1 / (1 + exp(-(values[i] - values[j])))
                    gradient += result - p
                    precision += p * (1 - p)
                }
                let step = max(-1, min(1, gradient / precision))
                values[i] += step
                largestChange = max(largestChange, abs(step))
            }
            if largestChange < 1e-8 { break }
        }
        var precision = Array(repeating: 0.0, count: ids.count * ids.count)
        var maximumGradient = 0.0
        for i in ids.indices {
            var gradient = -0.25 * values[i]
            precision[i + i * ids.count] = 0.25
            for (j, result) in edges[i] {
                let p = logistic(values[i] - values[j])
                let weight = p * (1 - p)
                gradient += result - p
                precision[i + i * ids.count] += weight
                precision[i + j * ids.count] -= weight
            }
            maximumGradient = max(maximumGradient, abs(gradient))
        }
        return RankingAnalysis(ids: ids, strengths: values, precision: precision,
                               diagnostics: FitDiagnostics(iterations: iterations, converged: maximumGradient < 1e-6,
                                                           maximumGradient: maximumGradient, ignoredEvidenceCount: ignored))
    }
}
