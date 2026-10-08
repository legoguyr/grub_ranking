import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @State private var error: String?
    @State private var cookingList: RankingList?
    @State private var path = NavigationPath()
    @Query private var attempts: [CookingAttempt]

    var body: some View {
        NavigationStack(path: $path) {
            Group {
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
            .navigationDestination(for: UUID.self) { id in
                if let attempt = attempts.first(where: { $0.id == id }) { AttemptDetailView(attempt: attempt) }
            }
            .task { prepareCooking() }
        }
        .environment(\.returnToRankings, { path = NavigationPath() })
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
