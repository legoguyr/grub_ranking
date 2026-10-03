import Foundation
import Accelerate

nonisolated struct ScoreInterval: Codable, Equatable {
    let lower: Double
    let upper: Double
}

nonisolated struct PairwiseEstimate {
    let strengthDifference: Double
    let standardDeviation: Double
    /// Posterior probability that the first latent strength exceeds the second.
    let probabilityFirstStronger: Double
    /// Approximate posterior predictive choice probability, distinct from order confidence.
    let predictedWinProbability: Double
    let informationGainBits: Double
    var orderConfidence: Double { max(probabilityFirstStronger, 1 - probabilityFirstStronger) }
}

nonisolated struct RankEstimate: Codable, Equatable {
    let expectedRank: Double
    let standardDeviation: Double
    let lower95: Int
    let upper95: Int
}

nonisolated struct ComparisonPair: Hashable {
    let first: UUID
    let second: UUID
    init(_ first: UUID, _ second: UUID) {
        if first.uuidString < second.uuidString { self.first = first; self.second = second }
        else { self.first = second; self.second = first }
    }
}

nonisolated struct RefinementSuggestion {
    let pair: ComparisonPair
    let relationship: PairwiseEstimate
}

nonisolated struct FitDiagnostics {
    let iterations: Int
    let converged: Bool
    let maximumGradient: Double
    let ignoredEvidenceCount: Int
}

