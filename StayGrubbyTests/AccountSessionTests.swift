import Foundation
import SwiftData
import Testing
@testable import StayGrubby

@MainActor private final class AccountMockBackend: AccountBackend {
    var identity: AuthenticatedIdentity?
    var restoredFailure = false
    var provisionFailure = false
    var signOutFailure = false
    var holdProvision = false
    var receiptOverride: ProvisionedAccount?
    var reads = 0, provisions = 0, signOuts = 0
    var pending: [UUID: CheckedContinuation<ProvisionedAccount, Error>] = [:]
    var accounts: [UUID: UUID] = [:]
    var events: AsyncStream<AuthenticatedIdentity?>.Continuation?
    init(identity: AuthenticatedIdentity? = nil) { self.identity = identity }
    func signInWithApple(_ credentials: AppleSignInCredentials) async throws -> AuthenticatedIdentity {
        throw URLError(.unsupportedURL) // Part 1 tests exercise restoration, not provider authentication.
    }
    func restoredIdentity() async throws -> AuthenticatedIdentity? {
        reads += 1
        if restoredFailure { throw URLError(.notConnectedToInternet) }
        return identity
    }
    func receipt(_ identity: AuthenticatedIdentity) -> ProvisionedAccount {
        if let receiptOverride { return receiptOverride }
        let id = accounts[identity.userID] ?? UUID(); accounts[identity.userID] = id
        return ProvisionedAccount(formatVersion: 1, authUserID: identity.userID, accountID: id, syncRevision: 0, libraryState: .uninitialized)
    }
    func provision(for identity: AuthenticatedIdentity) async throws -> ProvisionedAccount {
        provisions += 1
        if provisionFailure { throw URLError(.notConnectedToInternet) }
        if holdProvision {
            return try await withCheckedThrowingContinuation { pending[identity.userID] = $0 }
        }
        return receipt(identity)
    }
    func complete(_ identity: AuthenticatedIdentity) {
        pending.removeValue(forKey: identity.userID)?.resume(returning: receipt(identity))
    }
    func identityChanges() -> AsyncStream<AuthenticatedIdentity?> {
        AsyncStream { events = $0 }
    }
    func emit(_ identity: AuthenticatedIdentity?) { self.identity = identity; events?.yield(identity) }
    func signOutLocally() async throws {
        signOuts += 1; identity = nil
        if signOutFailure { throw URLError(.notConnectedToInternet) }
    }
}

