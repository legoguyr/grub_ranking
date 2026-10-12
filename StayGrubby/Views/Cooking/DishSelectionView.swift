import SwiftUI

struct DishSelectionView: View {
    let dishes: [Dish]
    let onSelect: (Dish) -> Void
    let onCancel: () -> Void
    @State private var search = ""
    private var matches: [Dish] { DishSelectionSearch.matches(dishes, query: search) }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: SGTheme.Space.small) {
                    if matches.isEmpty {
                        ContentUnavailableView {
                            Label("No matching dishes", systemImage: "magnifyingglass")
                                .accessibilityIdentifier("parent-dish-empty")
                        } description: {
                            Text("No dishes match ‘\(TagNormalization.display(search))’.")
                        }
                    }
                    ForEach(matches) { dish in
                        Button { onSelect(dish) } label: {
                            HStack(spacing: SGTheme.Space.small) {
                                DishPhoto(media: dish.attempts.sorted { $0.sequenceNumber > $1.sequenceNumber }.compactMap(\.primaryImage).first,
                                          thumbnail: true, name: dish.name)
                                    .frame(width: SGTheme.Size.versionThumbnail, height: SGTheme.Size.versionThumbnail)
                                    .clipShape(RoundedRectangle(cornerRadius: SGTheme.Radius.field))
                                VStack(alignment: .leading, spacing: SGTheme.Space.hairline) {
                                    Text(dish.name).font(SGTheme.TypeRole.headline).fixedSize(horizontal: false, vertical: true)
                                    Text("\(dish.attempts.count) versions").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }.frame(minHeight: SGTheme.Size.minimumTap).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("choose-dish-\(dish.name)")
                    }
                }.padding(SGTheme.Space.medium)
            }
            .safeAreaInset(edge: .top) {
                SGSearchField(placeholder: "Search dishes", text: $search, identifier: "parent-dish-search")
                    .padding(SGTheme.Space.medium).background(SGTheme.ColorToken.background)
            }
            .scrollDismissesKeyboard(.interactively).background(SGTheme.ColorToken.background)
            .navigationTitle("Choose a Dish").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) } }
        }
    }
}
