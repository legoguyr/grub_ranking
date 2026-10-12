import SwiftUI
import UIKit

/// The visual vocabulary lives here; feature views retain product state and routing.
enum SGTheme {
    enum ColorToken {
        static let accent = Color.accentColor
        static let background = adaptive(light: 0xF6F5F0, dark: 0x111514)
        static let groupedBackground = background
        static let surface = adaptive(light: 0xFFFFFF, dark: 0x1C2220)
        static let elevatedSurface = adaptive(light: 0xEBEDE7, dark: 0x29312D)
        static let primaryText = Color.primary
        static let subdued = Color.secondary
        static let destructive = Color.red
        static let border = Color.primary.opacity(0.09)
        static let placeholderStart = Color.secondary.opacity(0.13)
        static let placeholderEnd = Color.secondary.opacity(0.05)
        static let onAccent = Color.white
        static let selected = accent.opacity(0.13)
        static let focusBackground = adaptive(light: 0xE7EAE3, dark: 0x0B0F0D)
        private static func adaptive(light: UInt32, dark: UInt32) -> Color {
            Color(UIColor { traits in
                let hex = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                               green: CGFloat((hex >> 8) & 255) / 255,
                               blue: CGFloat(hex & 255) / 255, alpha: 1)
            })
        }
    }
    enum Space {
        static let hairline: CGFloat = 3
        static let xSmall: CGFloat = 6
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
    }
    enum Radius {
        static let chip: CGFloat = 10
        static let field: CGFloat = 12
        static let card: CGFloat = 18
        static let hero: CGFloat = 24
    }
    enum Size {
        static let rowThumbnail: CGFloat = 68
        static let versionThumbnail: CGFloat = 44
        static let rankWidth: CGFloat = 22
        static let minimumTap: CGFloat = 44
        static let heroHeight: CGFloat = 260
        static let placeholderHeight: CGFloat = 96
        static let editorPhotoHeight: CGFloat = 190
        static let comparisonMaximum: CGFloat = 210
        static let comparisonLandscape: CGFloat = 140
        static let comparisonSeparator: CGFloat = 28
        static let comparisonLabelHeight: CGFloat = 62
        static let contentMaximum: CGFloat = 680
        static let tagColumnWidth: CGFloat = 120
        static let border: CGFloat = 1
        static let selectedBorder: CGFloat = 3
        static let placeholderIcon: CGFloat = 42
        static let thumbnailIcon: CGFloat = 22
    }
    enum TypeRole {
        static let identity = Font.system(.title3, design: .rounded, weight: .heavy)
        static let title = Font.system(.title2, design: .rounded, weight: .bold)
        static let headline = Font.headline.weight(.semibold)
        static let body = Font.subheadline
        static let secondary = Font.caption
        static let score = Font.system(.title3, design: .rounded, weight: .bold).monospacedDigit()
    }
    enum Motion {
        static let quick = Animation.snappy(duration: 0.18)
        static let standard = Animation.snappy(duration: 0.28)
        static let selectionDelay: Duration = .milliseconds(120)
        static let pressedScale: CGFloat = 0.98
    }
}

struct SGButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.sgReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SGTheme.TypeRole.headline)
            .padding(.horizontal, SGTheme.Space.medium)
            .frame(minHeight: SGTheme.Size.minimumTap)
            .foregroundStyle(prominent ? SGTheme.ColorToken.onAccent : SGTheme.ColorToken.primaryText)
            .background(prominent ? SGTheme.ColorToken.accent : SGTheme.ColorToken.elevatedSurface,
                        in: RoundedRectangle(cornerRadius: SGTheme.Radius.field))
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? SGTheme.Motion.pressedScale : 1)
    }
}

extension View {
    func sgCard() -> some View {
        padding(SGTheme.Space.medium)
            .background(SGTheme.ColorToken.surface,
                        in: RoundedRectangle(cornerRadius: SGTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SGTheme.Radius.card, style: .continuous)
                    .stroke(SGTheme.ColorToken.border, lineWidth: SGTheme.Size.border)
            }
    }
    func sgField() -> some View {
        padding(SGTheme.Space.small)
            .frame(minHeight: SGTheme.Size.minimumTap)
            .background(SGTheme.ColorToken.elevatedSurface,
                        in: RoundedRectangle(cornerRadius: SGTheme.Radius.field))
    }
}

private struct SGReduceMotionOverride: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Honors the device preference; DEBUG review can also request reduced motion.
    var sgReduceMotion: Bool {
        get { accessibilityReduceMotion || self[SGReduceMotionOverride.self] }
        set { self[SGReduceMotionOverride.self] = newValue }
    }
}
