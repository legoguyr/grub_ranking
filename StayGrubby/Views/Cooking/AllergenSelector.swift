import SwiftUI

/// The same presence vocabulary serves metadata entry and discovery exclusion.
struct SGAllergenChoices: View {
    @Binding var selection: Set<Allergen>
    let identifierPrefix: String
    var body: some View {
        ForEach(CookingProductOptions.allergens) { allergen in
            SGSelectionRow(title: allergen.label, selected: selection.contains(allergen)) {
                if selection.contains(allergen) { selection.remove(allergen) }
                else { selection.insert(allergen) }
            }.accessibilityIdentifier("\(identifierPrefix)-\(allergen.rawValue)")
        }
    }
}

struct ContainsSelector: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: Set<Allergen>
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SGTheme.Space.xSmall) {
                    SGAllergenChoices(selection: $selection, identifierPrefix: "contains")
                    Text("Mark ingredients this cook contains. These are your own labels, not verified allergy information.")
                        .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.padding(SGTheme.Space.medium)
            }
            .background(SGTheme.ColorToken.background)
            .navigationTitle("Contains").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }.accessibilityIdentifier("contains-done")
            } }
        }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
}
