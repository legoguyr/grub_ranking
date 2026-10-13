import Foundation
import SwiftData
import Observation
import SwiftUI

nonisolated struct AccountLibrarySnapshot: Codable, Sendable {
    let account: ProvisionedAccount
    let graph: CookingGraph
    func validate(for resolved: ProvisionedAccount) throws {
        try account.validate(for: AuthenticatedIdentity(userID: resolved.authUserID))
        guard account.accountID == resolved.accountID, account.libraryState == .initialized,
              account.syncRevision >= resolved.syncRevision, graph.accountID == account.accountID,
              graph.libraries.count == 1, !graph.rankings.isEmpty else { throw AccountFoundationError.invalidResolution }
        try graph.validate()
    }
}

@MainActor protocol AccountLibraryBackend: AccountBackend {
    func openLibrary(for account: ProvisionedAccount) async throws -> AccountLibrarySnapshot
    func rememberReadyAccount(_ account: ProvisionedAccount) throws
    func offlineAccount(for identity: AuthenticatedIdentity) throws -> ProvisionedAccount?
}

/// A resolved Auth/account receipt never grants access until a separate store is ready.
@MainActor @Observable final class AccountLibraryAccess {
    private(set) var store: LocalStoreSession?
    private(set) var account: ProvisionedAccount?
    private(set) var failed = false
    private(set) var offline = false
    @ObservationIgnored private var generation = 0
    func reset() { generation += 1; store = nil; account = nil; failed = false; offline = false }
    func isReady(for resolved: ProvisionedAccount) -> Bool {
        account?.accountID == resolved.accountID && account?.authUserID == resolved.authUserID && store?.scope == .account(resolved.accountID)
    }
    func prepare(_ resolved: ProvisionedAccount, root: URL? = nil, offline: Bool = false,
                 load: () async throws -> AccountLibrarySnapshot,
                 remember: (ProvisionedAccount) throws -> Void = { _ in }) async {
        reset(); let current = generation
        do {
            let snapshot: AccountLibrarySnapshot?
            if offline { snapshot = nil }
            else { snapshot = try await load(); try snapshot?.validate(for: resolved) }
            guard current == generation, !Task.isCancelled else { return }
            let session = try LocalStoreStartup.openAccount(resolved.accountID, root: root)
            let context = session.container.mainContext
            guard let binding = try SyncJournal.binding(context), binding.accountID == resolved.accountID else { throw SyncFoundationError.wrongAccount }
            if let snapshot {
                let graph = snapshot.graph.canonicalized(), encoded = try graph.encoded()
                let hasPending = !(try SyncJournal.pending(context)).isEmpty
                if !binding.restorationRequired && binding.acceptedSnapshotData != nil &&
                    ((binding.acceptedRevision == snapshot.account.syncRevision && binding.acceptedSnapshotData == encoded) || hasPending) {
                    // Local drafts/committed outbox changes must survive a same-base relaunch.
                    try CookingGraphExport.snapshot(context: context).validate()
                } else {
                    try session.restore(graph, revision: snapshot.account.syncRevision)
                }
                try remember(snapshot.account)
            } else {
                guard !binding.restorationRequired, binding.acceptedSnapshotData != nil, binding.acceptedRevision >= 0 else { throw SyncFoundationError.restorationRequired }
                try CookingGraphExport.snapshot(context: context).validate()
            }
            try SyncJournal.enable(context)
            guard current == generation, !Task.isCancelled else { return }
            self.account = snapshot?.account ?? resolved; self.store = session; self.offline = offline
        } catch {
            guard current == generation, !Task.isCancelled else { return }
            failed = true // Never show arbitrary SDK/error text or mount partially restored data.
        }
    }
}

private struct CookingMediaRootKey: EnvironmentKey { static let defaultValue: URL? = nil }
extension EnvironmentValues {
    var cookingMediaRoot: URL? {
        get { self[CookingMediaRootKey.self] }
        set { self[CookingMediaRootKey.self] = newValue }
    }
}
