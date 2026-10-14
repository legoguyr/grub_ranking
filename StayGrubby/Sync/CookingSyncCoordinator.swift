import Foundation
import SwiftData
import SwiftUI
import Observation
import Network

/// One foreground worker for one verified account/store. Guest/demo trees never connect it.
@MainActor @Observable final class CookingSyncCoordinator {
    enum Status: Equatable {
        case idle, syncing, current, savedLocally, conflict, needsReview, signInRequired
        var label: String {
            switch self {
            case .idle: ""
            case .syncing: "Syncing cooking data…"
            case .current: "Cooking data up to date"
            case .savedLocally: "Saved on this device · Sync pending"
            case .conflict: "Local changes saved · Sync conflict needs reconciliation"
            case .needsReview: "Local changes saved · Sync needs review"
            case .signInRequired: "Local changes saved · Sign in again to sync"
            }
        }
    }
    private(set) var status = Status.idle
    @ObservationIgnored private var connection: UUID?
    @ObservationIgnored private var store: LocalStoreSession?
    @ObservationIgnored private var owner: ProvisionedAccount?
    @ObservationIgnored private var send: (@Sendable (SyncEnvelope) async throws -> SyncReceipt)?
    @ObservationIgnored private var load: (@MainActor () async throws -> AccountLibrarySnapshot)?
    @ObservationIgnored private var remember: (@MainActor (ProvisionedAccount) throws -> Void)?
    @ObservationIgnored private var photos: (any CookingPhotoTransport)?
    @ObservationIgnored private var jobID: UUID?
    @ObservationIgnored private var job: Task<Void, Never>?
    @ObservationIgnored private var retry: Task<Void, Never>?
    @ObservationIgnored private var observer: NSObjectProtocol?
    @ObservationIgnored private var monitor: NWPathMonitor?
    @ObservationIgnored private var active = true
    @ObservationIgnored private var requested = false
    @ObservationIgnored private var holds = Set<UUID>()

