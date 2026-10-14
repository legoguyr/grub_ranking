import SwiftUI
import SwiftData

struct ReRankView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var attempts: [CookingAttempt]
    let attempt: CookingAttempt
    @State private var workflow: CookingReRankingWorkflow
    @State private var error: String?
    @State private var saving = false
    init(attempt: CookingAttempt) {
        self.attempt = attempt
        _workflow = State(initialValue: CookingReRankingWorkflow(attempt: attempt))
    }
    var body: some View {
        NavigationStack {
            Group {
                if workflow.completed {
                    CookingRankingResultView(attempt: attempt, event: workflow.completionSnapshot, onClose: { dismiss() })
                } else if let session = workflow.session {
                    if let opponent = attempt.rankedItem?.list?.items.first(where: { $0.id == session.nextOpponent }) {
                        let opponentAttempt = attempts.first { $0.rankedItemID == opponent.id }
                        ComparisonView(newName: attempt.dish?.name ?? attempt.displayName,
                            existingName: opponentAttempt?.dish?.name ?? opponent.name,
                            newVersion: attempt.versionLabel, existingVersion: opponentAttempt?.versionLabel,
                            newPhoto: attempt.primaryImage, existingPhoto: opponentAttempt?.primaryImage,
                            canUndo: session.canUndo, onAnswer: { workflow.answer($0) }, onUndo: { workflow.undo() })
                    } else if error == nil { ProgressView("Finishing your ranking…") }
                    else { Button("Retry", action: finish).buttonStyle(SGButtonStyle(prominent: true)) }
                } else {
                    InitialReactionView(name: attempt.displayName) { reaction in
                        do { try workflow.choose(reaction, context: context) }
                        catch { self.error = error.localizedDescription }
                    }
                }
            }
            .navigationTitle(workflow.completed ? "Ranking Result" : "Re-rank")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !workflow.completed {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                }
            }
            .interactiveDismissDisabled(workflow.session != nil)
            .task(id: workflow.session?.isComplete) { if workflow.session?.isComplete == true { finish() } }
            .alert("Couldn't save ranking", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                if workflow.session?.isComplete == true { Button("Retry", action: finish) }
                Button("Cancel", role: .cancel) { dismiss() }
            } message: { Text(error ?? "") }
        }
        .deferRemoteCookingUpdates()
    }
    private func finish() {
        guard !saving, !workflow.completed else { return }
        saving = true; error = nil
        defer { saving = false }
        do { try workflow.finish(context: context) }
        catch { self.error = error.localizedDescription }
    }
}
