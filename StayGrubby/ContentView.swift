import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AccountSessionCoordinator.self) private var accountSession
    @State private var selection: StayGrubbyTab = .rankings

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Rankings", systemImage: "chart.bar.fill") }
                .tag(StayGrubbyTab.rankings)

            NavigationStack {
                AccountView()
            }
            .tabItem { Label("Profile", systemImage: "person") }.tag(StayGrubbyTab.profile)
        }
        .tint(SGTheme.ColorToken.accent)
        #if DEBUG
        .modifier(SocialReviewModifier())
        #endif

    }

    // Re-enable in TabView when Profiles, Following, and Friends Feed are available.
    private var feedDestination: some View {
        NavigationStack {
            ContentUnavailableView("Feed comes later", systemImage: "rectangle.stack",
                description: Text("Your private cooking rankings stay local in this version."))
                .navigationTitle("Feed").toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .top) { StayGrubbyHeader(page: "Feed", searchText: .constant(""), searching: .constant(false)) }
                .background(SGTheme.ColorToken.background)
        }
        .tabItem { Label("Feed", systemImage: "house") }.tag(StayGrubbyTab.feed)
    }
}

enum StayGrubbyTab: Hashable { case feed, rankings, profile }

#Preview {
    ContentView().environment(AccountSessionCoordinator()).modelContainer(try! ModelContainer(for: AppPersistence.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]))
}
