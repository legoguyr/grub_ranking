import SwiftUI
import SwiftData

struct CookingRankingView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let list: RankingList
    @Query private var attempts: [CookingAttempt]
    @Query(sort: \Dish.name) private var dishes: [Dish]
    @State private var newDish = false
    @State private var choosingDish = false
    @State private var selectedDish: Dish?
    @State private var pendingDish: Dish?
    @State private var searchText = ""
    @State private var filters = CookingFilters()
    @State private var showingFilters = false
    private var eligibleDishes: [Dish] { dishes.filter { dish in dish.attempts.contains { $0.rankedItem?.list?.id == list.id } } }
    private var hasSearch: Bool { !TagNormalization.display(searchText).isEmpty }

    var body: some View {
        let entries = CookingDiscovery.entries(in: list, attempts: attempts, query: searchText, filters: filters)
        List {
            Section {
                creationActions
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                filterControls
                .buttonStyle(.borderless)
            }
            if filters.isActive {
                Section {
                    activeFilters
                }
            }
            Section {
                if list.items.isEmpty {
                    ContentUnavailableView {
                        Label("Your cooking, ranked", systemImage: "fork.knife")
                    } description: { Text("Add your first dish to begin.") } actions: {
                        Button("Add Your First Dish") { newDish = true }
                            .frame(minHeight: SGTheme.Size.minimumTap)
                    }
                } else if entries.isEmpty {
                    noResults
                }
                ForEach(entries) { entry in
                    NavigationLink { AttemptDetailView(attempt: entry.attempt) } label: {
                        RankedDishRow(attempt: entry.attempt, rank: entry.globalRank)
                    }
                    .accessibilityIdentifier("cook-row-\(entry.attempt.rankedItemID)")
                    .accessibilityLabel("Rank \(entry.globalRank), \(entry.attempt.displayName), score \(entry.attempt.rankedItem?.score.formatted(.number.precision(.fractionLength(1))) ?? "unknown")")
                    .accessibilityHint("Global rank. Opens dish details.")
                }
            } header: {
                if !list.items.isEmpty && (hasSearch || filters.isActive) {
                    Text("\(entries.count) of \(list.items.count) ranked cooks · Global ranks")
                        .accessibilityIdentifier("discovery-result-count")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(SGTheme.ColorToken.background)
        .navigationTitle("Rankings")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search dishes, versions, tags")
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showingFilters) { CookingFilterView(filters: $filters) }
        .sheet(isPresented: $newDish) { AddCookingView(list: list) }
        .sheet(item: $selectedDish) { AddCookingView(list: list, dish: $0) }
        .sheet(isPresented: $choosingDish, onDismiss: {
            selectedDish = pendingDish; pendingDish = nil
        }) {
            NavigationStack {
                List(eligibleDishes) { dish in
                    Button {
                        pendingDish = dish
                        choosingDish = false
                    } label: {
                        VStack(alignment: .leading) {
                            Text(dish.name)
                            Text("\(dish.attempts.count) versions").font(.caption).foregroundStyle(.secondary)
                        }
                    }.accessibilityIdentifier("choose-dish-\(dish.name)")
                }
                .navigationTitle("Choose a Dish")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { choosingDish = false } } }
            }
        }
    }

    @ViewBuilder private var creationActions: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: SGTheme.Space.small) { newDishButton; newVersionButton }
        } else {
            HStack(spacing: SGTheme.Space.small) { newDishButton; newVersionButton }
        }
    }

    private var newDishButton: some View {
        Button { newDish = true } label: {
            Label("New Dish", systemImage: "plus")
                .frame(maxWidth: .infinity, minHeight: SGTheme.Size.minimumTap)
        }
        .buttonStyle(.borderedProminent).accessibilityIdentifier("new-dish")
    }

    private var newVersionButton: some View {
        Button { choosingDish = true } label: {
            Label("New Version", systemImage: "arrow.triangle.branch")
                .frame(maxWidth: .infinity, minHeight: SGTheme.Size.minimumTap)
        }
        .buttonStyle(.bordered).disabled(eligibleDishes.isEmpty).accessibilityIdentifier("new-version")
    }

    @ViewBuilder private var filterControls: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: SGTheme.Space.small) { filterButton; clearFiltersButton }
        } else {
            HStack { filterButton; Spacer(); clearFiltersButton }
        }
    }

    private var filterButton: some View {
        Button { showingFilters = true } label: {
            Label(filters.isActive ? "Filters (\(filters.count))" : "Filters", systemImage: "line.3.horizontal.decrease")
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: SGTheme.Size.minimumTap)
        }
        .accessibilityIdentifier("ranking-filters")
        .accessibilityLabel(filters.isActive ? "Filters, \(filters.count) active selections" : "Filters, none active")
    }

    @ViewBuilder private var clearFiltersButton: some View {
        if filters.isActive {
            Button("Clear Filters") { filters = CookingFilters() }
                .frame(minHeight: SGTheme.Size.minimumTap)
                .accessibilityIdentifier("clear-filters")
        }
    }

    private var activeFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SGTheme.Space.small) {
                if let category = filters.category {
                    filterChip("Category: \(category.label)") { filters.category = nil }
                }
                ForEach(DietaryTag.allCases.filter { filters.dietary.contains($0) }) { tag in
                    filterChip("Dietary: \(tag.label)") { filters.dietary.remove(tag) }
                }
                ForEach(AllergyTag.allCases.filter { filters.allergies.contains($0) }) { tag in
                    filterChip("Allergy: \(tag.label)") { filters.allergies.remove(tag) }
                }
            }
        }
    }

    private func filterChip(_ title: String, remove: @escaping () -> Void) -> some View {
        Button(action: remove) {
            Label(title, systemImage: "xmark.circle.fill")
                .font(.subheadline)
                .padding(.horizontal, SGTheme.Space.small)
                .frame(minHeight: SGTheme.Size.minimumTap)
                .background(SGTheme.ColorToken.elevatedSurface, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove \(title) filter")
    }

    private var noResults: some View {
        ContentUnavailableView {
            Label(filters.isActive ? "No filter matches" : "No search results", systemImage: "magnifyingglass")
        } description: {
            if filters.isActive {
                Text(hasSearch ? "No ranked dishes match this search and these filters." : "No ranked dishes match these filters.")
            } else {
                Text("No dishes match ‘\(TagNormalization.display(searchText))’.")
            }
        } actions: {
            if hasSearch {
                Button("Clear Search") { searchText = "" }
                    .frame(minHeight: SGTheme.Size.minimumTap).accessibilityIdentifier("clear-search")
            }
            if filters.isActive {
                Button("Clear Filters") { filters = CookingFilters() }
                    .frame(minHeight: SGTheme.Size.minimumTap)
                    .accessibilityIdentifier("empty-clear-filters")
            }
        }
        .buttonStyle(.bordered)
    }
}
