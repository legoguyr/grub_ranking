import SwiftUI
import SwiftData
#if DEBUG
import UIKit
#endif

@main
struct Grub_RankedApp: App {
    private let storage: Result<ModelContainer, Error> = Result {
        var testURL: URL?
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        var token = ProcessInfo.processInfo.environment["GRUB_TEST_STORE"]
        if let index = arguments.firstIndex(of: "--ui-test-store"), arguments.indices.contains(index + 1) {
            token = arguments[index + 1]
        }
        if let token, let identifier = UUID(uuidString: token) {
            testURL = FileManager.default.temporaryDirectory.appendingPathComponent("ui-test-\(identifier.uuidString).store")
        }
        #endif
        return try AppPersistence.open(url: testURL)
    }

    var body: some Scene {
        WindowGroup {
            switch storage {
            case .success(let container):
                #if DEBUG
                if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--comparison-fixture"),
                   ProcessInfo.processInfo.arguments.indices.contains(index + 1) {
                    ComparisonReviewFixture(mode: ProcessInfo.processInfo.arguments[index + 1])
                        .modifier(DebugPresentationOverrides())
                } else {
                    ContentView().modelContainer(container).modifier(DebugPresentationOverrides())
                }
                #else
                ContentView().modelContainer(container)
                #endif
            case .failure(let error):
                ContentUnavailableView("Couldn't open local data", systemImage: "externaldrive.badge.exclamationmark",
                    description: Text("Your store has not been reset.\n\(error.localizedDescription)"))
            }
        }
    }
}

#if DEBUG
/// Deterministic UI-test fixture for the four photo/placeholder combinations.
private struct ComparisonReviewFixture: View {
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
            }
            .frame(width: 44, height: 44)
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
        let arguments = ProcessInfo.processInfo.arguments
        let scheme: ColorScheme? = arguments.contains("--test-light") ? .light :
            (arguments.contains("--test-dark") ? .dark : nil)
        if arguments.contains("--test-large-type") {
            content.environment(\.dynamicTypeSize, .accessibility2).preferredColorScheme(scheme)
        } else {
            content.preferredColorScheme(scheme)
        }
        #else
        content
        #endif
    }
}
