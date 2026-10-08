import SwiftUI

nonisolated enum CookingFilterGroup: String, Identifiable {
    case course, dietary, avoid
    var id: String { rawValue }
    var title: String {
        switch self {
        case .course: CookingProductOptions.courseTitle
        case .dietary: "Dietary"
        case .avoid: "Avoid"
        }
    }
}

struct CookingFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filters: CookingFilters
    let group: CookingFilterGroup

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SGTheme.Space.xSmall) {
                    switch group {
                    case .course:
                        SGSelectionRow(title: "All courses", selected: filters.category == nil) { filters.category = nil }
                        ForEach(CookingProductOptions.courses) { course in
                            SGSelectionRow(title: course.label, selected: filters.category == course) {
                                filters.category = filters.category == course ? nil : course
                            }.accessibilityIdentifier("filter-course-\(course.rawValue)")
                        }
                    case .dietary:
                        ForEach(CookingProductOptions.dietary) { tag in
                            SGSelectionRow(title: tag.label, selected: filters.dietary.contains(tag)) {
                                if filters.dietary.contains(tag) { filters.dietary.remove(tag) }
                                else { filters.dietary.insert(tag) }
                            }.accessibilityIdentifier("filter-dietary-\(tag.rawValue)")
                        }
                    case .avoid:
                        SGAllergenChoices(selection: $filters.avoidedAllergens, identifierPrefix: "filter-avoid")
                        Button("Clear Avoid") { filters.avoidedAllergens = [] }
                            .buttonStyle(SGButtonStyle()).accessibilityIdentifier("clear-avoid")
                    }
                    if group == .dietary {
                        Text("Matches any selected \(group.title.lowercased()) label. Groups and search must all match.")
                            .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, SGTheme.Space.small)
                    }
                    if group == .avoid {
                        Text(CookingProductOptions.allergenSafetyText).accessibilityIdentifier("allergen-safety")
                            .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                    }
                }.padding(SGTheme.Space.medium)
            }
            .background(SGTheme.ColorToken.background)
            .navigationTitle(group.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("filters-done")
                }
            }
        }
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
}
