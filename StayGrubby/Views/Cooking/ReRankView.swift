import SwiftUI
import SwiftData

struct ReRankView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var attempts: [CookingAttempt]
    let attempt: CookingAttempt
    @State private var session: ReRankingSession
    @State private var error: String?
    init(attempt: CookingAttempt) {
        self.attempt = attempt
        let list = attempt.rankedItem?.list
        _session = State(initialValue: ReRankingSession(itemID: attempt.rankedItemID,
            ids: list?.items.map(\.id) ?? [], history: list?.comparisons.map(\.evidence) ?? []))
    }
    var body: some View {
        NavigationStack {
            Group {
                if let opponent = attempt.rankedItem?.list?.items.first(where: { $0.id == session.nextOpponent }) {
                    let opponentAttempt = attempts.first { $0.rankedItemID == opponent.id }
                    ComparisonView(newName: attempt.dish?.name ?? attempt.displayName,
                                   existingName: opponentAttempt?.dish?.name ?? opponent.name,
                                   newVersion: attempt.versionLabel,
                                   existingVersion: opponentAttempt?.versionLabel,
                                   newPhoto: attempt.primaryImage,
                                   existingPhoto: opponentAttempt?.primaryImage,
                                   canUndo: !session.answers.isEmpty,
                                   onAnswer: { session.answer($0) }, onUndo: { session.undo() })
                } else {
                    VStack(spacing: SGTheme.Space.large) {
                        Text(session.ids.count < 2 ? "Add another cook to compare." : "No more comparisons needed right now.")
                        if !session.answers.isEmpty { Button("Undo last answer") { session.undo() } }
                    }.padding()
                }
            }
            .navigationTitle("Re-rank").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Text("\(session.evidence.count) new answers. Saved history is kept.")
                    .font(.footnote).foregroundStyle(.secondary).padding()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Answers") {
                        do { try CookingStore.rerank(attempt, evidence: session.evidence, context: context); dismiss() }
                        catch { self.error = error.localizedDescription }
                    }.disabled(session.evidence.isEmpty)
                }
            }
            .interactiveDismissDisabled(!session.evidence.isEmpty)
            .alert("Couldn't save answers", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
        }
    }
}
