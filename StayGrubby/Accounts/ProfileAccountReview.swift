#if DEBUG
import SwiftUI
import SwiftData

/// Explicit UI-test harness for Profile only. Both the UUID review store and
/// flag are required; account/auth/sync services outside this subtree are never
/// replaced. The entire harness is absent from Release.
@MainActor struct ProfileAccountReview: View {
    static var requested: Bool {
        DebugReviewConfiguration.current.storeID != nil &&
            ProcessInfo.processInfo.arguments.contains("--profile-account-review")
    }
    @State private var fixture: Fixture?
    @State private var failed = false

    var body: some View {
        Group {
            if let fixture {
                AccountView()
                    .environment(fixture.session)
                    .environment(\.endDevelopmentReview, nil)
                    .environment(\.cookingSyncCoordinator, fixture.sync)
                    .modelContainer(fixture.store.container)
                    .safeAreaInset(edge: .bottom) {
                        Text(fixture.backend.signOuts > 0 ? "Review signed out" : "Review sync reads: \(fixture.cloud.reads)")
                            .font(.caption).accessibilityIdentifier("profile-review-status")
                    }
            } else if failed {
                Text("Couldn't open isolated Profile review")
            } else { ProgressView("Opening isolated Profile review") }
        }
        .task {
            guard fixture == nil else { return }
            do { fixture = try await Fixture.open() }
            catch { failed = true }
        }
        .onDisappear { fixture?.sync.disconnect() }
    }

    @MainActor @Observable fileprivate final class Backend: AccountBackend {
        let account = ProvisionedAccount(formatVersion: 1, authUserID: UUID(), accountID: UUID(),
                                         syncRevision: 0, libraryState: .initialized)
        var signOuts = 0
        func restoredIdentity() async throws -> AuthenticatedIdentity? { .init(userID: account.authUserID) }
        func provision(for identity: AuthenticatedIdentity) async throws -> ProvisionedAccount { account }
        func identityChanges() -> AsyncStream<AuthenticatedIdentity?> { AsyncStream { _ in } }
        func signInWithApple(_ credentials: AppleSignInCredentials) async throws -> AuthenticatedIdentity {
            throw URLError(.unsupportedURL)
        }
        func signOutLocally() async throws { signOuts += 1 }
    }
    @MainActor @Observable fileprivate final class Cloud { var reads = 0 }

    @MainActor private final class Fixture {
        let backend: Backend
        let session: AccountSessionCoordinator
        let sync = CookingSyncCoordinator()
        let store: LocalStoreSession
        let cloud = Cloud()
        private init(backend: Backend, session: AccountSessionCoordinator, store: LocalStoreSession) {
            self.backend = backend; self.session = session; self.store = store
        }
        static func open() async throws -> Fixture {
            guard requested, let id = DebugReviewConfiguration.current.storeID else {
                throw AccountFoundationError.accountNotResolved
            }
            let backend = Backend(), session = AccountSessionCoordinator(backendFactory: { backend })
            await session.restoreSession()
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("profile-account-review-\(id)")
            let store = try session.prepareResolvedStore(root: root)
            try store.initializeVerifiedEmptyAccount(); _ = try store.prepare()
            try SyncJournal.enable(store.container.mainContext)
            let snapshot = AccountLibrarySnapshot(account: backend.account,
                graph: try CookingGraphExport.snapshot(context: store.container.mainContext))
            let fixture = Fixture(backend: backend, session: session, store: store)
            let pending = ProcessInfo.processInfo.arguments.contains("--profile-sync-pending")
            try fixture.sync.connect(store: store, account: backend.account,
                send: { _ in throw URLError(.unsupportedURL) },
                load: { [cloud = fixture.cloud] in
                    cloud.reads += 1
                    if pending { throw URLError(.notConnectedToInternet) }
                    return snapshot
                })
            return fixture
        }
    }
}
#endif
