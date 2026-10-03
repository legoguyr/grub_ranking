import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View { HomeView() }
}

#Preview {
    ContentView().modelContainer(for: [RankingList.self, RankedItem.self, Comparison.self], inMemory: true)
}
