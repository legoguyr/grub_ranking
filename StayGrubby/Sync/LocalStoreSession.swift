import Foundation
import SwiftData

nonisolated enum LocalStoreScope: Equatable, Sendable {
    case guest
    case account(UUID)
    var accountID: UUID? { if case .account(let id) = self { id } else { nil } }
}
nonisolated struct LocalStoreLayout: Equatable, Sendable {
    var databaseURL: URL?
    var mediaRoot: URL?
    static func resolve(_ scope: LocalStoreScope, root: URL) -> Self {
        switch scope {
        case .guest: return Self(databaseURL: nil, mediaRoot: nil) // Keep the existing default database/files untouched.
        case .account(let id):
            let directory = root.appendingPathComponent("StayGrubbyAccounts", isDirectory: true)
                .appendingPathComponent(id.uuidString.lowercased(), isDirectory: true)
            return Self(databaseURL: directory.appendingPathComponent("cooking.store"), mediaRoot: directory)
        }
    }
}
@MainActor struct LocalStoreSession {
    let scope: LocalStoreScope
    let container: ModelContainer
    let mediaRoot: URL?

    static func open(_ scope: LocalStoreScope, root: URL? = nil) throws -> Self {
        let base = try root ?? FileManager.default.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
        let layout: LocalStoreLayout
        if scope == .guest, root != nil { layout = LocalStoreLayout(databaseURL: base.appendingPathComponent("guest.store"), mediaRoot: base) }
        else { layout = LocalStoreLayout.resolve(scope, root: base) }
        if let url = layout.databaseURL { try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true) }
        let container = try AppPersistence.open(url: layout.databaseURL)
        if let account = scope.accountID {
            let context = container.mainContext
            if let binding = try SyncJournal.binding(context) {
                guard binding.accountID == account else { throw SyncFoundationError.wrongAccount }
            } else {
                context.insert(SyncStoreBinding(accountID: account)); try context.save()
            }
        }
        return Self(scope: scope, container: container, mediaRoot: layout.mediaRoot)
    }
    /// A fresh account is deliberately blocked until restoration or verified-empty authorization.
    @discardableResult func prepare() throws -> RankingList { try CookingStore.prepare(context: container.mainContext) }
    func restore(_ graph: CookingGraph, revision: Int) throws {
        try CookingGraphHydration.apply(graph, revision: revision, context: container.mainContext)
        try prepare()
    }
    /// Phase 3C must call this only after the server confirms the account has no library.
    func initializeVerifiedEmptyAccount() throws {
        guard let binding = try SyncJournal.binding(container.mainContext), binding.accountID == scope.accountID,
              binding.restorationRequired,
              try container.mainContext.fetchCount(FetchDescriptor<RankingList>()) == 0 else { throw SyncFoundationError.invalidGraph }
        binding.restorationRequired = false
        do { try prepare() } catch { container.mainContext.rollback(); throw error }
    }
}

/// Account restoration is an explicit pre-presentation step. Guest launch retains
/// its existing location and bridge; there is no authentication or account toggle yet.
@MainActor enum LocalStoreStartup {
    static func openGuest(overrideURL: URL? = nil) throws -> ModelContainer {
        try AppPersistence.open(url: overrideURL)
    }
    static func openAccount(_ accountID: UUID, root: URL? = nil) throws -> LocalStoreSession {
        try LocalStoreSession.open(.account(accountID), root: root)
    }
}
