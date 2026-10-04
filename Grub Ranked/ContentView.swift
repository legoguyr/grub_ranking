import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View { HomeView() }
}

#Preview {
    ContentView().modelContainer(try! ModelContainer(for: AppPersistence.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]))
}
