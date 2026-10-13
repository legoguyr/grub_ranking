import Foundation
import Supabase

nonisolated struct SupabaseClientConfiguration: Equatable, Sendable {
    let projectURL: URL
    let publishableKey: String
    enum ConfigurationError: Error { case missing, invalid }
    static func load(bundle: Bundle = .main) throws -> Self {
        guard let url = bundle.url(forResource: "SupabaseClient", withExtension: "plist") else { throw ConfigurationError.missing }
        let data = try Data(contentsOf: url)
        guard let values = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else { throw ConfigurationError.invalid }
        return try validated(values)
    }
    static func validated(_ values: [String: String]) throws -> Self {
        guard Set(values.keys) == ["ProjectURL", "ProjectReference", "PublishableKey"],
              let reference = values["ProjectReference"], !reference.isEmpty,
              let url = URL(string: values["ProjectURL"] ?? ""), url.scheme == "https",
              url.host == reference + ".supabase.co", url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil, url.path.isEmpty || url.path == "/",
              let key = values["PublishableKey"], key.hasPrefix("sb_publishable_"), key.count > 15,
              key.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" })
        else { throw ConfigurationError.invalid }
        return Self(projectURL: url, publishableKey: key)
    }
}

nonisolated struct AuthenticatedIdentity: Equatable, Sendable { let userID: UUID }
nonisolated struct ProvisionedAccount: Codable, Equatable, Sendable {
    enum LibraryState: String, Codable, Sendable { case uninitialized, initialized }
    let formatVersion: Int
    let authUserID: UUID
    let accountID: UUID
    let syncRevision: Int
    let libraryState: LibraryState
    enum CodingKeys: String, CodingKey {
        case formatVersion = "format_version", authUserID = "auth_user_id", accountID = "account_id"
        case syncRevision = "sync_revision", libraryState = "library_state"
    }
    func validate(for identity: AuthenticatedIdentity) throws {
        guard formatVersion == 1, authUserID == identity.userID, accountID != authUserID, syncRevision >= 0
        else { throw AccountFoundationError.invalidResolution }
    }
}
nonisolated enum AccountFoundationError: Error { case invalidResolution, accountNotResolved, identityChanged }

/// Provider credentials are ephemeral; persistent session tokens stay inside SDK Auth storage.
@MainActor protocol AccountBackend: AnyObject {
    func signInWithApple(_ credentials: AppleSignInCredentials) async throws -> AuthenticatedIdentity
    func restoredIdentity() async throws -> AuthenticatedIdentity?
    func provision(for identity: AuthenticatedIdentity) async throws -> ProvisionedAccount
    func identityChanges() -> AsyncStream<AuthenticatedIdentity?>
    func signOutLocally() async throws
}

@MainActor final class SupabaseAccountBackend: AccountLibraryBackend {
    let client: SupabaseClient
    init(configuration: SupabaseClientConfiguration) {
        // SDK defaults persist sessions in Keychain; no custom preferences or model storage.
        client = SupabaseClient(supabaseURL: configuration.projectURL, supabaseKey: configuration.publishableKey)
    }
    func restoredIdentity() async throws -> AuthenticatedIdentity? {
        do { return AuthenticatedIdentity(userID: try await client.auth.session.user.id) }
        catch AuthError.sessionMissing { return nil }
    }
    func signInWithApple(_ credentials: AppleSignInCredentials) async throws -> AuthenticatedIdentity {
        let session = try await client.auth.signInWithIdToken(credentials: credentials.supabaseCredentials())
        return AuthenticatedIdentity(userID: session.user.id)
    }
    func provision(for identity: AuthenticatedIdentity) async throws -> ProvisionedAccount {
        guard client.auth.currentSession?.user.id == identity.userID else { throw AccountFoundationError.identityChanged }
        // There are deliberately no RPC identity/owner parameters.
        let account: ProvisionedAccount = try await client.schema("api").rpc("provision_account").execute().value
        try account.validate(for: identity)
        guard client.auth.currentSession?.user.id == identity.userID else { throw AccountFoundationError.identityChanged }
        return account
    }
    func identityChanges() -> AsyncStream<AuthenticatedIdentity?> {
        let auth = client.auth
        return AsyncStream { continuation in
            let task = Task {
                for await _ in auth.authStateChanges {
                    guard !Task.isCancelled else { break }
                    // Initial/refresh callbacks can finish late. Read the SDK's
                    // current identity rather than routing from a queued payload.
                    continuation.yield(auth.currentSession.map { AuthenticatedIdentity(userID: $0.user.id) })
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
    func openLibrary(for account: ProvisionedAccount) async throws -> AccountLibrarySnapshot {
        guard client.auth.currentSession?.user.id == account.authUserID else { throw AccountFoundationError.identityChanged }
        let response = try await client.schema("api").rpc("open_account_library").execute()
        // Graph dates use Swift reference-date numbers; do not use SDK ISO date decoding.
        let snapshot = try JSONDecoder().decode(AccountLibrarySnapshot.self, from: response.data)
        try snapshot.validate(for: account)
        guard client.auth.currentSession?.user.id == account.authUserID else { throw AccountFoundationError.identityChanged }
        return snapshot
    }
    func rememberReadyAccount(_ account: ProvisionedAccount) throws { try VerifiedAccountCache.save(account) }
    func offlineAccount(for identity: AuthenticatedIdentity) throws -> ProvisionedAccount? {
        guard let session = client.auth.currentSession, !session.isExpired, session.user.id == identity.userID else { return nil }
        return try VerifiedAccountCache.load(identity)
    }
    func signOutLocally() async throws {
        if let user = client.auth.currentSession?.user.id { VerifiedAccountCache.remove(AuthenticatedIdentity(userID: user)) }
        // In this pinned SDK, local session removal precedes the logout network request.
        try await client.auth.signOut(scope: .local)
    }
}
