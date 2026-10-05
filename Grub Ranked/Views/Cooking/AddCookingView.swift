import SwiftUI
import SwiftData

struct AddCookingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var attempts: [CookingAttempt]
    let list: RankingList
    let dish: Dish?
    @State private var draft: CookingDraft
    @State private var choosingReaction = false
    @State private var session: RankingEngine?
    @State private var error: String?

    init(list: RankingList, dish: Dish? = nil) {
        self.list = list; self.dish = dish
        _draft = State(initialValue: dish.map { CookingDraft(dish: $0) } ?? CookingDraft())
    }
    private var displayName: String {
        "\(draft.cleanDishName) — \(draft.cleanTitle ?? "Version \((dish?.attempts.map(\.sequenceNumber).max() ?? 0) + 1)")"
    }
    var body: some View {
        NavigationStack {
            Group {
                if let session {
                    if let opponent = list.items.first(where: { $0.id == session.nextOpponent }) {
                        let opponentAttempt = attempts.first { $0.rankedItemID == opponent.id }
                        ComparisonView(newName: draft.cleanDishName,
                                       existingName: opponentAttempt?.dish?.name ?? opponent.name,
                                       newVersion: draft.cleanTitle ?? "Version \((dish?.attempts.map(\.sequenceNumber).max() ?? 0) + 1)",
                                       existingVersion: opponentAttempt?.versionLabel,
                                       newPreparedPhoto: draft.pendingPhoto,
                                       existingPhoto: opponentAttempt?.primaryImage,
                                       canUndo: session.canUndo,
                                       onAnswer: { self.session?.answer($0) }, onUndo: { self.session?.undo() })
                    } else {
                        VStack(spacing: 20) {
                            Text("Ready to save this cook").font(.headline)
                            Button("Save Cook", action: save).buttonStyle(.borderedProminent)
                            if session.canUndo { Button("Undo last answer") { self.session?.undo() } }
                        }
                    }
                } else if choosingReaction {
                    InitialReactionView(name: displayName) { reaction in
                        session = RankingEngine(itemID: UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: reaction)
                    }
                } else {
                    Form { CookingMetadataForm(draft: $draft, existingDish: dish != nil) }
                }
            }
            .navigationTitle(dish == nil ? "New Dish" : "New Version")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                if !choosingReaction && session == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Continue") { choosingReaction = true }.disabled(draft.cleanDishName.isEmpty)
                    }
                } else if session == nil {
                    ToolbarItem(placement: .confirmationAction) { Button("Edit Details") { choosingReaction = false } }
                }
            }
            .interactiveDismissDisabled(session != nil)
            .alert("Couldn't save cook", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
        }
    }
    private func save() {
        guard let session else { return }
        do { try CookingStore.create(draft: draft, existingDish: dish, session: session, context: context); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}
