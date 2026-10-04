import SwiftUI

/// Shared value-only fields: canceling a form never changes persistent objects.
struct CookingMetadataForm: View {
    @Binding var draft: CookingDraft
    var existingDish = false
    var editing = false
    @State private var newTag = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        Section("Dish") {
            TextField("Dish name", text: $draft.dishName)
                .accessibilityIdentifier("dish-name").disabled(existingDish && !editing)
            if editing { Text("Changing the dish name renames all its versions.").font(.footnote).foregroundStyle(.secondary) }
            Picker("Category", selection: $draft.category) {
                ForEach(DishCategory.allCases) { Text($0.label).tag($0) }
            }
        }
        Section("This cook") {
            TextField("Version title (optional)", text: $draft.versionTitle).accessibilityIdentifier("version-title")
                .focused($titleFocused).submitLabel(.done).onSubmit { titleFocused = false }
            if editing {
                Toggle("Cooked date known", isOn: Binding(get: { draft.cookedAt != nil }, set: { draft.cookedAt = $0 ? .now : nil }))
            }
            if draft.cookedAt != nil {
                DatePicker("Date cooked", selection: Binding(get: { draft.cookedAt ?? .now }, set: { draft.cookedAt = $0 }), displayedComponents: .date)
            }
            TextField("Notes (optional)", text: $draft.notes, axis: .vertical).lineLimit(3...6).accessibilityIdentifier("cook-notes")
        }
        Section("Dietary") {
            DisclosureGroup("Select dietary tags (\(draft.dietary.count))") {
                ForEach(DietaryTag.allCases) { tag in
                    Toggle(tag.label, isOn: Binding(get: { draft.dietary.contains(tag) }, set: { selected in
                        if selected { draft.dietary.insert(tag) } else { draft.dietary.remove(tag) }
                    }))
                }
            }
        }
        Section {
            DisclosureGroup("Select allergy tags (\(draft.allergy.count))") {
                ForEach(AllergyTag.allCases) { tag in
                    Toggle(tag.label, isOn: Binding(get: { draft.allergy.contains(tag) }, set: { selected in
                        if selected { draft.allergy.insert(tag) } else { draft.allergy.remove(tag) }
                    }))
                }
            }
        } header: { Text("Allergy") } footer: { Text("Your own labels, not verified allergy safety information.") }
        Section("Custom tags") {
            ForEach(draft.customTags, id: \.self) { tag in
                HStack {
                    Text(tag)
                    Spacer()
                    Button { draft.customTags.removeAll { $0 == tag } } label: { Image(systemName: "minus.circle") }
                        .accessibilityLabel("Remove tag \(tag)").buttonStyle(.borderless)
                }
            }
            HStack {
                TextField("Custom tag", text: $newTag).onSubmit(addTag).submitLabel(.done)
                Button("Add tag", action: addTag).disabled(TagNormalization.display(newTag).isEmpty).buttonStyle(.borderless)
            }
        }
    }
    private func addTag() {
        draft.customTags = TagNormalization.deduplicated(draft.customTags + [newTag]); newTag = ""
    }
}
