import Foundation
import Testing
@testable import StayGrubby

@MainActor private final class DelayedSocialBackend: SocialBackend {
    let account = ProvisionedAccount(formatVersion: 1, authUserID: UUID(), accountID: UUID(), syncRevision: 0, libraryState: .initialized)
    var response: CheckedContinuation<Data, Never>?
    func restoredIdentity() async throws -> AuthenticatedIdentity? { .init(userID: account.authUserID) }
    func provision(for identity: AuthenticatedIdentity) async throws -> ProvisionedAccount { account }
    func identityChanges() -> AsyncStream<AuthenticatedIdentity?> { AsyncStream { _ in } }
    func signInWithApple(_ credentials: AppleSignInCredentials) async throws -> AuthenticatedIdentity { throw URLError(.unsupportedURL) }
    func signOutLocally() async throws {}
    func socialRequest(endpoint: String, action: String, payload: SocialPayload) async throws -> Data {
        await withCheckedContinuation { response = $0 }
    }
}
@MainActor struct SocialSessionTests {
    @Test func signedOutAccountCannotReceivePriorSocialReply() async throws {
        let backend = DelayedSocialBackend(), session = AccountSessionCoordinator(backendFactory: { backend })
        await session.restoreSession()
        let request = Task { try await session.performSocialRequest(endpoint: "social_people", action: "friends", payload: .init()) }
        for _ in 0..<100 where backend.response == nil { await Task.yield() }
        let response = try #require(backend.response)
        await session.signOut()
        response.resume(returning: Data(#"{"people":[]}"#.utf8)); backend.response = nil
        await #expect(throws: AccountFoundationError.identityChanged) { try await request.value }
    }
}
