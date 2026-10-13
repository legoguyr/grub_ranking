#if DEBUG
import Foundation
import SwiftData

/// Explicit, authenticated read-only verification. Scratch data never mounts or uploads.
@MainActor enum FreshCookingRestoreCheck {
    struct Result: Equatable {
        let dishes: Int
        let attempts: Int
        let comparisons: Int
        let digest: String
        var label: String { "Fresh restore verified · \(dishes) dishes / \(attempts) cooks / \(comparisons) comparisons" }
    }
    static func verify(_ snapshot: AccountLibrarySnapshot, for account: ProvisionedAccount) throws -> Result {
        try snapshot.validate(for: account)
        let graph = snapshot.graph.canonicalized()
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("fresh-restore-check-\(UUID())")
        defer { try? FileManager.default.removeItem(at: scratch) }
        let store = try LocalStoreStartup.openAccount(account.accountID, root: scratch)
        try store.restore(graph, revision: snapshot.account.syncRevision)
        try store.restore(graph, revision: snapshot.account.syncRevision)
        guard try CookingGraphExport.snapshot(context: store.container.mainContext).canonicalized() == graph,
              try SyncJournal.pending(store.container.mainContext).isEmpty,
              try SyncJournal.binding(store.container.mainContext)?.enabled == false
        else { throw SyncFoundationError.invalidGraph }
        return Result(dishes: graph.dishes.count, attempts: graph.attempts.count, comparisons: graph.comparisons.count,
            digest: SyncJournal.digest(try graph.encoded()))
    }
}
#endif
