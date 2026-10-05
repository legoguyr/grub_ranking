import SwiftUI
import SwiftData

struct CookingRankingView: View {
    let list: RankingList
    @Query private var attempts: [CookingAttempt]
    @Query(sort: \Dish.name) private var dishes: [Dish]
    @State private var newDish = false
    @State private var choosingDish = false
    @State private var selectedDish: Dish?
    @State private var pendingDish: Dish?
    @State private var searchText = ""
    private var eligibleDishes: [Dish] { dishes.filter { dish in dish.attempts.contains { $0.rankedItem?.list?.id == list.id } } }
    private var rankedAttempts: [(rank: Int, attempt: CookingAttempt)] {
        list.orderedItems.enumerated().compactMap { index, item in
            guard let attempt = attempts.first(where: { $0.rankedItemID == item.id }) else { return nil }
            let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard search.isEmpty || attempt.displayName.localizedCaseInsensitiveContains(search) ||
                    attempt.category.label.localizedCaseInsensitiveContains(search) else { return nil }
            return (index + 1, attempt)
        }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: SGTheme.Space.small) {
                    Button { newDish = true } label: {
                        Label("New Dish", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent).accessibilityIdentifier("new-dish")
                    Button { choosingDish = true } label: {
                        Label("New Version", systemImage: "arrow.triangle.branch")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered).disabled(eligibleDishes.isEmpty).accessibilityIdentifier("new-version")
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            Section {
                if list.items.isEmpty {
                    ContentUnavailableView("Your cooking, ranked", systemImage: "fork.knife",
                                           description: Text("Add your first dish to begin."))
                }
                ForEach(rankedAttempts, id: \.attempt.id) { entry in
                    NavigationLink { AttemptDetailView(attempt: entry.attempt) } label: {
                        RankedDishRow(attempt: entry.attempt, rank: entry.rank)
                    }
                    .accessibilityIdentifier("cook-row-\(entry.attempt.rankedItemID)")
                    .accessibilityLabel("Rank \(entry.rank), \(entry.attempt.displayName), score \(entry.attempt.rankedItem?.score.formatted(.number.precision(.fractionLength(1))) ?? "unknown")")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(SGTheme.ColorToken.background)
        .navigationTitle("Rankings")
        .searchable(text: $searchText, prompt: "Search dishes")
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
}
