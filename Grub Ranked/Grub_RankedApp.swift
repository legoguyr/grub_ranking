import SwiftUI
import SwiftData

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
            case .success(let container): ContentView().modelContainer(container)
            case .failure(let error):
                ContentUnavailableView("Couldn't open local data", systemImage: "externaldrive.badge.exclamationmark",
                    description: Text("Your store has not been reset.\n\(error.localizedDescription)"))
            }
        }
    }
}
