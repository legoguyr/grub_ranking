import SwiftUI
import SwiftData
#if DEBUG
import UIKit
#endif

@main
struct StayGrubbyApp: App {
    @State private var accountSession = AccountSessionCoordinator()
    var body: some Scene {
        WindowGroup {
            AccountApplicationRoot().environment(accountSession).modifier(DebugPresentationOverrides())
        }
    }
}

#if DEBUG
/// Deterministic UI-test fixture for the four photo/placeholder combinations.
struct ComparisonReviewFixture: View {
    @State private var mode: String
    private let modes = ["11", "10", "01", "00"]

    init(mode: String) {
        _mode = State(initialValue: mode)
    }

    var body: some View {
        ComparisonView(
            newName: "An Exceptionally Long Roasted Vegetable Dish",
            existingName: "Northstar",
            newVersion: "Smoky Sunday version",
            existingVersion: "Version 2",
            newPreparedPhoto: mode.first == "1" ? Self.photo(.systemOrange) : nil,
            existingPreparedPhoto: mode.last == "1" ? Self.photo(.systemGreen) : nil,
            canUndo: false,
            onAnswer: { _ in },
            onUndo: {}
        )
        .overlay(alignment: .topTrailing) {
            Button {
                let index = modes.firstIndex(of: mode) ?? 0
                mode = modes[(index + 1) % modes.count]
            } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .frame(width: SGTheme.Size.minimumTap, height: SGTheme.Size.minimumTap)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 30)
            .padding(.trailing, 8)
            .accessibilityIdentifier("comparison-fixture-next")
            .accessibilityLabel("Next comparison fixture, current \(mode)")
        }
    }

    private static func photo(_ color: UIColor) -> PreparedCookingPhoto {
        let size = CGSize(width: 420, height: 840)
        let data = UIGraphicsImageRenderer(size: size).jpegData(withCompressionQuality: 0.8) { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.white.withAlphaComponent(0.45).setFill()
            context.fill(CGRect(x: 70, y: 280, width: 280, height: 280))
        }
        return PreparedCookingPhoto(displayData: data, thumbnailData: data,
                                    pixelWidth: Int(size.width), pixelHeight: Int(size.height))
    }
}
#endif

/// Deterministic appearance hooks for simulator inspection and UI tests only.
private struct DebugPresentationOverrides: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        #if DEBUG
        let review = DebugReviewConfiguration.current
        let scheme: ColorScheme? = review.light ? .light : (review.dark ? .dark : nil)
        if review.storeID != nil {
            // SwiftUI and UIKit review sizes use the same explicit test option.
            // UIKit's launch argument alone does not update SwiftUI on this runtime.
            content.environment(\.dynamicTypeSize, review.largeType ? .accessibility2 : .large)
                .preferredColorScheme(scheme).modifier(DebugMotionOverride())
        } else {
            // Normal launches inherit the real device setting without a size limit.
            content.modifier(DebugMotionOverride())
        }
        #else
        content
        #endif
    }
}

private struct DebugMotionOverride: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        #if DEBUG
        if DebugReviewConfiguration.current.reduceMotion {
            content.environment(\.sgReduceMotion, true)
        } else { content }
        #else
        content
        #endif
    }
}
