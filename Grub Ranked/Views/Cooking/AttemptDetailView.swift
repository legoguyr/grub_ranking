import SwiftUI
import SwiftData

struct AttemptDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let attempt: CookingAttempt
    @State private var editing = false
    @State private var reranking = false
    @State private var deleting = false
    @State private var error: String?

    var body: some View {
        List {
            Section {
                Text(attempt.dish?.name ?? "Dish").font(.title2.bold())
                Text(attempt.versionLabel)
                if let item = attempt.rankedItem {
                    LabeledContent("Global score", value: item.score.formatted(.number.precision(.fractionLength(1))))
                }
                LabeledContent("Category", value: attempt.category.label)
                LabeledContent("Date cooked", value: attempt.cookedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")
                if let notes = attempt.notes { Text(notes) }
            }
            if !attempt.dietaryTags.isEmpty { Section("Dietary") { Text(attempt.dietaryTags.map(\.label).sorted().joined(separator: ", ")) } }
            if !attempt.allergyTags.isEmpty {
                Section { Text(attempt.allergyTags.map(\.label).sorted().joined(separator: ", ")) }
                header: { Text("Allergy") } footer: { Text("User-entered labels; not verified allergy safety information.") }
            }
            if !attempt.customTags.isEmpty { Section("Custom tags") { Text(attempt.customTags.joined(separator: ", ")) } }
            Section {
                Button("Edit Cook") { editing = true }
                Button("Re-rank") { reranking = true }
                Button("Delete Cook", role: .destructive) { deleting = true }
            }
        }
        .navigationTitle("Cook Details").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editing) { EditCookingView(attempt: attempt) }
        .sheet(isPresented: $reranking) { ReRankView(attempt: attempt) }
        .confirmationDialog("Delete this cook and all its comparisons?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete Cook", role: .destructive) {
                do { try CookingStore.delete(attempt, context: context); dismiss() }
                catch { self.error = error.localizedDescription }
            }
        } message: { Text("Other cooks stay saved. If this is the dish's last version, the dish is also removed.") }
        .alert("Couldn't delete", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }
}

struct EditCookingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let attempt: CookingAttempt
    @State private var draft: CookingDraft
    @State private var error: String?
    init(attempt: CookingAttempt) { self.attempt = attempt; _draft = State(initialValue: CookingDraft(attempt: attempt)) }
    var body: some View {
        NavigationStack {
            Form { CookingMetadataForm(draft: $draft, editing: true) }
                .navigationTitle("Edit Cook")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            do { try CookingStore.edit(attempt, draft: draft, context: context); dismiss() }
                            catch { self.error = error.localizedDescription }
                        }.disabled(draft.cleanDishName.isEmpty).accessibilityIdentifier("save-cook-metadata")
                    }
                }
                .alert("Couldn't save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                    Button("OK") { error = nil }
                } message: { Text(error ?? "") }
        }
    }
}
