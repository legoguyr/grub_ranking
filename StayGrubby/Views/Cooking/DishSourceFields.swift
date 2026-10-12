import SwiftUI

/// A thin presentation adapter: hidden legacy metadata stays in the value draft.
struct DishSourceFields: View {
    @Binding var source: DishSourceDraft
    var body: some View {
        switch SourceChoice(type: source.type) {
        case .myOwn:
            Text("Your own creation.").font(SGTheme.TypeRole.body).foregroundStyle(.secondary)
        case .online:
            TextField("URL", text: Binding(
                get: { source.type == .socialMedia ? source.socialURL : source.onlineURL },
                set: { if source.type == .socialMedia { source.socialURL = $0 } else { source.onlineURL = $0 } }))
                .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityIdentifier("source-online-url").sgField()
        case .cookbook:
            TextField("Cookbook name", text: $source.cookbookTitle)
                .accessibilityIdentifier("source-cookbook-title").sgField()
        case .restaurant:
            TextField("Restaurant name", text: $source.restaurantName)
                .accessibilityIdentifier("source-restaurant-name").sgField()
        case .friendFamily:
            TextField("Person / source name (optional)", text: $source.friendName).sgField()
        case .other:
            TextField("Source", text: $source.otherName).sgField()
        }
    }
}

struct DishSourceEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var source: DishSourceDraft?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                    Text("Where did this dish come from?").font(SGTheme.TypeRole.body).foregroundStyle(.secondary)
                    SGSelectionRow(title: "No source", selected: source == nil) { source = nil; dismiss() }
                    ForEach(CookingProductOptions.sources) { choice in
                        SGSelectionRow(title: choice.label, selected: source.map { SourceChoice(type: $0.type) == choice } ?? false) {
                            // Selecting Online again leaves a legacy Social Media record intact.
                            if source.map({ SourceChoice(type: $0.type) }) != choice {
                                source = DishSourceDraft(type: choice.storedType)
                            }
                            if choice == .myOwn { dismiss() }
                        }.accessibilityIdentifier("source-choice-\(choice.rawValue)")
                    }
                    if source != nil {
                        DishSourceFields(source: Binding(get: { source ?? DishSourceDraft() }, set: { source = $0 }))
                    }
                }.font(SGTheme.TypeRole.body).padding(SGTheme.Space.medium)
            }
            .background(SGTheme.ColorToken.background)
            .navigationTitle("Source").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("source-done") } }
        }.presentationDetents([.large]).presentationDragIndicator(.visible)
    }
}
