import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selection: StayGrubbyTab = .rankings

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                ContentUnavailableView("Feed comes later", systemImage: "rectangle.stack",
                    description: Text("Your private cooking rankings stay local in this version."))
                    .navigationTitle("Feed")
            }
            .tabItem { Label("Feed", systemImage: "house") }.tag(StayGrubbyTab.feed)

            HomeView()
                .tabItem { Label("Rankings", systemImage: "chart.bar.fill") }
                .tag(StayGrubbyTab.rankings)

            NavigationStack {
                ContentUnavailableView("Profile comes later", systemImage: "person.crop.circle",
                    description: Text("Accounts and social profiles are outside the local app."))
                    .navigationTitle("Profile")
            }
            .tabItem { Label("Profile", systemImage: "person") }.tag(StayGrubbyTab.profile)
        }
        .tint(SGTheme.ColorToken.accent)
    }
}

enum StayGrubbyTab: Hashable { case feed, rankings, profile }

#Preview {
    ContentView().modelContainer(try! ModelContainer(for: AppPersistence.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]))
}
