import Foundation
import SwiftData
import SwiftUI

/// Visibility only: never fits, edits or journals the cooking graph.
nonisolated enum ScoreUnlockPolicy {
    static let requiredRankedEntryCount = 10

    @MainActor static func entries(in context: ModelContext, list: RankingList? = nil) -> [CookingDiscovery.Entry] {
        do { try SyncJournal.requireReady(context) } catch { return [] }
        guard let library = try? context.fetch(FetchDescriptor<CookingLibrary>()).first(where: { $0.key == "local" }),
              let global = try? context.fetch(FetchDescriptor<RankingList>()).first(where: { $0.id == library.globalRankingID }),
              list == nil || list?.id == global.id,
              let attempts = try? context.fetch(FetchDescriptor<CookingAttempt>()),
              let tombstones = try? context.fetch(FetchDescriptor<SyncTombstone>()) else { return [] }
        let unavailable = Set((context.deletedModelsArray + context.insertedModelsArray).map(\.persistentModelID))
        let retired = Set(tombstones.map(\.key))
        func active(_ entity: SyncEntity, _ id: UUID) -> Bool {
            !retired.contains(SyncReference(entity: entity, key: id.uuidString.lowercased()).identity)
        }
        guard !unavailable.contains(global.persistentModelID), active(.ranking, global.id) else { return [] }
        return CookingDiscovery.entries(in: global, attempts: attempts).filter { entry in
            let attempt = entry.attempt
            guard let dish = attempt.dish, let item = attempt.rankedItem,
                  item.id == attempt.rankedItemID, item.list?.id == global.id,
                  dish.attempts.contains(where: { $0.id == attempt.id }),
                  ![attempt.persistentModelID, dish.persistentModelID, item.persistentModelID].contains(where: unavailable.contains)
            else { return false }
            return active(.dish, dish.id) && active(.attempt, attempt.id) && active(.rankedItem, item.id)
        }
    }

    @MainActor static func state(in context: ModelContext, list: RankingList? = nil) -> ScoreUnlockState {
        ScoreUnlockState(rankedEntryCount: Set(entries(in: context, list: list).map { $0.attempt.rankedItemID }).count)
    }

    @MainActor static func state(for attempt: CookingAttempt) -> ScoreUnlockState {
        guard let context = attempt.modelContext, let list = attempt.rankedItem?.list else { return .locked }
        let eligible = entries(in: context, list: list)
        guard eligible.contains(where: { $0.attempt.id == attempt.id }) else { return .locked }
        return ScoreUnlockState(rankedEntryCount: Set(eligible.map { $0.attempt.rankedItemID }).count)
    }

    static func crossed(from previous: Int, to current: ScoreUnlockState) -> Bool {
        previous < requiredRankedEntryCount && current.isUnlocked
    }
}

nonisolated struct ScoreUnlockState: Equatable, Sendable {
    let rankedEntryCount: Int
    static let locked = Self(rankedEntryCount: 0)
    var isUnlocked: Bool { rankedEntryCount >= ScoreUnlockPolicy.requiredRankedEntryCount }
    var remainingEntryCount: Int { max(0, ScoreUnlockPolicy.requiredRankedEntryCount - rankedEntryCount) }
    var progress: Double { min(1, Double(max(0, rankedEntryCount)) / Double(ScoreUnlockPolicy.requiredRankedEntryCount)) }
    var progressText: String { "\(rankedEntryCount) / \(ScoreUnlockPolicy.requiredRankedEntryCount) dishes & versions ranked" }
    var remainingText: String {
        "Rank \(remainingEntryCount) more \(remainingEntryCount == 1 ? "dish or version" : "dishes or versions") to reveal your numerical scores."
    }
    var completionText: String {
        "You're building your rankings. Rank \(ScoreUnlockPolicy.requiredRankedEntryCount) dishes or versions to unlock your numerical scores."
    }
    func scoreText(_ score: Double) -> String? {
        guard isUnlocked, score.isFinite else { return nil }
        return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), score)
    }
}

/// Local, per-account/per-installation presentation receipt. No cooking store or
/// cloud write. Hydration alone never presents or consumes an event milestone.
@MainActor enum ScoreUnlockMilestones {
    static func claim(scope: String?, previous: Int?, current: ScoreUnlockState,
                      defaults: UserDefaults = .standard) -> Bool {
        guard let scope, !scope.isEmpty, let previous,
              ScoreUnlockPolicy.crossed(from: previous, to: current) else { return false }
        let key = "StayGrubby.scoreUnlock.presented.v1.\(scope)"
        guard !defaults.bool(forKey: key) else { return false }
        defaults.set(true, forKey: key)
        return true
    }
}

private struct ScoreUnlockStateKey: EnvironmentKey { static let defaultValue = ScoreUnlockState.locked }
private struct ScoreMilestoneScopeKey: EnvironmentKey { static let defaultValue: String? = nil }
extension EnvironmentValues {
    var scoreUnlockState: ScoreUnlockState {
        get { self[ScoreUnlockStateKey.self] }
        set { self[ScoreUnlockStateKey.self] = newValue }
    }
    var scoreMilestoneScope: String? {
        get { self[ScoreMilestoneScopeKey.self] }
        set { self[ScoreMilestoneScopeKey.self] = newValue }
    }
}

struct ScoreUnlockProgressBanner: View {
    let state: ScoreUnlockState
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            Label("Unlock your scores", systemImage: "lock.fill").font(SGTheme.TypeRole.headline)
            ProgressView(value: state.progress).progressViewStyle(StayGrubbyUnlockProgressStyle()).accessibilityHidden(true)
            Text(state.progressText).font(SGTheme.TypeRole.body.weight(.semibold))
                .accessibilityIdentifier("score-unlock-progress")
            Text(state.remainingText).font(SGTheme.TypeRole.secondary)
        }
        .foregroundStyle(SGTheme.Brand.charcoal)
        .padding(SGTheme.Space.medium)
        .background(SGTheme.Brand.cream, in: RoundedRectangle(cornerRadius: SGTheme.Radius.card))
        .padding(.vertical, SGTheme.Space.small)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("score-unlock-banner")
    }
}

struct LockedScoreIndicator: View {
    var body: some View {
        Image(systemName: "lock.fill").font(SGTheme.TypeRole.secondary)
            .foregroundStyle(.secondary)
            .padding(SGTheme.Space.xSmall)
            .accessibilityLabel("Score locked")
            .accessibilityHint("Rank \(ScoreUnlockPolicy.requiredRankedEntryCount) dishes or versions to reveal scores")
            .accessibilityIdentifier("score-locked")
    }
}

/// Explicit SwiftUI shapes keep the official red fill in either appearance;
/// the system linear style can substitute its monochrome dark-mode treatment.
struct StayGrubbyUnlockProgressStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(SGTheme.Brand.charcoal.opacity(0.18))
                Capsule().fill(SGTheme.Brand.red)
                    .frame(width: geometry.size.width * min(1, max(0, configuration.fractionCompleted ?? 0)))
            }
        }.frame(height: 6)
    }
}
