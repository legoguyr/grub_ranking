import Foundation

nonisolated enum RankingsDisplayMode: String, CaseIterable, Identifiable {
    case topVersion = "Top Version", allVersions = "All Versions"
    var id: String { rawValue }
    static let preferenceKey = "StayGrubby.rankingsDisplayMode.v1"
}
@MainActor enum RankingsDisplayPreferences {
    static var defaults: UserDefaults {
        #if DEBUG
        if let id = DebugReviewConfiguration.current.storeID,
           let isolated = UserDefaults(suiteName: "StayGrubby.review.display.\(id.uuidString)") { return isolated }
        #endif
        return .standard
    }
}
@MainActor enum RankingsPresentation {
    /// Filter/search first, then retain the highest globally ranked matching
    /// version of each Dish. Original global rank numbers are never renumbered.
    static func entries(_ eligible: [CookingDiscovery.Entry], matching: [CookingDiscovery.Entry],
                        mode: RankingsDisplayMode) -> [CookingDiscovery.Entry] {
        let matches = Set(matching.map(\.id))
        var seen = Set<UUID>()
        return eligible.filter { entry in
            guard matches.contains(entry.id), let dish = entry.attempt.dish else { return false }
            return mode == .allVersions || seen.insert(dish.id).inserted
        }
    }
}
