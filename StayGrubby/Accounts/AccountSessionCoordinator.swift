import Foundation
import Observation

nonisolated enum AccountSessionState: Equatable {
    enum RetryStep: Equatable { case restoreSession, provision }
    case guest
    case authorizingApple
    case authenticating
    case signInFailed
    case loadingSession
    case provisioning(AuthenticatedIdentity)
    case resolved(ProvisionedAccount)
    case retryRequired(RetryStep, AuthenticatedIdentity?)
}

/// Auth/account resolution is separate from library readiness. The application
/// root grants personal access only after the account-specific store is ready.
@MainActor @Observable final class AccountSessionCoordinator {
    private(set) var state: AccountSessionState = .guest
    private(set) var preparedStore: LocalStoreSession?
    private(set) var remoteSignOutFailed = false
    private(set) var isSigningOut = false
    private(set) var offlineResolution = false
    var hasPendingAppleRequest: Bool { pendingApple != nil }
    @ObservationIgnored private let backendFactory: @MainActor () throws -> any AccountBackend
    @ObservationIgnored private let stopAccountWork: @MainActor () -> Void
    @ObservationIgnored private var backend: (any AccountBackend)?
    @ObservationIgnored private var observer: Task<Void, Never>?
    @ObservationIgnored private var eventWork: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var identity: AuthenticatedIdentity?
    @ObservationIgnored private var pendingApple: (request: AppleSignInRequest, nonce: AppleSignInNonce)?
    @ObservationIgnored private var authenticationWork: Task<AuthenticatedIdentity, Error>?
    @ObservationIgnored private var startedRestoration = false
    @ObservationIgnored private let nonceFactory: () throws -> AppleSignInNonce

    init(backendFactory: @escaping @MainActor () throws -> any AccountBackend = {
        try SupabaseAccountBackend(configuration: .load())
    }, stopAccountWork: @escaping @MainActor () -> Void = {},
       nonceFactory: @escaping () throws -> AppleSignInNonce = { try .generate() }) {
        self.backendFactory = backendFactory; self.stopAccountWork = stopAccountWork
        self.nonceFactory = nonceFactory
    }
    private func service() throws -> any AccountBackend {
        if let backend { return backend }
        let value = try backendFactory(); backend = value; return value
    }
    private func invalidateAccount() {
        generation += 1; eventWork?.cancel(); eventWork = nil
        preparedStore = nil; identity = nil; stopAccountWork()
        pendingApple = nil
        offlineResolution = false
    }
    /// Runs behind onboarding; no saved session means no provisioning/network.
    func restoreSessionOnLaunch() async {
        guard !startedRestoration else { return }
        startedRestoration = true
        await restoreSession()
    }
    #if DEBUG
    /// Explicit review mode has no Auth session or production account route.
    func beginDevelopmentReview() -> Bool {
        guard !isSigningOut else { return false }
        switch state {
        case .guest, .signInFailed, .retryRequired(.restoreSession, nil): break
        default: return false
        }
        invalidateAccount(); observer?.cancel(); observer = nil
        startedRestoration = true; state = .guest
        return true
    }
    #endif
    func beginAppleSignIn() -> AppleSignInRequest? {
        guard !isSigningOut else { return nil }
        switch state { case .guest, .signInFailed: break; default: return nil }
        startedRestoration = true
        invalidateAccount(); observer?.cancel(); observer = nil
        remoteSignOutFailed = false
        do {
            let nonce = try nonceFactory()
            let request = AppleSignInRequest(id: UUID(), hashedNonce: nonce.hash)
            pendingApple = (request, nonce); state = .authorizingApple
            return request
        } catch { state = .signInFailed; return nil }
    }
    func appleAuthorizationFailed(requestID: UUID, cancelled: Bool) {
        guard pendingApple?.request.id == requestID else { return }
        pendingApple = nil
        state = cancelled ? .guest : .signInFailed
    }
    func completeAppleSignIn(requestID: UUID, identityToken: Data?) async {
        guard let pending = pendingApple, pending.request.id == requestID else { return }
        pendingApple = nil // Single use, including malformed-token and failure paths.
        let current = generation
        do {
            let credentials = try AppleSignInCredentials(identityToken: identityToken, nonce: pending.nonce)
            let service = try service()
            state = .authenticating
            let work = Task { try await service.signInWithApple(credentials) }
            authenticationWork = work
            let authenticated = try await work.value
            guard current == generation, !Task.isCancelled else { return }
            authenticationWork = nil
            identity = authenticated
            observe(service)
            await resolve(authenticated, generation: current, service: service)
        } catch {
            if current == generation { authenticationWork = nil; state = .signInFailed }
        }
    }
    func restoreSession() async {
        guard !isSigningOut, authenticationWork == nil, pendingApple == nil else { return }
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
            if isOfflineConnectionError(error), let library = service as? any AccountLibraryBackend,
               let cached = try? library.offlineAccount(for: identity),
               (try? cached.validate(for: identity)) != nil, cached.libraryState == .initialized {
                offlineResolution = true; state = .resolved(cached); return
            }
            // Never surface arbitrary SDK/server error text that might contain request credentials.
            state = .retryRequired(.provision, identity)
        }
    }
    func openResolvedLibrary() async throws -> AccountLibrarySnapshot {
        guard case .resolved(let account) = state, let service = backend as? any AccountLibraryBackend else { throw AccountFoundationError.accountNotResolved }
        let current = generation
        let snapshot = try await service.openLibrary(for: account)
        guard current == generation, case .resolved(let latest) = state, latest == account else { throw AccountFoundationError.identityChanged }
        return snapshot
    }
    func rememberReadyAccount(_ account: ProvisionedAccount) throws {
        guard case .resolved(let resolved) = state, resolved.accountID == account.accountID,
              resolved.authUserID == account.authUserID, let service = backend as? any AccountLibraryBackend else { throw AccountFoundationError.identityChanged }
        try service.rememberReadyAccount(account)
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
        guard !isSigningOut else { return }
        isSigningOut = true
        let authenticating = authenticationWork
        authenticating?.cancel()
        invalidateAccount(); observer?.cancel(); observer = nil
        state = .guest; remoteSignOutFailed = false
        let current = generation
        // A cancelled HTTP exchange may still persist a session. Drain it before
        // removing SDK storage, and block new sign-in until local cleanup finishes.
        _ = try? await authenticating?.value
        authenticationWork = nil
        defer { isSigningOut = false }
        guard let backend else { return } // Guest sign-out never creates an SDK client.
        do { try await backend.signOutLocally() }
        catch { if current == generation { remoteSignOutFailed = true } }
        // The root gate is already closed. Cloud rows and account files are retained.
    }
    deinit { observer?.cancel(); eventWork?.cancel(); authenticationWork?.cancel() }
}
