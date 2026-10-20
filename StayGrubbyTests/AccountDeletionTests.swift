import Foundation
import Testing
@testable import StayGrubby

@MainActor private final class DeletionMockBackend: AccountDeletionBackend {
    let identity: AuthenticatedIdentity
    let account: ProvisionedAccount
    var pendingStatus = false
    var provisionFails = false
    var deleteFails = false
    var replacementIdentity: AuthenticatedIdentity?
    var deletionCalls = 0
    var signOuts = 0

    init() {
        identity = AuthenticatedIdentity(userID: UUID())
        account = ProvisionedAccount(formatVersion: 1, authUserID: identity.userID,
            accountID: UUID(), syncRevision: 1, libraryState: .initialized)
    }
    func signInWithApple(_ credentials: AppleSignInCredentials) async throws -> AuthenticatedIdentity {
        replacementIdentity ?? identity
    }
    func restoredIdentity() async throws -> AuthenticatedIdentity? { identity }
    func provision(for identity: AuthenticatedIdentity) async throws -> ProvisionedAccount {
        if provisionFails { throw URLError(.cannotConnectToHost) }
        return account
    }
    func identityChanges() -> AsyncStream<AuthenticatedIdentity?> { AsyncStream { _ in } }
    func signOutLocally() async throws { signOuts += 1 }
    func accountDeletionStatus() async throws -> AccountDeletionStatus {
        .init(pending: pendingStatus, accountID: pendingStatus ? account.accountID : nil,
              state: pendingStatus ? "requested" : nil)
    }
    func deleteCurrentAccount(authorizationCode: String) async throws {
        deletionCalls += 1
        #expect(authorizationCode == "valid-authorization-code")
        if deleteFails { throw URLError(.cannotConnectToHost) }
    }
}

@Suite(.serialized) @MainActor struct AccountDeletionTests {
    private let token = Data("eyJhbGciOiJub25lIn0.eyJzdWIiOiIxIn0.signature".utf8)
    private let code = Data("valid-authorization-code".utf8)

    private func resolved(_ backend: DeletionMockBackend) async -> AccountSessionCoordinator {
        let session = AccountSessionCoordinator(backendFactory: { backend })
        await session.restoreSession()
        return session
    }

    @Test func cancellationDoesNotDeleteOrEndSession() async {
        let backend = DeletionMockBackend(), session = await resolved(backend)
        session.requestAccountDeletion()
        let request = try! #require(session.beginAccountDeletionAuthorization())
        session.accountDeletionAuthorizationFailed(requestID: request.id, cancelled: true)
        #expect(session.deletionProgress == .needsAuthorization)
        #expect(backend.deletionCalls == 0)
        #expect(session.state == .resolved(backend.account))
    }

    @Test func failureNeverClaimsSuccessOrClearsLocalAccount() async {
        let backend = DeletionMockBackend(); backend.deleteFails = true
        let session = await resolved(backend)
        session.requestAccountDeletion()
        let request = try! #require(session.beginAccountDeletionAuthorization())
        await session.completeAccountDeletion(requestID: request.id, identityToken: token, authorizationCode: code)
        #expect(session.deletionProgress == .failed)
        #expect(session.state == .resolved(backend.account))
        #expect(session.pendingLocalDeletionAccountID == nil)
        #expect(backend.deletionCalls == 1 && backend.signOuts == 0)
    }

    @Test func mismatchedAppleIdentityCannotDeleteAccount() async {
        let backend = DeletionMockBackend(); backend.replacementIdentity = .init(userID: UUID())
        let session = await resolved(backend)
        session.requestAccountDeletion()
        let request = try! #require(session.beginAccountDeletionAuthorization())
        await session.completeAccountDeletion(requestID: request.id, identityToken: token, authorizationCode: code)
        #expect(session.deletionProgress == .failed && backend.deletionCalls == 0)
        #expect(session.state == .resolved(backend.account))
    }

    @Test func successReturnsToAuthenticationAndQueuesDurableLocalCleanup() async {
        let backend = DeletionMockBackend(), session = await resolved(backend)
        defer { AccountDeletionCleanupJournal.clear(backend.account.accountID) }
        session.requestAccountDeletion()
        let request = try! #require(session.beginAccountDeletionAuthorization())
        await session.completeAccountDeletion(requestID: request.id, identityToken: token, authorizationCode: code)
        #expect(session.state == .guest && session.deletionProgress == .idle)
        #expect(session.pendingLocalDeletionAccountID == backend.account.accountID)
        #expect(AccountDeletionCleanupJournal.pendingAccountID == backend.account.accountID)
        #expect(backend.deletionCalls == 1 && backend.signOuts == 1)
    }

    @Test func interruptedServerDeletionIsDetectedOnRelaunch() async {
        let backend = DeletionMockBackend(); backend.provisionFails = true; backend.pendingStatus = true
        let session = AccountSessionCoordinator(backendFactory: { backend })
        await session.restoreSession()
        #expect(session.state == .deletionRequired(backend.identity, backend.account.accountID))
        #expect(session.deletionProgress == .needsAuthorization)
    }

    @Test func localCleanupRemovesOnlyExactAccountDirectory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("deletion-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let target = UUID(), sibling = UUID()
        let targetDirectory = LocalAccountDataDeletion.directory(for: target, root: root)
        let siblingDirectory = LocalAccountDataDeletion.directory(for: sibling, root: root)
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: siblingDirectory, withIntermediateDirectories: true)
        try Data("private".utf8).write(to: targetDirectory.appendingPathComponent("cooking.store"))
        try Data("keep".utf8).write(to: siblingDirectory.appendingPathComponent("cooking.store"))
        try LocalAccountDataDeletion.remove(target, root: root)
        #expect(!FileManager.default.fileExists(atPath: targetDirectory.path))
        #expect(FileManager.default.fileExists(atPath: siblingDirectory.path))
    }

    @Test func bundledPrivacyPolicyMatchesCurrentPrivateProduct() throws {
        let text = try #require(PrivacyPolicyDocument.text())
        #expect(text.contains("private cooking journal"))
        #expect(text.contains("does not currently include a conventional analytics SDK or advertising SDK"))
        #expect(text.contains("Effective date: October 20, 2026"))
        #expect(text.contains("privacy@staygrubby.com"))
        #expect(text.contains("support@staygrubby.com"))
        #expect(text.contains(PrivacyPolicyDocument.publicURL.absoluteString))
        #expect(PrivacyPolicyDocument.publicURL.absoluteString == "https://staygrubby.com/privacy")
    }
}
