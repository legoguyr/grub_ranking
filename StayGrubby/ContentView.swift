import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AccountSessionCoordinator.self) private var accountSession
    @State private var selection: StayGrubbyTab = .rankings

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { SocialFeedView(isSelected: selection == .feed) }
                .tabItem { Label("Grub List", systemImage: "house") }.tag(StayGrubbyTab.feed)

            HomeView()
                .tabItem { Label("Grub Rank", systemImage: "chart.bar.fill") }
                .tag(StayGrubbyTab.rankings)

            NavigationStack { FoodBibleView() }
                .tabItem { Label("Food Bible", systemImage: "book.closed") }.tag(StayGrubbyTab.bible)

            NavigationStack {
                AccountView()
            }
            .tabItem { Label("My Kitchen", systemImage: "person") }.tag(StayGrubbyTab.profile)
        }
        .tint(SGTheme.ColorToken.accent)
        .modifier(AppLinkPresentation())
        .modifier(SocialPublicationHost())
        #if DEBUG
        .modifier(SocialReviewModifier())
        #endif

    }


}

enum StayGrubbyTab: Hashable { case feed, rankings, bible, profile }

#Preview {
    ContentView().environment(AppLinkRouter()).environment(AccountSessionCoordinator()).modelContainer(try! ModelContainer(for: AppPersistence.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]))
}
