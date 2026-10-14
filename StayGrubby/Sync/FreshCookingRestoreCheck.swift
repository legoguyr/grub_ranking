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
        var photos: Int = 0
        var label: String { "Fresh restore verified · \(dishes) dishes / \(attempts) cooks / \(comparisons) comparisons / \(photos) \(photos == 1 ? "photo" : "photos")" }
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
    static func verifyPhotos(_ snapshot: AccountLibrarySnapshot, for account: ProvisionedAccount,
        transport: any CookingPhotoTransport) async throws -> Result {
        try snapshot.validate(for: account)
        let graph = snapshot.graph.canonicalized()
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("fresh-restore-check-\(UUID())")
        defer { try? FileManager.default.removeItem(at: scratch) }
        let store = try LocalStoreStartup.openAccount(account.accountID, root: scratch)
        try store.restore(graph, revision: snapshot.account.syncRevision)
        guard let root = store.mediaRoot else { throw SyncFoundationError.wrongAccount }
        let photos = try await CookingPhotoSync.restoreOnly(graph: graph, root: root, owner: account.accountID, transport: transport)
        try store.restore(graph, revision: snapshot.account.syncRevision)
        let repeated = try await CookingPhotoSync.restoreOnly(graph: graph, root: root, owner: account.accountID, transport: transport)
        guard repeated == photos, try CookingGraphExport.snapshot(context: store.container.mainContext).canonicalized() == graph,
              try SyncJournal.pending(store.container.mainContext).isEmpty,
              try SyncJournal.binding(store.container.mainContext)?.enabled == false else { throw SyncFoundationError.invalidGraph }
        return Result(dishes: graph.dishes.count, attempts: graph.attempts.count, comparisons: graph.comparisons.count,
            digest: SyncJournal.digest(try graph.encoded()), photos: photos)
    }
}
#endif
