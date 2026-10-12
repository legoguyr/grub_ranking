#if DEBUG
import Foundation

/// Review presentation and media are permitted only for an explicit isolated store.
/// This never writes defaults or changes the device's accessibility preferences.
nonisolated struct DebugReviewConfiguration {
    static let current = Self(arguments: ProcessInfo.processInfo.arguments,
                              environment: ProcessInfo.processInfo.environment)
    let storeID: UUID?
    let light: Bool
    let dark: Bool
    let reduceMotion: Bool
    let largeType: Bool
    let discoveryFixture: Bool
    let comparisonMode: String?

    init(arguments: [String], environment: [String: String] = [:]) {
        var token = environment["GRUB_TEST_STORE"]
        if let index = arguments.firstIndex(of: "--ui-test-store") {
            token = arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
        }
        storeID = token.flatMap(UUID.init(uuidString:))
        let isolated = storeID != nil
        light = isolated && arguments.contains("--test-light")
        dark = isolated && arguments.contains("--test-dark")
        reduceMotion = isolated && arguments.contains("--test-reduce-motion")
        largeType = isolated && arguments.contains("--test-large-type")
        discoveryFixture = isolated && arguments.contains("--discovery-fixture")
        if isolated, let index = arguments.firstIndex(of: "--comparison-fixture"),
           arguments.indices.contains(index + 1), ["11", "10", "01", "00"].contains(arguments[index + 1]) {
            comparisonMode = arguments[index + 1]
        } else { comparisonMode = nil }
    }

    func storeURL(in temporaryDirectory: URL) -> URL? {
        storeID.map { temporaryDirectory.appendingPathComponent("ui-test-\($0.uuidString).store") }
    }

    func mediaRoot(in temporaryDirectory: URL) -> URL? {
        storeID.map { temporaryDirectory.appendingPathComponent("ui-test-\($0.uuidString)-media", isDirectory: true) }
    }
}
#endif
