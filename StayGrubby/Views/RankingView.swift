import SwiftUI
import SwiftData

struct RankingDraft: Identifiable {
    let id = UUID()
    var name = ""
    var session: RankingEngine?
}

struct RankingView: View {
    @Environment(\.modelContext) private var context
    let list: RankingList
    @State private var draft: RankingDraft?
    @State private var lastCompleted: RankingDraft?
    @State private var error: String?

    var body: some View {
        List {
            if list.items.isEmpty {
                ContentUnavailableView("Start your ranking", systemImage: "list.number",
                                       description: Text("Add an item. A few quick choices will find its place."))
            }
            ForEach(Array(list.orderedItems.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 16) {
                    Text("\(index + 1)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary).frame(minWidth: 24)
                    Text(item.name).font(.body.weight(.medium)).frame(maxWidth: .infinity, alignment: .leading)
                    Text(item.score, format: .number.precision(.fractionLength(1)))
                        .font(.title3.weight(.semibold).monospacedDigit()).foregroundStyle(.tint)
                }
                .padding(.vertical, 10)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Rank \(index + 1), \(item.name), score \(item.score.formatted(.number.precision(.fractionLength(1))))")
            }
            if let lastCompleted, lastCompleted.session?.canUndo == true {
                Section {
                    Button("Undo last answer", systemImage: "arrow.uturn.backward") { undoCompletion() }
                } footer: {
                    Text(lastCompleted.session?.placementResolved == true
                         ? "Scores are estimates and refine as you compare."
                         : "Placement is provisional: no more useful comparisons were available.")
                }
            }
        }
        .navigationTitle(list.name)
        .safeAreaInset(edge: .bottom) {
            Button {
                lastCompleted = nil
                draft = RankingDraft()
            } label: {
                Label("Add Item", systemImage: "plus").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
            }.buttonStyle(.borderedProminent).accessibilityIdentifier("add-item").padding().background(.bar)
        }
        .sheet(item: $draft) { draft in
            AddItemView(list: list, draft: draft) { completed in lastCompleted = completed }
        }
        .alert("Couldn't undo", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func undoCompletion() {
        guard var completed = lastCompleted, var session = completed.session else { return }
        do {
            try RankingStore.removeSession(session, from: list, context: context)
            session.undo()
            completed.session = session
            lastCompleted = nil
            draft = completed
        } catch { self.error = error.localizedDescription }
    }
}