/// A joint Laplace posterior. Off-diagonal covariance matters for transitive relationships:
/// Var(a-b) = Var(a) + Var(b) - 2 Cov(a,b), not a sum of independent item errors.
nonisolated struct RankingAnalysis {
    let ids: [UUID]
    let estimates: [UUID: PreferenceEstimate]
    let diagnostics: FitDiagnostics
    private let indices: [UUID: Int]
    private let covariance: [Double]
    private let precisionCholesky: [Double]

    init(ids: [UUID], strengths: [Double], precision: [Double], diagnostics: FitDiagnostics) {
        self.ids = ids
        self.diagnostics = diagnostics
        indices = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        let decomposition = PosteriorMatrix(precision: precision, size: ids.count)
        covariance = decomposition.covariance
        precisionCholesky = decomposition.cholesky
        estimates = Dictionary(uniqueKeysWithValues: ids.indices.map { i in
            (ids[i], PreferenceEstimate(strength: strengths[i], uncertainty: sqrt(max(0, decomposition.covariance[i + i * ids.count]))))
        })
    }

    func relationship(_ first: UUID, _ second: UUID) -> PairwiseEstimate? {
        guard first != second, let a = indices[first], let b = indices[second] else { return nil }
        let n = ids.count
        let difference = estimates[first]!.strength - estimates[second]!.strength
        let variance = max(1e-12, covariance[a + a * n] + covariance[b + b * n] - 2 * covariance[a + b * n])
        let sd = sqrt(variance)
        let orderProbability = 0.5 * erfc(-difference / (sd * sqrt(2)))
        let p = BradleyTerryModel.logistic(difference)
        // Local expected Gaussian entropy reduction after one Bernoulli observation.
        // Unlike choice entropy alone, this declines for a precisely known tie.
        let gain = 0.5 * log2(1 + p * (1 - p) * variance)
        return PairwiseEstimate(strengthDifference: difference, standardDeviation: sd,
                                probabilityFirstStronger: orderProbability,
                                predictedWinProbability: BradleyTerryModel.logistic(difference / sqrt(1 + .pi * variance / 8)),
                                informationGainBits: gain)
    }

    /// Existing pairs may be revisited: repeated answers remain independent observations.
    /// `excluding` is session-local (e.g. Skip); it does not remove saved evidence.
    func nextRefinement(excluding: Set<ComparisonPair> = [], confidenceLimit: Double = 0.975,
                        minimumInformationBits: Double = 0.01) -> RefinementSuggestion? {
        guard diagnostics.converged else { return nil }
        var best: RefinementSuggestion?
        for a in ids.indices {
            for b in (a + 1)..<ids.count {
                let pair = ComparisonPair(ids[a], ids[b])
                guard !excluding.contains(pair), let relationship = relationship(pair.first, pair.second),
                      relationship.orderConfidence < confidenceLimit,
                      relationship.informationGainBits >= minimumInformationBits else { continue }
                if best == nil || relationship.informationGainBits > best!.relationship.informationGainBits {
                    best = RefinementSuggestion(pair: pair, relationship: relationship)
                }
            }
        }
        return best
    }

    /// Deterministic correlated posterior draws. Quantiles include rank dependence,
    /// unlike summing independent pairwise variances. Kept off the insertion hot path.
    func rankEstimates(sampleCount: Int = 512, seed: UInt64 = 0x47525542) -> [UUID: RankEstimate] {
        guard !ids.isEmpty else { return [:] }
        let n = ids.count
        let count = max(32, sampleCount)
        var random = PosteriorRandom(seed: seed)
        var draws = (0..<(n * count)).map { _ in random.normal() }
        // H = L Lᵀ; L⁻ᵀ z has covariance H⁻¹. BLAS solves all draws in one batch.
        cblas_dtrsm(CblasColMajor, CblasLeft, CblasLower, CblasTrans, CblasNonUnit,
                    Int32(n), Int32(count), 1, precisionCholesky, Int32(n), &draws, Int32(n))
        let means = ids.map { estimates[$0]!.strength }
        var histograms = Array(repeating: Array(repeating: 0, count: n + 1), count: n)
        for sample in 0..<count {
            let offset = sample * n
            let ordering = (0..<n).sorted {
                let a = means[$0] + draws[offset + $0], b = means[$1] + draws[offset + $1]
                return a == b ? $0 < $1 : a > b
            }
            for (position, index) in ordering.enumerated() { histograms[index][position + 1] += 1 }
        }
        return Dictionary(uniqueKeysWithValues: ids.indices.map { i in
            var expected = 1.0
            for j in ids.indices where i != j { expected += relationship(ids[j], ids[i])!.probabilityFirstStronger }
            var cumulative = 0
            var lower = 1
            var upper = n
            var foundLower = false
            var variance = 0.0
            for rank in 1...n {
                let frequency = histograms[i][rank]
                variance += Double(frequency) * pow(Double(rank) - expected, 2) / Double(count)
                cumulative += frequency
                if !foundLower && Double(cumulative) >= 0.025 * Double(count) { lower = rank; foundLower = true }
                if Double(cumulative) >= 0.975 * Double(count) { upper = rank; break }
            }
            // Include the upper tail when calculating variance.
            if upper < n {
                for rank in (upper + 1)...n {
                    variance += Double(histograms[i][rank]) * pow(Double(rank) - expected, 2) / Double(count)
                }
            }
            return (ids[i], RankEstimate(expectedRank: expected, standardDeviation: sqrt(variance), lower95: lower, upper95: upper))
        })
    }
}

/// Dense native linear algebra is small (~2 MB/matrix at 500 items). The 0.25I
/// regularizer makes the Hessian positive definite even for disconnected graphs.
nonisolated private struct PosteriorMatrix {
    let cholesky: [Double]
    let covariance: [Double]
    init(precision: [Double], size: Int) {
        guard size > 0 else { cholesky = []; covariance = []; return }
        var n = Int32(size), leading = Int32(size), info: Int32 = 0
        var lower: Int8 = 76 // LAPACK 'L', column-major lower triangle.
        var factor = precision
        dpotrf_(&lower, &n, &factor, &leading, &info)
        // With validated finite evidence and positive prior precision this is an invariant.
        precondition(info == 0, "Regularized preference precision must be positive definite")
        cholesky = factor
        dpotri_(&lower, &n, &factor, &leading, &info)
        precondition(info == 0, "Preference precision inversion failed")
        for column in 0..<size {
            for row in 0..<column { factor[row + column * size] = factor[column + row * size] }
        }
        covariance = factor
    }
}

nonisolated private struct PosteriorRandom {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func uniform() -> Double {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        value ^= value >> 31
        return (Double(value >> 11) + 0.5) / 9007199254740992.0
    }
    mutating func normal() -> Double { sqrt(-2 * log(uniform())) * cos(2 * .pi * uniform()) }
}
