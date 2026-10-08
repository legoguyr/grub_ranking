import SwiftUI

/// Page-aware identity and controls. Search state remains owned by the feature.
struct StayGrubbyHeader: View {
    let page: String
    var onCreate: (() -> Void)?
    var onSearch: (() -> Void)?
    @Binding var searchText: String
    @Binding var searching: Bool
    @FocusState private var searchFocused: Bool
    @Environment(\.sgReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if searching {
                HStack(spacing: SGTheme.Space.xSmall) {
                    HStack(spacing: SGTheme.Space.xSmall) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Search dishes, versions, tags", text: $searchText)
                            .font(SGTheme.TypeRole.body)
                            .focused($searchFocused).submitLabel(.search)
                            .onSubmit { searchFocused = false }
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("ranking-search-field")
                        if !searchText.isEmpty {
                            SGIconButton(title: "Clear Search", symbol: "xmark.circle.fill") { searchText = "" }
                                .accessibilityIdentifier("header-clear-search")
                        }
                    }.sgField()
                    Button("Done") { animate { searching = false }; searchFocused = false }
                        .font(SGTheme.TypeRole.body.weight(.semibold))
                        .frame(minHeight: SGTheme.Size.minimumTap)
                        .accessibilityIdentifier("search-done")
                }
                .onAppear { searchFocused = true }
                .transition(.opacity)
            } else {
                ZStack {
                    VStack(spacing: SGTheme.Space.hairline) {
                        Text("StayGrubby").font(SGTheme.TypeRole.identity)
                        Text(page).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, SGTheme.Size.minimumTap + SGTheme.Space.small)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("staygrubby-header-\(page.lowercased())")
                    HStack {
                        if let onCreate {
                            SGIconButton(title: "Create a cook", symbol: "plus", emphasized: true, action: onCreate)
                                .accessibilityIdentifier("creation-toggle")
                        }
                        Spacer()
                        if let onSearch {
                            SGIconButton(title: "Search rankings", symbol: searchText.isEmpty ? "magnifyingglass" : "magnifyingglass.circle.fill") {
                                onSearch(); animate { searching = true }
                            }.accessibilityIdentifier("ranking-search")
                        }
                    }
                }.frame(minHeight: SGTheme.Size.minimumTap)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, SGTheme.Space.medium).padding(.vertical, SGTheme.Space.xSmall)
        .background(SGTheme.ColorToken.background)
    }
    private func animate(_ action: () -> Void) {
        withAnimation(reduceMotion ? nil : SGTheme.Motion.quick, action)
    }
}

struct SGIconButton: View {
    let title: String
    let symbol: String
    var emphasized = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(SGTheme.TypeRole.headline)
                .frame(width: SGTheme.Size.minimumTap, height: SGTheme.Size.minimumTap)
                .foregroundStyle(emphasized ? SGTheme.ColorToken.onAccent : SGTheme.ColorToken.primaryText)
                .background(emphasized ? SGTheme.ColorToken.accent : SGTheme.ColorToken.elevatedSurface, in: Circle())
        }.buttonStyle(.plain).accessibilityLabel(title)
    }
}

struct SGCreationChoices: View {
    let canCreateVersion: Bool
    let newDish: () -> Void
    let newVersion: () -> Void
    var body: some View {
        VStack(spacing: SGTheme.Space.xSmall) {
            choice("New Dish", subtitle: "Something new for your ranking", symbol: "fork.knife", action: newDish)
                .accessibilityIdentifier("new-dish")
            choice("New Version", subtitle: "Another cook of a saved dish", symbol: "arrow.triangle.branch", action: newVersion)
                .disabled(!canCreateVersion).accessibilityIdentifier("new-version")
        }.sgCard().padding(.horizontal, SGTheme.Space.medium)
    }
    private func choice(_ title: String, subtitle: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: SGTheme.Space.small) {
                Image(systemName: symbol).foregroundStyle(SGTheme.ColorToken.accent)
                VStack(alignment: .leading, spacing: SGTheme.Space.hairline) {
                    Text(title).font(SGTheme.TypeRole.headline)
                    Text(subtitle).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right").foregroundStyle(.secondary)
            }.frame(minHeight: SGTheme.Size.minimumTap).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

struct SGSelectionRow: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: SGTheme.Space.small) {
                Text(title).font(SGTheme.TypeRole.body)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? SGTheme.ColorToken.accent : .secondary)
            }
            .padding(.horizontal, SGTheme.Space.medium)
            .frame(minHeight: SGTheme.Size.minimumTap)
            .padding(.vertical, SGTheme.Space.xSmall)
            .background(selected ? SGTheme.ColorToken.selected : SGTheme.ColorToken.surface,
                        in: RoundedRectangle(cornerRadius: SGTheme.Radius.field))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityLabel(title)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
