import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @State private var error: String?
    @State private var cookingList: RankingList?
    @State private var path = NavigationPath()
    @Query private var attempts: [CookingAttempt]
    @Query private var scoreTombstones: [SyncTombstone]

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                #if DEBUG
                if let mode = DebugReviewConfiguration.current.sharingMode {
                    SharingReviewFixture(mode: mode)
                } else {
                    rankingContent
                }
                #else
                rankingContent
                #endif
            }
            .navigationDestination(for: UUID.self) { id in
                if let attempt = attempts.first(where: { $0.id == id }) { AttemptDetailView(attempt: attempt) }
            }
            .task { prepareCooking() }
        }
        .environment(\.returnToRankings, { path = NavigationPath() })
        .environment(\.scoreUnlockState, scoreState)
    }

    private var scoreState: ScoreUnlockState {
        _ = attempts.count; _ = scoreTombstones.count
        return ScoreUnlockPolicy.state(in: context, list: cookingList)
    }

    @ViewBuilder private var rankingContent: some View {
        if let cookingList {
            CookingRankingView(list: cookingList)
        } else if let error {
            ContentUnavailableView {
                Label("Couldn't open Rankings", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            } actions: {
                Button("Try Again", action: prepareCooking)
            }
        } else {
            ProgressView("Opening Rankings")
        }
    }

    private func prepareCooking() {
        error = nil
        do { cookingList = try CookingStore.prepare(context: context) }
        catch { self.error = error.localizedDescription }
    }
}

private struct ReturnToRankingsKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}
extension EnvironmentValues {
    var returnToRankings: () -> Void {
        get { self[ReturnToRankingsKey.self] }
        set { self[ReturnToRankingsKey.self] = newValue }
    }
}
