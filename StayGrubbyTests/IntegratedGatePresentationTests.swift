#if DEBUG
import XCTest
import SwiftUI
import UIKit
@testable import StayGrubby

/// Render the integrated recovery UI using only a disposable backend. No Apple
/// request, network service, account store or development-library bypass runs.
final class IntegratedGatePresentationTests: XCTestCase {
    @MainActor func testPendingRecoveryAndLibraryFailureRemainGated() async throws {
        let backend = GateBackend()
        let session = AccountSessionCoordinator(backendFactory: { backend })
        let restore = Task { await session.restoreSession() }
        for _ in 0..<100 {
            if backend.pending != nil { break }
            await Task.yield()
        }
        XCTAssertNotNil(backend.pending)
        XCTAssertEqual(session.state, .loadingSession)
        try await capture("Integrated gate - restoring light", session, appearance: .light)
        XCTAssertNil(session.preparedStore)

        backend.pending?.resume(throwing: URLError(.notConnectedToInternet))
        backend.pending = nil
        await restore.value
        XCTAssertEqual(session.state, .retryRequired(.restoreSession, nil))
        try await capture("Integrated gate - retry dark", session, appearance: .dark)
        XCTAssertNil(session.preparedStore)

        backend.hold = false
        await session.retry()
        guard case .resolved(let account) = session.state else {
            XCTFail("Retry did not resolve the synthetic account")
            return
        }
        let access = AccountLibraryAccess()
        XCTAssertFalse(access.isReady(for: account))
        try await capture("Integrated gate - waiting for library light", session, appearance: .light)
        try await capture("Integrated gate - library recovery dark", session, appearance: .dark, failed: true)
        XCTAssertFalse(access.isReady(for: account))
        XCTAssertNil(session.preparedStore)
        XCTAssertEqual(backend.reads, 2)
        XCTAssertEqual(backend.provisions, 1)
        await session.signOut()
        XCTAssertEqual(session.state, .guest)
        try await capture("Integrated gate - sign out returns to Apple", session, appearance: .light)
    }

    @MainActor private func capture(_ name: String, _ session: AccountSessionCoordinator,
                                    appearance: ColorScheme, failed: Bool = false) async throws {
        let before = session.state
        let view = AuthenticationGateView(setupFailed: failed, retrySetup: {})
            .environment(session).preferredColorScheme(appearance)
        let controller = UIHostingController(rootView: view)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.effectiveGeometry.coordinateSpace.bounds
        window.overrideUserInterfaceStyle = appearance == .light ? .light : .dark
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(250))
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        XCTAssertEqual(image.size, window.bounds.size)
        XCTAssertEqual(session.state, before, "Rendering must never advance account access")
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

@MainActor private final class GateBackend: AccountBackend {
    let identity = AuthenticatedIdentity(userID: UUID())
    var hold = true
    var reads = 0
    var provisions = 0
    var pending: CheckedContinuation<AuthenticatedIdentity?, Error>?
    func restoredIdentity() async throws -> AuthenticatedIdentity? {
        reads += 1
        if hold { return try await withCheckedThrowingContinuation { pending = $0 } }
        return identity
    }
    func provision(for identity: AuthenticatedIdentity) async throws -> ProvisionedAccount {
        provisions += 1
        return .init(formatVersion: 1, authUserID: identity.userID, accountID: UUID(),
                     syncRevision: 0, libraryState: .initialized)
    }
    func identityChanges() -> AsyncStream<AuthenticatedIdentity?> { AsyncStream { _ in } }
    func signInWithApple(_ credentials: AppleSignInCredentials) async throws -> AuthenticatedIdentity {
        throw URLError(.unsupportedURL)
    }
    func signOutLocally() async throws {}
}
#endif
