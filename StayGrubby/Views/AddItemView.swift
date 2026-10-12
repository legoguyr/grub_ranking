import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let list: RankingList
    let onComplete: (RankingDraft) -> Void
    @State private var draft: RankingDraft
    @State private var choosingReaction = false
    @State private var error: String?
    @FocusState private var nameFocused: Bool

    init(list: RankingList, draft: RankingDraft, onComplete: @escaping (RankingDraft) -> Void) {
        self.list = list; self.onComplete = onComplete; _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let session = draft.session {
                    if let opponentID = session.nextOpponent,
                       let opponent = list.items.first(where: { $0.id == opponentID }) {
                        ComparisonView(newName: draft.name, existingName: opponent.name, canUndo: session.canUndo,
                                       onAnswer: answer, onUndo: { draft.session?.undo() })
                    } else {
                        VStack(spacing: 20) {
                            Text("Ready to save your ranking").font(.headline)
                            Button("Save Ranking", action: save).buttonStyle(.borderedProminent)
                            if session.canUndo { Button("Undo last answer") { draft.session?.undo() } }
                        }
                    }
                } else if choosingReaction {
                    InitialReactionView(name: draft.name) { reaction in
                        draft.session = RankingEngine(itemID: UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: reaction)
                        if draft.session?.isComplete == true { save() }
                    }
                } else {
                    Form {
                        Section("What are you adding?") {
                            TextField("Item name", text: $draft.name).accessibilityIdentifier("item-name").focused($nameFocused).submitLabel(.next).onSubmit(begin)
                        }
                        Button("Continue", action: begin).disabled(trimmedName.isEmpty).frame(minHeight: 44)
                    }
                    .onAppear { nameFocused = true }
                }
            }
            .navigationTitle("Add Item")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .interactiveDismissDisabled(draft.session != nil)
            .alert("Couldn't save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("Try Again", action: save)
                Button("Cancel", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
        }
    }
    private var trimmedName: String { draft.name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private func begin() {
        guard !trimmedName.isEmpty else { return }
        draft.name = trimmedName; nameFocused = false; choosingReaction = true
    }
    private func answer(_ answer: ComparisonAnswer) {
        draft.session?.answer(answer)
        if draft.session?.isComplete == true { save() }
    }
    private func save() {
        guard let session = draft.session else { return }
        do {
            try RankingStore.save(name: draft.name, session: session, to: list, context: context)
            onComplete(draft); dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
