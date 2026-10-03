//
//  Grub_RankedApp.swift
//  Grub Ranked
//
//  Created by Guy Rettig on 10/1/26.
//

import SwiftUI
import SwiftData

@main
struct Grub_RankedApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self, // Retained so the starter store can migrate without dropping its schema.
            RankingList.self, RankedItem.self, Comparison.self,
        ])
        var modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        #if DEBUG
        // UI tests get an isolated disk store, retained across their relaunch check.
        // Never clear or seed the user's ranking history to make a test pass.
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--ui-test-store"), arguments.indices.contains(index + 1),
           let identifier = UUID(uuidString: arguments[index + 1]) {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("ui-test-\(identifier.uuidString).store")
            modelConfiguration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        }
        #endif

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
