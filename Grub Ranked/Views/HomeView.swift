import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @State private var error: String?
    @State private var cookingList: RankingList?

    var body: some View {
        NavigationStack {
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
            .task { prepareCooking() }
        }
    }

    private func prepareCooking() {
        error = nil
        do { cookingList = try CookingStore.prepare(context: context) }
        catch { self.error = error.localizedDescription }
    }
}
