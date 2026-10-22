import SwiftUI

/// Shared presentation; no feature state, authorization or ranking decisions.
struct SGEyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(SGTheme.TypeRole.eyebrow).tracking(1.6)
            .foregroundStyle(SGTheme.ColorToken.accent).fixedSize(horizontal: false, vertical: true)
    }
}
struct SGPageIntro: View {
    let title: String
    let subtitle: String
    var eyebrow: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            if let eyebrow { SGEyebrow(text: eyebrow) }
            Text(title).font(SGTheme.TypeRole.page).tracking(-0.8).accessibilityAddTraits(.isHeader)
            Text(subtitle).font(SGTheme.TypeRole.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, SGTheme.Space.medium)
    }
}
struct SGEmptyState: View {
    let title: String
    let message: String
    var symbol = "sparkle"
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
            Image(systemName: symbol).font(.title).foregroundStyle(SGTheme.ColorToken.accent).accessibilityHidden(true)
            Text(title).font(SGTheme.TypeRole.title).accessibilityAddTraits(.isHeader)
            Text(message).font(SGTheme.TypeRole.reading).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, SGTheme.Space.xLarge)
    }
}
struct SGDestinationLabel: View {
    let title: String
    let subtitle: String
    let symbol: String
    var body: some View {
        HStack(spacing: SGTheme.Space.medium) {
            Image(systemName: symbol).font(.title3).foregroundStyle(SGTheme.ColorToken.accent).frame(width: 28).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(SGTheme.TypeRole.headline).foregroundStyle(SGTheme.ColorToken.primaryText)
                Text(subtitle).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary).accessibilityHidden(true)
        }.padding(.vertical, SGTheme.Space.small).frame(minHeight: SGTheme.Size.minimumTap).contentShape(Rectangle())
    }
}
struct SGListPresentation: ViewModifier {
    func body(content: Content) -> some View {
        content.listStyle(.plain).scrollContentBackground(.hidden)
            .background(SGTheme.ColorToken.background)
            .environment(\.defaultMinListRowHeight, SGTheme.Size.minimumTap)
    }
}
extension View {
    func sgEditorialList() -> some View { modifier(SGListPresentation()) }
}
