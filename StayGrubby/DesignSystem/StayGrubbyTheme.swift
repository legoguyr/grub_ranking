import SwiftUI
import UIKit

/// The visual vocabulary lives here; feature views retain product state and routing.
enum SGTheme {
    /// Fixed export/identity colors. The supplied official PNG's dominant red
    /// takes precedence over the conceptual mockup's approximate red.
    enum Brand {
        static let cream = Color(red: 250 / 255, green: 243 / 255, blue: 236 / 255)
        static let red = Color(red: 241 / 255, green: 6 / 255, blue: 7 / 255)
        static let charcoal = Color(red: 31 / 255, green: 31 / 255, blue: 31 / 255)
    }
    enum ColorToken {
        // Accessible red variants for product controls; exports keep Brand.red.
        static let accent = adaptive(light: 0xCB1015, dark: 0xFF6B63)
        static let buttonAccent = Color(red: 203 / 255, green: 16 / 255, blue: 21 / 255)
        static let background = adaptive(light: 0xFAF3EC, dark: 0x171615)
        static let groupedBackground = background
        static let surface = adaptive(light: 0xFFFCF8, dark: 0x22201E)
        static let elevatedSurface = adaptive(light: 0xEFE5DA, dark: 0x302C28)
        static let primaryText = Color.primary
        static let subdued = Color.secondary
        static let destructive = adaptive(light: 0xB72420, dark: 0xFF8C80)
        static let tertiaryText = Color.secondary.opacity(0.8)
        static let photoScrim = Color.black.opacity(0.65)
        static let border = Color.primary.opacity(0.09)
        static let placeholderStart = Color.secondary.opacity(0.13)
        static let placeholderEnd = Color.secondary.opacity(0.05)
        static let onAccent = Color.white
        static let selected = accent.opacity(0.13)
        static let focusBackground = adaptive(light: 0xF1E7DC, dark: 0x100F0E)
        fileprivate static func adaptive(light: UInt32, dark: UInt32) -> Color {
            Color(UIColor { traits in
                let hex = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                               green: CGFloat((hex >> 8) & 255) / 255,
                               blue: CGFloat(hex & 255) / 255, alpha: 1)
            })
        }
    }
    /// In-app presentation only. Exported cards deliberately keep Brand.red.
    enum ScoreColor {
        static let orangeMinimum = 5.0
        static let goldMinimum = 7.6
        enum Band: Equatable { case gold, orange, coral }
        static let gold = ColorToken.adaptive(light: 0x80600F, dark: 0xEAC86B)
        static let orange = ColorToken.adaptive(light: 0xA74910, dark: 0xF2A669)
        static let coral = ColorToken.adaptive(light: 0xAA4243, dark: 0xF19D96)

        // Classify the already-formatted score so its visible decimal and color agree.
        // This neither rounds nor writes the underlying numerical ranking score.
        static func band(forDisplayedScore text: String) -> Band? {
            guard let score = Double(text), score.isFinite else { return nil }
            if score >= goldMinimum { return .gold }
            if score >= orangeMinimum { return .orange }
            return .coral
        }
        static func color(forDisplayedScore text: String) -> Color {
            switch band(forDisplayedScore: text) {
            case .gold: gold
            case .orange: orange
            case .coral: coral
            case nil: Color.secondary
            }
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
        static let card: CGFloat = 16
        static let hero: CGFloat = 18
    }
    enum Size {
        static let rowThumbnail: CGFloat = 86
        static let versionThumbnail: CGFloat = 44
        static let rankWidth: CGFloat = 30
        static let minimumTap: CGFloat = 44
        static let heroHeight: CGFloat = 260
        static let placeholderHeight: CGFloat = 96
        static let editorPhotoHeight: CGFloat = 190
        static let comparisonMaximum: CGFloat = 210
        static let comparisonLandscape: CGFloat = 140
        static let comparisonSeparator: CGFloat = 28
        static let comparisonLabelHeight: CGFloat = 62
        static let contentMaximum: CGFloat = 680
        static let sharingContentMaximum: CGFloat = 440
        static let sharingPreviewMaximumHeight: CGFloat = 320
        static let tagColumnWidth: CGFloat = 120
        static let border: CGFloat = 1
        static let selectedBorder: CGFloat = 3
        static let placeholderIcon: CGFloat = 42
        static let thumbnailIcon: CGFloat = 22
    }
    enum TypeRole {
        static let identity = Font.system(.title3, design: .default, weight: .black)
        static let title = Font.system(.title2, design: .default, weight: .bold)
        static let headline = Font.headline.weight(.semibold)
        static let hero = Font.system(.largeTitle, design: .default, weight: .black)
        static let page = Font.system(.largeTitle, design: .default, weight: .bold)
        static let dish = Font.system(.title3, design: .default, weight: .bold)
        static let eyebrow = Font.caption.weight(.bold)
        static let reading = Font.body
        static let rank = Font.system(.title2, design: .serif, weight: .semibold).monospacedDigit()
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
    var compact = false
    var prominentColor: Color? = nil
    @Environment(\.isEnabled) private var enabled
    @Environment(\.sgReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SGTheme.TypeRole.headline)
            .padding(.horizontal, compact ? SGTheme.Space.xSmall : SGTheme.Space.medium)
            .frame(minHeight: SGTheme.Size.minimumTap)
            .foregroundStyle(prominent ? SGTheme.ColorToken.onAccent : SGTheme.ColorToken.primaryText)
            .background(prominent ? (prominentColor ?? SGTheme.ColorToken.buttonAccent) : SGTheme.ColorToken.elevatedSurface,
                        in: RoundedRectangle(cornerRadius: SGTheme.Radius.field))
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? SGTheme.Motion.pressedScale : 1)
            .animation(reduceMotion ? nil : SGTheme.Motion.quick, value: configuration.isPressed)
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
