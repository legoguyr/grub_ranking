import SwiftUI
import SwiftData

struct AttemptDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let attempt: CookingAttempt
    @State private var editing = false
    @State private var reranking = false
    @State private var addingVersion = false
    @State private var deleting = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SGTheme.Space.large) {
                DishPhoto(media: attempt.primaryImage, name: attempt.dish?.name ?? attempt.displayName)
                    .frame(maxWidth: .infinity).frame(height: SGTheme.Size.heroHeight)
                    .clipShape(RoundedRectangle(cornerRadius: SGTheme.Radius.hero, style: .continuous))
                header
                actionButtons
                metadata
                if let source = attempt.dish?.source {
                    VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                        SGSectionHeader(title: "Source")
                        SourceSummary(source: source)
                    }.sgCard()
                }
                if let notes = attempt.notes {
                    VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                        SGSectionHeader(title: "Notes")
                        Text(notes)
                    }.sgCard()
                }
                versions
            }
            .padding(.horizontal, SGTheme.Space.medium).padding(.bottom, SGTheme.Space.xLarge)
        }
        .background(SGTheme.ColorToken.background)
        .navigationTitle("Dish Details").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editing) { EditCookingView(attempt: attempt) }
        .sheet(isPresented: $reranking) { ReRankView(attempt: attempt) }
        .sheet(isPresented: $addingVersion) {
            if let list = attempt.rankedItem?.list, let dish = attempt.dish {
                AddCookingView(list: list, dish: dish)
            }
        }
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

    private var globalRank: Int? {
        guard let item = attempt.rankedItem, let ordered = item.list?.orderedItems,
              let index = ordered.firstIndex(where: { $0.id == item.id }) else { return nil }
        return index + 1
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                Text(attempt.dish?.name ?? "Dish").font(.largeTitle.bold())
                Text(attempt.versionLabel).font(.headline).foregroundStyle(.secondary)
            }
            Spacer()
            if let item = attempt.rankedItem { ScoreBadge(score: item.score) }
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
            HStack {
                Label(attempt.category.label, systemImage: "fork.knife")
                Spacer()
                if let globalRank { Label("#\(globalRank)", systemImage: "trophy") }
            }.font(.subheadline.weight(.semibold))
            Label(attempt.cookedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Date unknown",
                  systemImage: "calendar")
                .font(.subheadline).foregroundStyle(.secondary)
            if !allTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SGTheme.Space.xSmall) {
                        ForEach(allTags, id: \.self) { TagChip(title: $0) }
                    }
                }
            }
            if !attempt.allergyTags.isEmpty {
                Text("Allergy labels are user-entered and are not a verified safety guarantee.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.sgCard()
    }

    private var allTags: [String] {
        attempt.dietaryTags.map(\.label).sorted() + attempt.allergyTags.map(\.label).sorted() + attempt.customTags
    }

    private var versions: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            HStack {
                SGSectionHeader(title: "Versions")
                Button("New Version", systemImage: "plus") { addingVersion = true }
                    .disabled(attempt.dish == nil || attempt.rankedItem?.list == nil)
            }
            ForEach(versionEntries, id: \.attempt.id) { entry in
                if entry.attempt.id == attempt.id {
                    versionRow(entry.attempt, rank: entry.rank, current: true)
                } else {
                    NavigationLink { AttemptDetailView(attempt: entry.attempt) } label: {
                        versionRow(entry.attempt, rank: entry.rank, current: false)
                    }.buttonStyle(.plain)
                }
            }
        }.sgCard()
    }

    private var versionEntries: [(rank: Int, attempt: CookingAttempt)] {
        guard let dish = attempt.dish, let ordered = attempt.rankedItem?.list?.orderedItems else { return [] }
        let ranks = Dictionary(uniqueKeysWithValues: ordered.enumerated().map { ($0.element.id, $0.offset + 1) })
        return dish.attempts.compactMap { cook in ranks[cook.rankedItemID].map { ($0, cook) } }
            .sorted { $0.rank < $1.rank }
    }

    private func versionRow(_ cook: CookingAttempt, rank: Int, current: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(cook.versionLabel).font(.headline)
                Text(cook.cookedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Date unknown")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("#\(rank)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            if let item = cook.rankedItem { ScoreBadge(score: item.score) }
            if current { Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint) }
        }
        .padding(.vertical, SGTheme.Space.xSmall)
        .accessibilityElement(children: .combine)
    }

    private var actionButtons: some View {
        VStack(spacing: SGTheme.Space.small) {
            HStack {
                Button("Edit Cook", systemImage: "pencil") { editing = true }
                Spacer()
                Button("Re-rank", systemImage: "arrow.triangle.2.circlepath") { reranking = true }
            }
            .buttonStyle(.bordered).frame(minHeight: SGTheme.Size.minimumTap)
            Button("Delete Cook", systemImage: "trash", role: .destructive) { deleting = true }
                .frame(maxWidth: .infinity, minHeight: SGTheme.Size.minimumTap)
        }
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