    @discardableResult func connect(store: LocalStoreSession, account: ProvisionedAccount,
        send: @escaping @Sendable (SyncEnvelope) async throws -> SyncReceipt,
        load: @escaping @MainActor () async throws -> AccountLibrarySnapshot, active: Bool = true,
        photos: (any CookingPhotoTransport)? = nil,
        remember: @escaping @MainActor (ProvisionedAccount) throws -> Void = { _ in }) throws -> UUID {
        disconnect()
        guard store.scope == .account(account.accountID), let binding = try SyncJournal.binding(store.container.mainContext),
              binding.accountID == account.accountID, binding.enabled, !binding.restorationRequired
        else { throw SyncFoundationError.wrongAccount }
        let token = UUID(); connection = token; self.active = active
        self.store = store; owner = account; self.send = send; self.load = load; self.remember = remember
        self.photos = photos
        observer = NotificationCenter.default.addObserver(forName: .cookingSyncWorkCommitted, object: store.container, queue: .main) { [weak self] _ in
            guard let coordinator = self else { return }
            Task { @MainActor in coordinator.request() }
        }
        let path = NWPathMonitor(); monitor = path
        path.pathUpdateHandler = { [weak self] value in
            if value.status == .satisfied, let coordinator = self {
                Task { @MainActor in coordinator.request() }
            }
        }
        path.start(queue: DispatchQueue(label: "StayGrubby.cooking-sync-connectivity"))
        request()
        return token
    }
    func disconnect(_ token: UUID? = nil) {
        if let token, token != connection { return }
        connection = nil; job?.cancel(); job = nil; jobID = nil; retry?.cancel(); retry = nil
        if let observer { NotificationCenter.default.removeObserver(observer) }; observer = nil
        monitor?.cancel(); monitor = nil
        store = nil; owner = nil; send = nil; load = nil; remember = nil; photos = nil; requested = false; holds.removeAll(); status = .idle
    }
    func setActive(_ value: Bool) {
        active = value
        if value { request() }
        else { job?.cancel(); job = nil; jobID = nil; retry?.cancel(); retry = nil }
    }
    var hasActiveRestoreLease: Bool { !holds.isEmpty }
    func hold(_ id: UUID) { holds.insert(id) }
    func release(_ id: UUID) { holds.remove(id); if holds.isEmpty { request() } }
    func request(forceRetry: Bool = false) {
        guard active, let token = connection, let store, let owner, let send, let load else { return }
        if job != nil { requested = true; return }
        retry?.cancel(); retry = nil; requested = false
        let work = UUID(); jobID = work
        let photoTransport = photos
        job = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.connection == token && self.jobID == work {
                    self.job = nil; self.jobID = nil
                    if self.requested { self.requested = false; self.request() }
                }
            }
            do {
                // Coalesce transaction/path/foreground notifications, not polling.
                try await Task.sleep(for: .milliseconds(250))
                guard self.connection == token, self.active else { return }
                let pending = try SyncJournal.pending(ModelContext(store.container))
                if !forceRetry, let error = pending.first?.lastError {
                    switch error {
                    case "revision-conflict": self.status = .conflict; return
                    case "operation-rejected": self.status = .needsReview; return
                    case "authentication-required": self.status = .signInRequired; return
                    default: break
                    }
                }
                self.status = .syncing
                try await SyncDispatcher().flush(context: store.container.mainContext,
                    transport: AuthorizedCookingTransport(sendOperation: send), now: forceRetry ? .distantFuture : .now)
                try Task.checkCancellation()
                guard self.connection == token else { return }
                let context = store.container.mainContext
                var graphReady = false
                // Never overwrite value drafts or another context's unsaved domain edits.
                if !(try SyncJournal.pending(context)).isEmpty || !self.holds.isEmpty || context.hasChanges {
                    self.status = .savedLocally
                    self.scheduleRetry(store: store, token: token)
                } else {
                    let snapshot = try await load(); try Task.checkCancellation()
                    guard self.connection == token else { return }
                    try snapshot.validate(for: owner)
                    let hasPending = !(try SyncJournal.pending(context)).isEmpty
                    if !self.holds.isEmpty || context.hasChanges || hasPending {
                        self.status = .savedLocally
                    } else {
                        let previousMedia = try CookingGraphExport.snapshot(context: context).media
                        try CookingGraphHydration.apply(snapshot.graph, revision: snapshot.account.syncRevision, context: context)
                        if let root = store.mediaRoot {
                            for old in previousMedia where !snapshot.graph.media.contains(where: { $0.id == old.id }) {
                                LocalPhotoStore.deleteFiles(displayFilename: old.displayFilename, thumbnailFilename: old.thumbnailFilename, rootURL: root)
                            }
                        }
                        try self.remember?(snapshot.account)
                        graphReady = true
                    }
                }
                if let photoTransport, (try SyncJournal.pending(context)).isEmpty {
                    let complete = try await CookingPhotoSync.run(store: store, account: owner, transport: photoTransport,
                        forceRetry: forceRetry, allowDownloads: self.holds.isEmpty && !context.hasChanges,
                        current: {
                            try Task.checkCancellation()
                            guard self.connection == token, self.active else { throw CancellationError() }
                        })
                    if !complete { self.status = .savedLocally; self.scheduleRetry(store: store, token: token) }
                    else if graphReady, (try SyncJournal.pending(context)).isEmpty, !context.hasChanges { self.status = .current }
                } else if graphReady {
                    self.status = .current
                }
            } catch {
                guard self.connection == token, !Task.isCancelled else { return }
                switch error {
                case CookingPhotoError.integrity, CookingPhotoError.rejected: self.status = .needsReview
                case CookingPhotoError.authenticationRequired: self.status = .signInRequired
                case CookingPhotoError.obsolete:
                    self.status = .savedLocally
                    if (try? SyncJournal.pending(store.container.mainContext).isEmpty) == false { self.requested = true }
                    else { self.scheduleRetry(store: store, token: token) }
                case CookingSyncError.conflict: self.status = .conflict
                case CookingSyncError.authenticationRequired, AccountFoundationError.identityChanged: self.status = .signInRequired
                case CookingSyncError.rejected, is SyncFoundationError: self.status = .needsReview
                default: self.status = .savedLocally; self.scheduleRetry(store: store, token: token)
                }
            }

        }
    }
    private func scheduleRetry(store: LocalStoreSession, token: UUID) {
        let context = ModelContext(store.container)
        let operationDeadline = (try? SyncJournal.pending(context).first)?.nextRetryAt
        let photoDeadline: Date?
        if let root = store.mediaRoot, let owner = store.scope.accountID {
            photoDeadline = (try? CookingPhotoJournal.load(owner: owner, root: root))?.retryAt
        } else { photoDeadline = nil }
        guard let deadline = [operationDeadline, photoDeadline].compactMap({ $0 }).min() else { return }
        retry?.cancel()
        retry = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(max(1, deadline.timeIntervalSinceNow))) }
            catch { return }
            guard self?.connection == token else { return }
            self?.request()
        }
    }
}

private struct CookingSyncCoordinatorKey: EnvironmentKey {
    static let defaultValue: CookingSyncCoordinator? = nil
}
extension EnvironmentValues {
    var cookingSyncCoordinator: CookingSyncCoordinator? {
        get { self[CookingSyncCoordinatorKey.self] }
        set { self[CookingSyncCoordinatorKey.self] = newValue }
    }
}
/// A retained navigation destination stays protected even when another tab hides it.
nonisolated final class CookingRestoreLease: Sendable {
    private let release: @Sendable () -> Void
    init(release: @escaping @Sendable () -> Void) { self.release = release }
    deinit { release() }
}
private struct DeferredCookingRestore: ViewModifier {
    @Environment(\.cookingSyncCoordinator) private var sync
    @State private var id = UUID()
    @State private var lease: CookingRestoreLease?
    @ViewBuilder func body(content: Content) -> some View {
        if let sync {
            content.onAppear {
                guard lease == nil else { return }
                sync.hold(id)
                let token = id
                lease = CookingRestoreLease { [weak sync] in
                    guard let coordinator = sync else { return }
                    Task { @MainActor in coordinator.release(token) }
                }
            }
        } else { content } // Demo/review UI has no sync lifecycle hooks.
    }
}
extension View {
    func deferRemoteCookingUpdates() -> some View { modifier(DeferredCookingRestore()) }
}
