import Foundation
import Observation

nonisolated enum AccountSessionState: Equatable {
    enum RetryStep: Equatable { case restoreSession, provision }
    case guest
    case loadingSession
    case provisioning(AuthenticatedIdentity)
    case resolved(ProvisionedAccount)
    case retryRequired(RetryStep, AuthenticatedIdentity?)
}

/// Part 1 keeps the presented UI in its guest container. Resolution and store
/// preparation are separate steps; preparing never restores/initializes/mounts data.
@MainActor @Observable final class AccountSessionCoordinator {
    private(set) var state: AccountSessionState = .guest
    private(set) var preparedStore: LocalStoreSession?
    private(set) var remoteSignOutFailed = false
    @ObservationIgnored private let backendFactory: @MainActor () throws -> any AccountBackend
    @ObservationIgnored private let stopAccountWork: @MainActor () -> Void
    @ObservationIgnored private var backend: (any AccountBackend)?
    @ObservationIgnored private var observer: Task<Void, Never>?
    @ObservationIgnored private var eventWork: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var identity: AuthenticatedIdentity?

    init(backendFactory: @escaping @MainActor () throws -> any AccountBackend = {
        try SupabaseAccountBackend(configuration: .load())
    }, stopAccountWork: @escaping @MainActor () -> Void = {}) {
        self.backendFactory = backendFactory; self.stopAccountWork = stopAccountWork
    }
    private func service() throws -> any AccountBackend {
        if let backend { return backend }
        let value = try backendFactory(); backend = value; return value
    }
    private func invalidateAccount() {
        generation += 1; eventWork?.cancel(); eventWork = nil
        preparedStore = nil; identity = nil; stopAccountWork()
    }
    /// Called explicitly by future auth UI. Guest launch never constructs a client or awaits network.
    func restoreSession() async {
        invalidateAccount(); observer?.cancel(); observer = nil
        remoteSignOutFailed = false; state = .loadingSession
        let current = generation
        do {
            let service = try service()
            let restored = try await service.restoredIdentity()
            guard current == generation, !Task.isCancelled else { return }
            identity = restored
            observe(service)
            if let restored { await resolve(restored, generation: current, service: service) }
            else { state = .guest }
        } catch {
            guard current == generation, !Task.isCancelled else { return }
            state = .retryRequired(.restoreSession, nil)
        }
    }
    private func observe(_ service: any AccountBackend) {
        let changes = service.identityChanges()
        observer = Task { [weak self] in
            for await changed in changes {
                guard !Task.isCancelled else { break }
                self?.receive(changed, service: service)
            }
        }
    }
    private func receive(_ changed: AuthenticatedIdentity?, service: any AccountBackend) {
        // Token refresh for the same identity must not issue duplicate provisioning requests.
        guard changed != identity else { return }
        invalidateAccount(); identity = changed
        guard let changed else { state = .guest; return }
        state = .provisioning(changed)
        let current = generation
        eventWork = Task { [weak self] in
            await self?.resolve(changed, generation: current, service: service)
        }
    }
    private func resolve(_ identity: AuthenticatedIdentity, generation current: Int, service: any AccountBackend) async {
        guard current == generation, !Task.isCancelled else { return }
        state = .provisioning(identity)
        do {
            let account = try await service.provision(for: identity)
            try account.validate(for: identity)
            guard current == generation, !Task.isCancelled else { return }
            state = .resolved(account)
        } catch {
            guard current == generation, !Task.isCancelled else { return }
            // Never surface arbitrary SDK/server error text that might contain request credentials.
            state = .retryRequired(.provision, identity)
        }
    }
    func retry() async {
        switch state {
        case .retryRequired(.restoreSession, _): await restoreSession()
        case .retryRequired(.provision, let identity?):
            guard let backend else { await restoreSession(); return }
            generation += 1; eventWork?.cancel()
            await resolve(identity, generation: generation, service: backend)
        default: break
        }
    }
    /// Selects the resolved permanent UUID, never the Auth UUID. Part 1 does not mount it.
    @discardableResult func prepareResolvedStore(root: URL? = nil) throws -> LocalStoreSession {
        guard case .resolved(let account) = state, account.authUserID == identity?.userID
        else { throw AccountFoundationError.accountNotResolved }
        if let preparedStore { return preparedStore }
        let session = try LocalStoreStartup.openAccount(account.accountID, root: root)
        preparedStore = session
        return session
    }
    func signOut() async {
        invalidateAccount(); observer?.cancel(); observer = nil
        state = .guest; remoteSignOutFailed = false
        let current = generation
        guard let backend else { return } // Guest sign-out never creates an SDK client.
        do { try await backend.signOutLocally() }
        catch { if current == generation { remoteSignOutFailed = true } }
        // Local guest routing already happened. Cloud rows and account files are retained.
    }
    deinit { observer?.cancel(); eventWork?.cancel() }
}
