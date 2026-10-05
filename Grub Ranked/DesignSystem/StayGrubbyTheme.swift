import SwiftUI

enum SGTheme {
    enum ColorToken {
        static let accent = Color.accentColor
        static let background = Color(.systemBackground)
        static let groupedBackground = Color(.systemGroupedBackground)
        static let surface = Color(.secondarySystemBackground)
        static let elevatedSurface = Color(.tertiarySystemBackground)
        static let border = Color.primary.opacity(0.10)
        static let subdued = Color.secondary
    }

    enum Space {
        static let xSmall: CGFloat = 6
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
    }

    enum Radius {
        static let chip: CGFloat = 10
        static let card: CGFloat = 18
        static let hero: CGFloat = 24
    }

    enum Size {
        static let rowThumbnail: CGFloat = 64
        static let minimumTap: CGFloat = 44
        static let heroHeight: CGFloat = 300
    }

    enum Motion {
        static let quick = Animation.snappy(duration: 0.18)
        static let standard = Animation.snappy(duration: 0.28)
    }
}

extension View {
    func sgCard() -> some View {
        padding(SGTheme.Space.medium)
            .background(SGTheme.ColorToken.surface,
                        in: RoundedRectangle(cornerRadius: SGTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SGTheme.Radius.card, style: .continuous)
                    .stroke(SGTheme.ColorToken.border)
            }
    }
}
