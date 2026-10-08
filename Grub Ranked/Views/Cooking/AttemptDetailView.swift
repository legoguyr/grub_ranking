import SwiftUI
import SwiftData

struct AttemptDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let attempt: CookingAttempt
    @State private var editing = false
    @State private var reranking = false
    @State private var addingVersion = false
    @State private var versionFinalized = false
    @Environment(\.returnToRankings) private var returnToRankings
    @State private var deleting = false
    @State private var error: String?
    @Environment(\.dynamicTypeSize) private var textSize
    @ScaledMetric(relativeTo: .caption) private var tagColumnWidth = SGTheme.Size.tagColumnWidth

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SGTheme.Space.medium) {
                SGHeroMedia(media: attempt.primaryImage, name: attempt.dish?.name ?? attempt.displayName)
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
            .frame(maxWidth: SGTheme.Size.contentMaximum)
            .padding(.horizontal, SGTheme.Space.medium).padding(.bottom, SGTheme.Space.xLarge)
            .frame(maxWidth: .infinity)
        }
        .background(SGTheme.ColorToken.background)
        .navigationTitle("Dish Details").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Delete Cook", systemImage: "trash", role: .destructive) { deleting = true }
                } label: { Image(systemName: "ellipsis") }
                .accessibilityLabel("More cook actions").accessibilityIdentifier("cook-more-actions")
            }
        }
        .sheet(isPresented: $editing) { EditCookingView(attempt: attempt) }
        .sheet(isPresented: $reranking) { ReRankView(attempt: attempt) }
        .sheet(isPresented: $addingVersion, onDismiss: {
            if versionFinalized { versionFinalized = false; returnToRankings() }
        }) {
            if let list = attempt.rankedItem?.list, let dish = attempt.dish {
                AddCookingView(list: list, dish: dish, onResultClose: { versionFinalized = true })
            }
        }
        .alert("Delete this cook?", isPresented: $deleting) {
            Button("Delete Cook", role: .destructive) {
                do { try CookingStore.delete(attempt, context: context); dismiss() }
                catch { self.error = error.localizedDescription }
            }
            Button("Cancel", role: .cancel) { }
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
        VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
            Text(attempt.dish?.name ?? "Dish").font(SGTheme.TypeRole.title)
                .fixedSize(horizontal: false, vertical: true)
            Text(attempt.versionLabel).font(SGTheme.TypeRole.body).foregroundStyle(.secondary)
            HStack(spacing: SGTheme.Space.small) {
                if let item = attempt.rankedItem { ScoreBadge(score: item.score) }
                if let globalRank {
                    Text("#\(globalRank) overall").font(SGTheme.TypeRole.body).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
            HStack {
                Label(attempt.category.label, systemImage: "fork.knife")
                Spacer()

            }.font(.subheadline.weight(.semibold))
            Label(attempt.cookedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Date unknown",
                  systemImage: "calendar")
                .font(.subheadline).foregroundStyle(.secondary)
            if !allTags.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: SGTheme.Space.xSmall) { ForEach(allTags, id: \.self) { TagChip(title: $0) } }
                        .fixedSize(horizontal: true, vertical: false)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: tagColumnWidth), alignment: .leading)], alignment: .leading, spacing: SGTheme.Space.xSmall) {
                        ForEach(allTags, id: \.self) { TagChip(title: $0) }
                    }
                }
            }
            if !attempt.containedAllergens.isEmpty {
                Text("Contains: " + attempt.containedAllergens.map(\.label).sorted().joined(separator: ", "))
                    .accessibilityIdentifier("detail-contains")
                Text(CookingProductOptions.allergenSafetyText)
                    .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
            }
            if !attempt.allergyTags.isEmpty {
                Text("Legacy free-of labels: " + attempt.allergyTags.map(\.label).sorted().joined(separator: ", "))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.sgCard()
    }

    private var allTags: [String] {
        attempt.dietaryTags.map(\.label).sorted() + attempt.customTags
    }

    private var versions: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            if textSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                    SGSectionHeader(title: "Versions")
                    newVersionButton
                }
            } else {
                HStack { SGSectionHeader(title: "Versions"); newVersionButton }
            }
            ForEach(versionEntries, id: \.attempt.id) { entry in
                if entry.attempt.id == attempt.id {
                    versionRow(entry.attempt, rank: entry.rank, current: true)
                } else {
                    NavigationLink(value: entry.attempt.id) {
                        versionRow(entry.attempt, rank: entry.rank, current: false)
                    }.buttonStyle(.plain)
                }
            }
        }.sgCard()
    }

    private var newVersionButton: some View {
        Button("New Version", systemImage: "plus") { addingVersion = true }
            .buttonStyle(SGButtonStyle()).accessibilityIdentifier("detail-new-version")
            .disabled(attempt.dish == nil || attempt.rankedItem?.list == nil)
    }

    private var versionEntries: [(rank: Int, attempt: CookingAttempt)] {
        guard let dish = attempt.dish, let ordered = attempt.rankedItem?.list?.orderedItems else { return [] }
        let ranks = Dictionary(uniqueKeysWithValues: ordered.enumerated().map { ($0.element.id, $0.offset + 1) })
        return dish.attempts.compactMap { cook in ranks[cook.rankedItemID].map { ($0, cook) } }
            .sorted { $0.rank < $1.rank }
    }

    private func versionRow(_ cook: CookingAttempt, rank: Int, current: Bool) -> some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
            HStack(spacing: SGTheme.Space.small) {
                if cook.primaryImage != nil {
                    DishPhoto(media: cook.primaryImage, thumbnail: true, name: cook.versionLabel)
                        .frame(width: SGTheme.Size.versionThumbnail, height: SGTheme.Size.versionThumbnail)
                        .clipShape(RoundedRectangle(cornerRadius: SGTheme.Radius.chip))
                }
                if !textSize.isAccessibilitySize { versionIdentity(cook) }
                Spacer(minLength: 0)
                Text("#\(rank)").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                if let item = cook.rankedItem { ScoreBadge(score: item.score) }
                Image(systemName: current ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundStyle(current ? SGTheme.ColorToken.accent : .secondary)
            }
            if textSize.isAccessibilitySize { versionIdentity(cook) }
        }
        .padding(.vertical, SGTheme.Space.small).contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("version-row-\(cook.id)")
        .accessibilityHint(current ? "Current version" : "Opens this version")
    }
    private func versionIdentity(_ cook: CookingAttempt) -> some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.hairline) {
            Text(cook.versionLabel).font(SGTheme.TypeRole.headline).fixedSize(horizontal: false, vertical: true)
            Text(cook.cookedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Date unknown")
                .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var actionButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: SGTheme.Space.small) { editButton; rerankButton }.fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: SGTheme.Space.small) { editButton; rerankButton }
        }
    }
    private var editButton: some View {
        Button("Edit Cook", systemImage: "pencil") { editing = true }.buttonStyle(SGButtonStyle())
    }
    private var rerankButton: some View {
        Button("Re-rank", systemImage: "arrow.triangle.2.circlepath") { reranking = true }.buttonStyle(SGButtonStyle())
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
            CookingFormScroll(draft: $draft, editing: true)
                .navigationTitle("Edit Cook").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }

                }
                .safeAreaInset(edge: .bottom) {
                    Button {
                        do { try CookingStore.edit(attempt, draft: draft, context: context); dismiss() }
                        catch { self.error = error.localizedDescription }
                    } label: { Text("Save").frame(maxWidth: .infinity) }
                    .buttonStyle(SGButtonStyle(prominent: true)).disabled(draft.cleanDishName.isEmpty)
                    .accessibilityIdentifier("save-cook-metadata")
                    .padding(SGTheme.Space.medium).background(SGTheme.ColorToken.background)
                }
                .alert("Couldn't save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                    Button("OK") { error = nil }
                } message: { Text(error ?? "") }
        }
    }
}
