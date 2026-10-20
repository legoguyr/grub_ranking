import SwiftUI
import SwiftData

struct CuisinePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var dishes: [Dish]
    @Binding var selection: Cuisine?
    var allowsCreation = true
    @State private var search = ""

    private var saved: [Cuisine] { dishes.compactMap(\.cuisine) }
    private var options: [Cuisine] {
        let all = CuisineCatalog.options(saved: saved + [selection].compactMap { $0 })
        let key = CuisineCatalog.key(search)
        if key.isEmpty { return all }
        let exact = CuisineCatalog.existing(search, saved: saved)
        return all.filter { CuisineCatalog.key($0.label).contains(key) || $0.id == exact?.id }
    }
    var body: some View {
        NavigationStack {
            List {
                Button(allowsCreation ? "No cuisine" : "All cuisines") { choose(nil) }
                    .accessibilityIdentifier("cuisine-clear")
                Section(search.isEmpty ? "Cuisines" : "Results") {
                    ForEach(options) { cuisine in
                        Button { choose(cuisine) } label: {
                            HStack {
                                Text(cuisine.label).foregroundStyle(SGTheme.ColorToken.primaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                if selection?.id == cuisine.id { Image(systemName: "checkmark").accessibilityLabel("Selected") }
                            }.frame(minHeight: SGTheme.Size.minimumTap)
                        }.accessibilityIdentifier("cuisine-option-\(cuisine.id)")
                    }
                }
                if allowsCreation, CuisineCatalog.existing(search, saved: saved) == nil,
                   let custom = CuisineCatalog.resolve(search, saved: saved) {
                    Button { choose(custom) } label: { Label("Add “\(custom.label)”", systemImage: "plus") }
                        .accessibilityIdentifier("cuisine-add")
                }
                if CuisineCatalog.display(search).unicodeScalars.count > CuisineCatalog.maximumLabelLength {
                    Text("Use 80 characters or fewer.").foregroundStyle(.secondary)
                }
            }
            .searchable(text: $search, prompt: "Search cuisines")
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Cuisine").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
    private func choose(_ cuisine: Cuisine?) { selection = cuisine; dismiss() }
}
