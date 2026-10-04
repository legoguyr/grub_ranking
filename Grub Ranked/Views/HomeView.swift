import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RankingList.createdAt) private var lists: [RankingList]
    @State private var creating = false
    @State private var name = ""
    @State private var error: String?
    @State private var cookingList: RankingList?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let cookingList {
                        NavigationLink {
                            CookingRankingView(list: cookingList)
                        } label: {
                            Label("My Cooking", systemImage: "fork.knife")
                        }.accessibilityIdentifier("my-cooking")
                    } else {
                        Button("Prepare Cooking Library", action: prepareCooking)
                    }
                }
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
            .navigationTitle("StayGrubby")
            .task { prepareCooking() }
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
    private func prepareCooking() {
        do { cookingList = try CookingStore.prepare(context: context) }
        catch { self.error = error.localizedDescription }
    }
    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        context.insert(RankingList(name: trimmed))
        do { try context.save() } catch { context.rollback(); self.error = error.localizedDescription }
    }
}
