import Foundation

/// Application workflow over generic IDs/evidence. No cooking metadata enters inference.
struct ReRankingSession {
    struct Answer { let opponent: UUID; let choice: ComparisonAnswer; let timestamp: Date }
    let itemID: UUID
    let ids: [UUID]
    let history: [PreferenceEvidence]
    private(set) var answers: [Answer] = []
    var evidence: [PreferenceEvidence] {
        answers.compactMap { answer in
            let outcome: Double
            switch answer.choice {
            case .newItem: outcome = 1
            case .existingItem: outcome = 0
            case .tooTough: outcome = 0.5
            case .skip: return nil
            }
            return PreferenceEvidence(first: itemID, second: answer.opponent, outcome: outcome, timestamp: answer.timestamp)
        }
    }
    var nextOpponent: UUID? {
        let analysis = BradleyTerryModel.analyze(ids: ids, evidence: history + evidence)
        // Explicitly asking to re-rank is a reason to revisit even a previously
        // confident relationship. After new evidence, use the normal refinement policy.
        let suggestion = analysis.nextRefinement(involving: itemID,
            excluding: Set(answers.map { ComparisonPair(itemID, $0.opponent) }),
            confidenceLimit: evidence.isEmpty ? 1.01 : 0.975,
            minimumInformationBits: evidence.isEmpty ? 0 : 0.01)
        guard let pair = suggestion?.pair else { return nil }
        return pair.first == itemID ? pair.second : pair.first
    }
    mutating func answer(_ choice: ComparisonAnswer, at timestamp: Date = .now) {
        guard let opponent = nextOpponent else { return }
        answers.append(Answer(opponent: opponent, choice: choice, timestamp: timestamp))
    }
    mutating func undo() { if !answers.isEmpty { answers.removeLast() } }
}
