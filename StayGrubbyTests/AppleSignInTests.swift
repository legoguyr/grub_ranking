import Foundation
import Testing
import Supabase
import AuthenticationServices
@testable import StayGrubby

@MainActor private final class AppleMockBackend: AccountBackend {
    let user = AuthenticatedIdentity(userID: UUID())
    let accountID = UUID()
    var identity: AuthenticatedIdentity?
    var received: AppleSignInCredentials?
    var signIns = 0, provisions = 0, restores = 0, signOuts = 0
    var failAuth = false, failProvision = false, failRestore = false
    var holdAuth = false, holdProvision = false
    var authReply: CheckedContinuation<AuthenticatedIdentity, Error>?
    var provisionReply: CheckedContinuation<ProvisionedAccount, Error>?
    var events: AsyncStream<AuthenticatedIdentity?>.Continuation?
    func signInWithApple(_ credentials: AppleSignInCredentials) async throws -> AuthenticatedIdentity {
        signIns += 1; received = credentials
        if failAuth { throw URLError(.notConnectedToInternet) }
        if holdAuth {
            let value = try await withCheckedThrowingContinuation { authReply = $0 }
            identity = value // Models an SDK request which ignores cancellation and persists late.
            return value
        }
        identity = user; return user
    }
    func restoredIdentity() async throws -> AuthenticatedIdentity? {
        restores += 1
        if failRestore { throw URLError(.notConnectedToInternet) }
        return identity
    }
    var receipt: ProvisionedAccount {
        ProvisionedAccount(formatVersion: 1, authUserID: user.userID, accountID: accountID, syncRevision: 0, libraryState: .uninitialized)
    }
    func provision(for identity: AuthenticatedIdentity) async throws -> ProvisionedAccount {
        provisions += 1
        if failProvision { throw URLError(.notConnectedToInternet) }
        if holdProvision { return try await withCheckedThrowingContinuation { provisionReply = $0 } }
        return receipt
    }
    func identityChanges() -> AsyncStream<AuthenticatedIdentity?> { AsyncStream { events = $0 } }
    func signOutLocally() async throws { signOuts += 1; identity = nil }
}

