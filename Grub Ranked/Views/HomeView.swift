import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RankingList.createdAt) private var lists: [RankingList]
    @State private var creating = false
    @State private var name = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                Section("My Rankings") {
                    if lists.isEmpty {
                        ContentUnavailableView("Your preferences, in order", systemImage: "list.number",
                                               description: Text("Create a ranking for anything you want to compare."))
                    }
                    ForEach(lists) { list in
                        NavigationLink {
                            RankingView(list: list)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(list.name).font(.headline)
                                Text("\(list.items.count) ranked items").font(.subheadline).foregroundStyle(.secondary)
                            }.padding(.vertical, 6)
                        }
                    }
                }
                Button { name = ""; creating = true } label: {
                    Label("New Ranking", systemImage: "plus").frame(minHeight: 44)
                }
            }
            .navigationTitle("Grub Ranked")
            .alert("New Ranking", isPresented: $creating) {
                TextField("Ranking name", text: $name)
                Button("Cancel", role: .cancel) {}
                Button("Create") { create() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: { Text("What would you like to rank?") }
            .alert("Couldn't save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
        }
    }
    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        context.insert(RankingList(name: trimmed))
        do { try context.save() } catch { context.rollback(); self.error = error.localizedDescription }
    }
}
