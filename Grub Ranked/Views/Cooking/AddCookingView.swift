import SwiftUI
import SwiftData

struct AddCookingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var attempts: [CookingAttempt]
    let list: RankingList
    let dish: Dish?
    let onResultClose: () -> Void
    @State private var draft: CookingDraft
    @State private var choosingReaction = false
    @State private var session: RankingEngine?
    @State private var error: String?
    @State private var savedAttempt: CookingAttempt?
    @State private var saving = false
    @State private var saveFailed = false

    init(list: RankingList, dish: Dish? = nil, onResultClose: @escaping () -> Void = {}) {
        self.list = list; self.dish = dish; self.onResultClose = onResultClose
        _draft = State(initialValue: dish.map { CookingDraft(dish: $0) } ?? CookingDraft())
    }
    private var displayName: String {
        "\(draft.cleanDishName) — \(draft.cleanTitle ?? "Version \((dish?.attempts.map(\.sequenceNumber).max() ?? 0) + 1)")"
    }
    var body: some View {
        NavigationStack {
            Group {
                if let savedAttempt {
                    CookingRankingResultView(attempt: savedAttempt, onClose: { onResultClose(); dismiss() })
                } else if let session {
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
                        VStack(spacing: SGTheme.Space.medium) {
                            if !saveFailed { ProgressView("Finishing your cook…") }
                            else {
                                Text("Your cook hasn’t been saved yet.")
                                Button("Retry", action: save).buttonStyle(SGButtonStyle(prominent: true))
                            }
                        }
                    }
                } else if choosingReaction {
                    InitialReactionView(name: displayName) { reaction in
                        session = RankingEngine(itemID: UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: reaction)
                    }
                } else {
                    CookingFormScroll(draft: $draft, existingDish: dish != nil)
                }
            }
            .navigationTitle(savedAttempt != nil ? "Ranking Result" : session == nil ? (dish == nil ? "New Dish" : "New Version") : "Rank this cook")
            .navigationBarTitleDisplayMode(.inline)
            .background(SGTheme.ColorToken.background)
            .toolbar {
                if savedAttempt == nil { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                if choosingReaction && session == nil {
                    ToolbarItem(placement: .confirmationAction) { Button("Edit Details") { choosingReaction = false } }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !choosingReaction && session == nil {
                    Button { choosingReaction = true } label: {
                        Text("Continue").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SGButtonStyle(prominent: true)).disabled(draft.cleanDishName.isEmpty)
                    .padding(SGTheme.Space.medium).background(SGTheme.ColorToken.background)
                }
            }
            .interactiveDismissDisabled(session != nil)
            .task(id: session?.isComplete) { if session?.isComplete == true { save() } }
            .alert("Couldn't save cook", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("Retry", action: save)
                Button("Cancel", role: .cancel) { dismiss() }
            } message: { Text(error ?? "") }
        }
    }
    private func save() {
        guard let session, session.isComplete, savedAttempt == nil, !saving else { return }
        saving = true; error = nil; saveFailed = false
        defer { saving = false }
        do { savedAttempt = try CookingStore.create(draft: draft, existingDish: dish, session: session, context: context) }
        catch { saveFailed = true; self.error = error.localizedDescription }
    }
}