@MainActor struct AppleSignInTests {
    private let token = Data("header.payload.signature".utf8)
    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<500 { if condition() { return }; await Task.yield() }
        #expect(condition())
    }
    @Test func nonceUsesIndependentRandomnessAndCorrectSHA256() throws {
        let nonces = try (0..<100).map { _ in try AppleSignInNonce.generate() }
        #expect(Set(nonces.map(\.raw)).count == 100)
        #expect(nonces.allSatisfy { $0.raw.count == 43 && $0.hash.count == 64 && $0.hash != $0.raw })
        #expect(AppleSignInNonce(raw: "abc").hash == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
    @Test func credentialsUseAppleAndOriginalNonceAndRedactDiagnostics() throws {
        let nonce = try AppleSignInNonce.generate()
        let credentials = try AppleSignInCredentials(identityToken: token, nonce: nonce)
        let sdk = credentials.supabaseCredentials()
        #expect(sdk.provider == .apple && sdk.nonce == nonce.raw && sdk.nonce != nonce.hash)
        #expect(sdk.idToken == String(data: token, encoding: .utf8) && sdk.accessToken == nil)
        #expect(!String(reflecting: credentials).contains(sdk.idToken))
        #expect(!String(reflecting: nonce).contains(nonce.raw))
        #expect(Mirror(reflecting: nonce).children.isEmpty && Mirror(reflecting: credentials).children.isEmpty)
    }
    @Test func deletionCredentialsRequireAndRedactAuthorizationCode() throws {
        let nonce = try AppleSignInNonce.generate()
        let credentials = try AppleAccountDeletionCredentials(identityToken: token,
            authorizationCode: Data("one-time-authorization-code".utf8), nonce: nonce)
        #expect(credentials.authorizationCode() == "one-time-authorization-code")
        #expect(!String(reflecting: credentials).contains("one-time-authorization-code"))
        #expect(Mirror(reflecting: credentials).children.isEmpty)
        #expect(throws: AppleSignInError.self) {
            try AppleAccountDeletionCredentials(identityToken: token, authorizationCode: nil, nonce: nonce)
        }
    }
    @Test(arguments: [nil, Data(), Data([0xff]), Data("a.b".utf8), Data("a..c".utf8), Data("a.b.c.d".utf8), Data("a.b.c\n".utf8), Data(repeating: 65, count: 16_385)])
    func missingOrMalformedTokensNeverReachBackend(token: Data?) async throws {
        let backend = AppleMockBackend(), session = AccountSessionCoordinator(backendFactory: { backend })
        let request = try #require(session.beginAppleSignIn())
        await session.completeAppleSignIn(requestID: request.id, identityToken: token)
        #expect(session.state == .signInFailed && !session.hasPendingAppleRequest)
        #expect(backend.signIns == 0 && backend.provisions == 0 && session.preparedStore == nil)
    }
    @Test func freshRequestsAndCancellationDoNotReuseOrRetainNonce() throws {
        let session = AccountSessionCoordinator(backendFactory: { throw URLError(.notConnectedToInternet) })
        let first = try #require(session.beginAppleSignIn())
        #expect(session.beginAppleSignIn() == nil)
        session.appleAuthorizationFailed(requestID: first.id, cancelled: true)
        #expect(session.state == .guest && !session.hasPendingAppleRequest)
        let second = try #require(session.beginAppleSignIn())
        #expect(first.id != second.id && first.hashedNonce != second.hashedNonce)
        session.appleAuthorizationFailed(requestID: first.id, cancelled: false)
        #expect(session.state == .authorizingApple)
        session.appleAuthorizationFailed(requestID: second.id, cancelled: false)
        #expect(session.state == .signInFailed && !session.hasPendingAppleRequest)
    }
    @Test func unavailableSecureRandomnessDoesNotStartAuthentication() {
        let session = AccountSessionCoordinator(nonceFactory: { throw AppleSignInError.randomnessUnavailable })
        #expect(session.beginAppleSignIn() == nil && session.state == .signInFailed)
        #expect(!session.hasPendingAppleRequest && session.preparedStore == nil)
    }
    @Test func authenticationPassesOriginalNonceAndRequiresResolution() async throws {
        let backend = AppleMockBackend(); backend.holdProvision = true
        let nonce = try AppleSignInNonce.generate()
        let session = AccountSessionCoordinator(backendFactory: { backend }, nonceFactory: { nonce })
        let request = try #require(session.beginAppleSignIn())
        #expect(request.hashedNonce == nonce.hash)
        let apple = ASAuthorizationAppleIDProvider().createRequest()
        request.configure(apple)
        #expect(apple.nonce == nonce.hash && apple.requestedScopes == [.email])
        let work = Task { await session.completeAppleSignIn(requestID: request.id, identityToken: token) }
        await waitUntil { backend.provisionReply != nil }
        #expect(session.state == .provisioning(backend.user) && !session.hasPendingAppleRequest)
        #expect(backend.received?.supabaseCredentials().nonce == nonce.raw)
        #expect(throws: AccountFoundationError.self) { try session.prepareResolvedStore() }
        backend.provisionReply?.resume(returning: backend.receipt); backend.provisionReply = nil
        await work.value
        #expect(session.state == .resolved(backend.receipt) && session.preparedStore == nil)
        #expect(backend.receipt.accountID != backend.user.userID)
        await session.completeAppleSignIn(requestID: request.id, identityToken: token)
        #expect(backend.signIns == 1 && backend.provisions == 1) // Consumed callback cannot replay.
        await session.signOut()
    }
    @Test func failedExchangeAllowsFreshAttemptWithoutProvisioning() async throws {
        let backend = AppleMockBackend(); backend.failAuth = true
        let session = AccountSessionCoordinator(backendFactory: { backend })
        let request = try #require(session.beginAppleSignIn())
        await session.completeAppleSignIn(requestID: request.id, identityToken: token)
        #expect(session.state == .signInFailed && backend.provisions == 0 && !session.hasPendingAppleRequest)
        backend.failAuth = false
        let retry = try #require(session.beginAppleSignIn())
        #expect(retry.hashedNonce != request.hashedNonce)
        await session.completeAppleSignIn(requestID: retry.id, identityToken: token)
        #expect(session.state == .resolved(backend.receipt))
        await session.signOut()
    }
    @Test func provisioningRetryKeepsAuthenticationAndRepeatedLoginSameAccount() async throws {
        let backend = AppleMockBackend(); backend.failProvision = true
        let session = AccountSessionCoordinator(backendFactory: { backend })
        let first = try #require(session.beginAppleSignIn())
        await session.completeAppleSignIn(requestID: first.id, identityToken: token)
        #expect(session.state == .retryRequired(.provision, backend.user) && backend.signIns == 1)
        backend.failProvision = false; await session.retry()
        #expect(session.state == .resolved(backend.receipt) && session.preparedStore == nil)
        await session.signOut()
        #expect(session.state == .guest && backend.identity == nil)
        let second = try #require(session.beginAppleSignIn())
        await session.completeAppleSignIn(requestID: second.id, identityToken: token)
        #expect(session.state == .resolved(backend.receipt) && backend.signIns == 2)
        #expect(backend.provisions == 3 && session.preparedStore == nil)
        await session.signOut()
    }
    @Test func signOutDrainsLateSDKExchangeAndRejectsStaleAppleCallback() async throws {
        let backend = AppleMockBackend(); backend.holdAuth = true
        var stopped = 0
        let session = AccountSessionCoordinator(backendFactory: { backend }, stopAccountWork: { stopped += 1 })
        let request = try #require(session.beginAppleSignIn())
        let signIn = Task { await session.completeAppleSignIn(requestID: request.id, identityToken: token) }
        await waitUntil { backend.authReply != nil }
        let signOut = Task { await session.signOut() }
        await waitUntil { session.isSigningOut }
        #expect(session.state == .guest && session.beginAppleSignIn() == nil)
        backend.authReply?.resume(returning: backend.user); backend.authReply = nil
        await signIn.value; await signOut.value
        #expect(session.state == .guest && !session.isSigningOut && backend.identity == nil)
        #expect(backend.signOuts == 1 && backend.provisions == 0 && stopped >= 2)
        await session.completeAppleSignIn(requestID: request.id, identityToken: token)
        #expect(backend.signIns == 1)
    }
    @Test func lateProvisionAfterSignOutCannotConnectAccount() async throws {
        let backend = AppleMockBackend(); backend.holdProvision = true
        let session = AccountSessionCoordinator(backendFactory: { backend })
        let request = try #require(session.beginAppleSignIn())
        let work = Task { await session.completeAppleSignIn(requestID: request.id, identityToken: token) }
        await waitUntil { backend.provisionReply != nil }
        await session.signOut()
        backend.provisionReply?.resume(returning: backend.receipt); backend.provisionReply = nil
        await work.value
        #expect(session.state == .guest && session.preparedStore == nil && backend.identity == nil)
    }
    @Test func startupRestoresOnceAndNeverMountsOrInitializesAccount() async {
        let backend = AppleMockBackend(); backend.identity = backend.user
        let session = AccountSessionCoordinator(backendFactory: { backend })
        #expect(session.state == .guest && backend.restores == 0)
        await session.restoreSessionOnLaunch(); await session.restoreSessionOnLaunch()
        #expect(session.state == .resolved(backend.receipt) && backend.restores == 1 && backend.provisions == 1)
        #expect(session.preparedStore == nil)
        await session.signOut(); await session.restoreSessionOnLaunch()
        #expect(session.state == .guest && backend.restores == 1)
    }
    @Test func offlineStartupFailureRetainsGuestAccessAndCanRetry() async {
        let backend = AppleMockBackend(); backend.failRestore = true
        let session = AccountSessionCoordinator(backendFactory: { backend })
        await session.restoreSessionOnLaunch()
        #expect(session.state == .retryRequired(.restoreSession, nil) && session.preparedStore == nil)
        backend.failRestore = false; await session.retry()
        #expect(session.state == .guest && backend.provisions == 0)
        await session.signOut()
    }
}
