import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AccountSessionCoordinator.self) private var accountSession
    @State private var selection: StayGrubbyTab = .rankings

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { SocialFeedView(isSelected: selection == .feed) }
                .tabItem { Label("Feed", systemImage: "house") }.tag(StayGrubbyTab.feed)

            HomeView()
                .tabItem { Label("Rankings", systemImage: "chart.bar.fill") }
                .tag(StayGrubbyTab.rankings)

            NavigationStack {
                AccountView()
            }
            .tabItem { Label("Profile", systemImage: "person") }.tag(StayGrubbyTab.profile)
        }
        .tint(SGTheme.ColorToken.accent)
        .modifier(SocialPublicationHost())
        #if DEBUG
        .modifier(SocialReviewModifier())
        #endif

    }


}

enum StayGrubbyTab: Hashable { case feed, rankings, profile }

#Preview {
    ContentView().environment(AccountSessionCoordinator()).modelContainer(try! ModelContainer(for: AppPersistence.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]))
}
