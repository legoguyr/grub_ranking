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
    private var eligibleDishes: [Dish] { dishes.filter { dish in dish.attempts.contains { $0.rankedItem?.list?.id == list.id } } }

    var body: some View {
        List {
            Section {
                Button("New Dish", systemImage: "plus") { newDish = true }.accessibilityIdentifier("new-dish")
                Button("New Version", systemImage: "arrow.triangle.branch") { choosingDish = true }
                    .disabled(eligibleDishes.isEmpty).accessibilityIdentifier("new-version")
            }
            Section("All cooks · global ranking") {
                if list.items.isEmpty {
                    Text("Log your first dish to start ranking what you cook.").foregroundStyle(.secondary)
                }
                ForEach(Array(list.orderedItems.enumerated()), id: \.element.id) { index, item in
                    if let attempt = attempts.first(where: { $0.rankedItemID == item.id }) {
                        NavigationLink { AttemptDetailView(attempt: attempt) } label: {
                            HStack {
                                Text("\(index + 1)").monospacedDigit().foregroundStyle(.secondary).frame(minWidth: 25)
                                VStack(alignment: .leading) {
                                    Text(attempt.dish?.name ?? item.name).font(.headline)
                                    Text(attempt.versionLabel).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(item.score, format: .number.precision(.fractionLength(1))).font(.headline).monospacedDigit()
                            }.padding(.vertical, 4)
                        }.accessibilityIdentifier("cook-row-\(item.id)")
                            .accessibilityLabel("Rank \(index + 1), \(attempt.displayName), score \(item.score.formatted(.number.precision(.fractionLength(1))))")
                    } else {
                        Text(item.name)
                    }
                }
            }
        }
        .navigationTitle("My Cooking")
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
