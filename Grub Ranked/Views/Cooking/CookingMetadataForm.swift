import SwiftUI

/// Value-only state: dismissing the enclosing editor never writes to saved objects.
struct CookingMetadataForm: View {
    @Binding var draft: CookingDraft
    var existingDish = false
    var editing = false
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var newTag = ""
    @State private var selection: CookingMetadataSelection?
    @State private var sourceEditor = false
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
            CookingPhotoEditor(draft: $draft)
            SGFormSection(title: "Dish") {
                if existingDish && !editing {
                    Text(draft.dishName).font(SGTheme.TypeRole.headline)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("inherited-dish-name")
                } else {
                    TextField("Dish name", text: $draft.dishName).font(SGTheme.TypeRole.headline)
                        .accessibilityIdentifier("dish-name").sgField()
                }
                if editing {
                    Text("The dish name and Source are shared by all versions.")
                        .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                }
                if existingDish && !editing {
                    Label(draft.source?.summary ?? "No source", systemImage: "text.book.closed")
                        .font(SGTheme.TypeRole.body).foregroundStyle(.secondary)
                    Text("Source is inherited from this dish.").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                } else {
                    selector("Source", value: draft.source?.summary ?? "Optional", symbol: "text.book.closed") { sourceEditor = true }
                        .accessibilityIdentifier("dish-source-type")
                }
            }
            SGFormSection(title: "This cook / version") {
                if textSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                        Text(CookingProductOptions.courseTitle).font(SGTheme.TypeRole.body)
                        coursePicker
                    }.sgField()
                } else {
                    HStack { Text(CookingProductOptions.courseTitle).font(SGTheme.TypeRole.body); Spacer(); coursePicker }.sgField()
                }
                TextField("Version title (optional)", text: $draft.versionTitle).accessibilityIdentifier("version-title")
                    .focused($titleFocused).submitLabel(.done).onSubmit { titleFocused = false }.sgField()
                if editing {
                    Toggle("Cooked date known", isOn: Binding(get: { draft.cookedAt != nil }, set: { draft.cookedAt = $0 ? .now : nil }))
                }
                if draft.cookedAt != nil {
                    if textSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                            Text("Date cooked").font(SGTheme.TypeRole.body)
                            cookedDate.labelsHidden().accessibilityLabel("Date cooked")
                        }
                    } else { cookedDate }
                }
                selector("Dietary", value: draft.dietary.isEmpty ? "Optional" : "\(draft.dietary.count) selected", symbol: "leaf") { selection = .dietary }
                selector("Contains", value: draft.contains.isEmpty ? "Optional" : "\(draft.contains.count) selected", symbol: "checklist") { selection = .contains }
                    .accessibilityIdentifier("cook-contains")
                if !draft.allergy.isEmpty {
                    VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                        Text("Legacy free-of labels: " + draft.allergy.map(\.label).sorted().joined(separator: ", "))
                            .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                        Text("Kept separately from Contains. These are user-entered claims.")
                            .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                        Button("Remove legacy free-of labels") { draft.allergy = [] }
                            .accessibilityIdentifier("clear-legacy-free-labels")
                    }
                }
            }
            SGFormSection(title: "More about this cook") {
                DisclosureGroup("Custom tags") {
                    ForEach(draft.customTags, id: \.self) { tag in
                        HStack {
                            Text(tag).font(SGTheme.TypeRole.body)
                            Spacer()
                            SGIconButton(title: "Remove tag \(tag)", symbol: "minus.circle") { draft.customTags.removeAll { $0 == tag } }
                        }
                    }
                    HStack {
                        TextField("Custom tag", text: $newTag).onSubmit(addTag).submitLabel(.done).sgField()
                        Button("Add tag", action: addTag).disabled(TagNormalization.display(newTag).isEmpty)
                            .buttonStyle(SGButtonStyle())
                    }
                }.font(SGTheme.TypeRole.body)
                TextField("Notes (optional)", text: $draft.notes, axis: .vertical)
                    .lineLimit(2...6).accessibilityIdentifier("cook-notes").sgField()
            }
        }
        .sheet(isPresented: $sourceEditor) { DishSourceEditor(source: $draft.source) }
        .sheet(item: $selection) { selection in
            switch selection {
            case .dietary:
                CookingFilterView(filters: Binding(
                    get: { CookingFilters(dietary: draft.dietary) },
                    set: { draft.dietary = $0.dietary }), group: .dietary)
            case .contains:
                ContainsSelector(selection: $draft.contains)
            }
        }
    }
    private var coursePicker: some View {
        Picker(CookingProductOptions.courseTitle, selection: $draft.category) {
            ForEach(CookingProductOptions.courses) { Text($0.label).tag($0) }
        }.pickerStyle(.menu).labelsHidden().tint(SGTheme.ColorToken.primaryText)
    }
    private var cookedDate: some View {
        DatePicker("Date cooked", selection: Binding(get: { draft.cookedAt ?? .now }, set: { draft.cookedAt = $0 }), displayedComponents: .date)
            .font(SGTheme.TypeRole.body).frame(minHeight: SGTheme.Size.minimumTap)
    }
    private func selector(_ title: String, value: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if textSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                        Label(title, systemImage: symbol)
                        HStack { Text(value).foregroundStyle(.secondary); Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary) }
                    }
                } else {
                    HStack(spacing: SGTheme.Space.small) {
                        Image(systemName: symbol).foregroundStyle(.secondary)
                        Text(title)
                        Spacer()
                        Text(value).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                }
            }.font(SGTheme.TypeRole.body).frame(minHeight: SGTheme.Size.minimumTap).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
    private func addTag() { draft.customTags = TagNormalization.deduplicated(draft.customTags + [newTag]); newTag = "" }
}

struct SGFormSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            Text(title).font(SGTheme.TypeRole.secondary.weight(.semibold)).foregroundStyle(.secondary)
            content
        }.font(SGTheme.TypeRole.body).sgCard()
    }
}

struct CookingFormScroll: View {
    @Binding var draft: CookingDraft
    var existingDish = false
    var editing = false
    var body: some View {
        ScrollView {
            CookingMetadataForm(draft: $draft, existingDish: existingDish, editing: editing)
                .frame(maxWidth: SGTheme.Size.contentMaximum)
                .padding(SGTheme.Space.medium).frame(maxWidth: .infinity)
        }.scrollDismissesKeyboard(.interactively).background(SGTheme.ColorToken.background)
    }
}

private enum CookingMetadataSelection: String, Identifiable {
    case dietary, contains
    var id: String { rawValue }
}
