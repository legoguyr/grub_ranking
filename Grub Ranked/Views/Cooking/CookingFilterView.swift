import SwiftUI

struct CookingFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filters: CookingFilters

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Category", selection: $filters.category) {
                        Text("All categories").tag(DishCategory?.none)
                        ForEach(DishCategory.allCases) { category in
                            Text(category.label).tag(Optional(category))
                        }
                    }
                    .accessibilityIdentifier("filter-category")
                } header: { Text("Category / Meal Type") }
                Section {
                    ForEach(DietaryTag.allCases) { tag in
                        Toggle(tag.label, isOn: Binding(
                            get: { filters.dietary.contains(tag) },
                            set: { selected in
                                if selected { filters.dietary.insert(tag) } else { filters.dietary.remove(tag) }
                            }))
                        .accessibilityIdentifier("filter-dietary-\(tag.rawValue)")
                    }
                } header: { Text("Dietary") } footer: {
                    Text("Matches any selected Dietary tag.")
                }
                Section {
                    ForEach(AllergyTag.allCases) { tag in
                        Toggle(tag.label, isOn: Binding(
                            get: { filters.allergies.contains(tag) },
                            set: { selected in
                                if selected { filters.allergies.insert(tag) } else { filters.allergies.remove(tag) }
                            }))
                        .accessibilityIdentifier("filter-allergy-\(tag.rawValue)")
                    }
                } header: { Text("Allergies") } footer: {
                    Text("Matches any selected Allergy tag. These are your own labels, not verified safety information.")
                }
                Section {
                    Button("Clear Filters") { filters = CookingFilters() }
                        .disabled(!filters.isActive).accessibilityIdentifier("sheet-clear-filters")
                } footer: {
                    Text("Category, Dietary, Allergies, and search must all match. Results keep their global ranking order and scores.")
                }
            }
            .navigationTitle("Filters").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("filters-done")
                }
            }
        }
    }
}