@MainActor struct AccountSessionTests {
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("account-session-\(UUID())") }
    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<200 { if condition() { return }; await Task.yield() }
        #expect(condition(), "Asynchronous state transition completed")
    }
    @Test func guestLaunchAndSignOutDoNotConstructBackendOrRequireNetwork() async throws {
        var creations = 0
        let session = AccountSessionCoordinator(backendFactory: { creations += 1; throw URLError(.notConnectedToInternet) })
        #expect(session.state == .guest && session.preparedStore == nil)
        await session.signOut()
        #expect(creations == 0 && session.state == .guest)
        let guest = try LocalStoreSession.open(.guest, root: root())
        let list = try guest.prepare()
        #expect(list.items.isEmpty)
        #expect(try SyncJournal.binding(guest.container.mainContext) == nil)
    }
    @Test func absentSavedSessionDoesNotProvisionOrPrepareAccount() async {
        let backend = AccountMockBackend(); let session = AccountSessionCoordinator(backendFactory: { backend })
        await session.restoreSession()
        #expect(session.state == .guest && backend.provisions == 0 && session.preparedStore == nil)
    }
    @Test func authSessionAloneCannotSelectStoreWhileProvisioning() async throws {
        let identity = AuthenticatedIdentity(userID: UUID())
        let backend = AccountMockBackend(identity: identity); backend.holdProvision = true
        let session = AccountSessionCoordinator(backendFactory: { backend })
        let work = Task { await session.restoreSession() }
        await waitUntil { backend.pending[identity.userID] != nil }
        #expect(session.state == .provisioning(identity))
        #expect(throws: AccountFoundationError.self) { try session.prepareResolvedStore(root: root()) }
        backend.complete(identity); await work.value
        guard case .resolved(let account) = session.state else { Issue.record("Account did not resolve"); return }
        #expect(account.accountID != identity.userID)
        let store = try session.prepareResolvedStore(root: root())
        #expect(store.scope == .account(account.accountID))
        #expect(try store.container.mainContext.fetchCount(FetchDescriptor<RankingList>()) == 0)
        #expect(try SyncJournal.binding(store.container.mainContext)?.restorationRequired == true)
        #expect(throws: SyncFoundationError.self) { try store.prepare() }
    }
    @Test func provisioningFailureRetriesWithoutGuestAdoption() async throws {
        let identity = AuthenticatedIdentity(userID: UUID())
        let backend = AccountMockBackend(identity: identity); backend.provisionFailure = true
        let session = AccountSessionCoordinator(backendFactory: { backend })
        await session.restoreSession()
        #expect(session.state == .retryRequired(.provision, identity) && session.preparedStore == nil)
        backend.provisionFailure = false; await session.retry()
        guard case .resolved(let account) = session.state else { Issue.record("Retry failed"); return }
        #expect(backend.provisions == 2 && account.libraryState == .uninitialized)
        let store = try session.prepareResolvedStore(root: root())
        #expect(try store.container.mainContext.fetchCount(FetchDescriptor<Dish>()) == 0)
        #expect(try SyncJournal.pending(store.container.mainContext).isEmpty)
    }
    @Test func sessionLoadingFailureIsRetryable() async {
        let backend = AccountMockBackend(); backend.restoredFailure = true
        let session = AccountSessionCoordinator(backendFactory: { backend })
        await session.restoreSession()
        #expect(session.state == .retryRequired(.restoreSession, nil))
        backend.restoredFailure = false; await session.retry()
        #expect(session.state == .guest && backend.reads == 2)
    }
    @Test func wrongAuthIdentityReceiptDoesNotUnlockStore() async {
        let identity = AuthenticatedIdentity(userID: UUID()), wrong = AuthenticatedIdentity(userID: UUID())
        let backend = AccountMockBackend(identity: identity); backend.receiptOverride = backend.receipt(wrong)
        let session = AccountSessionCoordinator(backendFactory: { backend })
        await session.restoreSession()
        #expect(session.state == .retryRequired(.provision, identity) && session.preparedStore == nil)
    }
    @Test func signOutPreservesAccountFilesAndReturnsToGuest() async throws {
        let identity = AuthenticatedIdentity(userID: UUID()), directory = root()
        let backend = AccountMockBackend(identity: identity); var stops = 0
        let session = AccountSessionCoordinator(backendFactory: { backend }, stopAccountWork: { stops += 1 })
        await session.restoreSession()
        let store = try session.prepareResolvedStore(root: directory)
        try store.initializeVerifiedEmptyAccount() // Explicit test-only verified-empty authorization.
        let rankingID = try store.prepare().id
        let accountID = try #require(store.scope.accountID)
        await session.signOut()
        #expect(session.state == .guest && session.preparedStore == nil && backend.signOuts == 1)
        #expect(stops >= 2)
        let reopened = try LocalStoreStartup.openAccount(accountID, root: directory)
        #expect(try reopened.prepare().id == rankingID)
        let guest = try LocalStoreSession.open(.guest, root: directory)
        #expect(try guest.prepare().id != rankingID && guest.mediaRoot != store.mediaRoot)
    }
    @Test func lateProvisioningReplyAfterSignOutCannotRestoreAccess() async {
        let identity = AuthenticatedIdentity(userID: UUID())
        let backend = AccountMockBackend(identity: identity); backend.holdProvision = true
        let session = AccountSessionCoordinator(backendFactory: { backend })
        let work = Task { await session.restoreSession() }
        await waitUntil { backend.pending[identity.userID] != nil }
        await session.signOut(); backend.complete(identity); await work.value
        #expect(session.state == .guest && session.preparedStore == nil)
    }
    @Test func identityChangeInvalidatesPreparedStoreAndSelectsDifferentAccount() async throws {
        let a = AuthenticatedIdentity(userID: UUID()), b = AuthenticatedIdentity(userID: UUID()), directory = root()
        let backend = AccountMockBackend(identity: a), session = AccountSessionCoordinator(backendFactory: { backend })
        await session.restoreSession()
        let first = try session.prepareResolvedStore(root: directory)
        backend.emit(b)
        await waitUntil { if case .resolved(let value) = session.state { return value.authUserID == b.userID }; return false }
        #expect(session.preparedStore == nil)
        let second = try session.prepareResolvedStore(root: directory)
        #expect(first.scope != second.scope && first.mediaRoot != second.mediaRoot)
        #expect(try second.container.mainContext.fetchCount(FetchDescriptor<RankingList>()) == 0)
        await session.signOut()
    }
    @Test func lateReplyForPreviousIdentityCannotReplaceNewAccountResolution() async {
        let a = AuthenticatedIdentity(userID: UUID()), b = AuthenticatedIdentity(userID: UUID())
        let backend = AccountMockBackend(identity: a); backend.holdProvision = true
        let session = AccountSessionCoordinator(backendFactory: { backend })
        let work = Task { await session.restoreSession() }
        await waitUntil { backend.pending[a.userID] != nil }
        backend.emit(b)
        await waitUntil { backend.pending[b.userID] != nil }
        backend.complete(b)
        await waitUntil { if case .resolved(let value) = session.state { return value.authUserID == b.userID }; return false }
        backend.complete(a); await work.value
        guard case .resolved(let value) = session.state else { Issue.record("New identity resolution lost"); return }
        #expect(value.authUserID == b.userID && session.preparedStore == nil)
        await session.signOut()
    }
    @Test func tokenRefreshForSameIdentityDoesNotReprovision() async {
        let identity = AuthenticatedIdentity(userID: UUID()), backend = AccountMockBackend()
        backend.identity = identity
        let session = AccountSessionCoordinator(backendFactory: { backend }); await session.restoreSession()
        backend.emit(identity)
        for _ in 0..<20 { await Task.yield() }
        #expect(backend.provisions == 1)
        await session.signOut()
    }
    @Test func networkFailureDuringSignOutStillLeavesGuestAndNoStoreAccess() async {
        let backend = AccountMockBackend(identity: AuthenticatedIdentity(userID: UUID())); backend.signOutFailure = true
        let session = AccountSessionCoordinator(backendFactory: { backend }); await session.restoreSession(); await session.signOut()
        #expect(session.state == .guest && session.preparedStore == nil && session.remoteSignOutFailed)
        #expect(backend.identity == nil)
    }
    @Test func wireReceiptAndConfigurationAcceptOnlyExpectedSafeContract() throws {
        let identity = AuthenticatedIdentity(userID: UUID())
        let backend = AccountMockBackend(identity: identity), account = backend.receipt(identity)
        #expect(try JSONDecoder().decode(ProvisionedAccount.self, from: JSONEncoder().encode(account)) == account)
        let values = ["ProjectReference":"fixture", "ProjectURL":"https://fixture.supabase.co", "PublishableKey":"sb_publishable_fixture"]
        #expect(try SupabaseClientConfiguration.validated(values).projectURL.host == "fixture.supabase.co")
        #expect(throws: SupabaseClientConfiguration.ConfigurationError.self) {
            try SupabaseClientConfiguration.validated(values.merging(["ServiceRoleKey":"forbidden"]) { _, right in right })
        }
        #expect(throws: SupabaseClientConfiguration.ConfigurationError.self) {
            try SupabaseClientConfiguration.validated(values.merging(["PublishableKey":"sb_secret_forbidden"]) { _, right in right })
        }
        #expect(throws: SupabaseClientConfiguration.ConfigurationError.self) {
            try SupabaseClientConfiguration.validated(values.merging(["ProjectURL":"http://fixture.supabase.co"]) { _, right in right })
        }
    }
    @Test(arguments: [0, 2, -1]) func incompatibleReceiptsRejected(version: Int) throws {
        let identity = AuthenticatedIdentity(userID: UUID())
        let receipt = ProvisionedAccount(formatVersion: version, authUserID: identity.userID, accountID: UUID(), syncRevision: 0, libraryState: .uninitialized)
        #expect(throws: AccountFoundationError.self) { try receipt.validate(for: identity) }
    }
}
