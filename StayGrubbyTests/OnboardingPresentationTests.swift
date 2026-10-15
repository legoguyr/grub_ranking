import Foundation
import Testing
@testable import StayGrubby

struct OnboardingPresentationTests {
    private let identity = AuthenticatedIdentity(userID: UUID())
    private var account: ProvisionedAccount {
        .init(formatVersion: 1, authUserID: identity.userID, accountID: UUID(), syncRevision: 1, libraryState: .initialized)
    }
    private func presentation(_ state: AccountSessionState, failed: Bool = false, signingOut: Bool = false) -> AuthenticationGatePresentation {
        .init(state: state, setupFailed: failed, isSigningOut: signingOut)
    }

    @Test func signedOutAndFailedSignInKeepAppleAsRecoveryPath() {
        let welcome = presentation(.guest)
        #expect(!welcome.isWorking && !welcome.isError && welcome.retry == nil && welcome.signOutTitle == nil)
        let failed = presentation(.signInFailed)
        #expect(failed.isError && !failed.isWorking && failed.retry == nil)
        #expect(failed.message.contains("Sign in with Apple"))
    }

    @Test func everyPendingPhaseShowsProgressWithoutPrematureRetry() {
        for state in [AccountSessionState.authorizingApple, .authenticating, .loadingSession, .provisioning(identity), .resolved(account)] {
            let value = presentation(state)
            #expect(value.isWorking && !value.isError && value.retry == nil)
        }
        #expect(presentation(.authorizingApple).signOutTitle == nil)
        #expect(presentation(.authenticating).signOutTitle == "Cancel sign-in")
    }

    @Test func recoveryTargetsTheFailingStage() {
        let restore = presentation(.retryRequired(.restoreSession, nil))
        let setup = presentation(.retryRequired(.provision, identity))
        let library = presentation(.resolved(account), failed: true)
        #expect(restore.retry == .account && setup.retry == .account && library.retry == .library)
        #expect(restore.title != setup.title)
        for value in [restore, setup, library] {
            #expect(value.isError && !value.isWorking && value.signOutTitle == "Sign out")
        }
        // A stale library failure cannot override an earlier authentication phase.
        #expect(presentation(.guest, failed: true).retry == nil)
        #expect(presentation(.provisioning(identity), failed: true).isWorking)
    }

    @Test func signOutCleanupTakesPriorityOverAllOtherPresentation() {
        for state in [AccountSessionState.guest, .signInFailed, .authorizingApple, .authenticating,
                      .loadingSession, .provisioning(identity), .retryRequired(.provision, identity), .resolved(account)] {
            let value = presentation(state, failed: true, signingOut: true)
            #expect(value.title == "Signing out…" && value.isWorking)
            #expect(!value.isError && value.retry == nil && value.signOutTitle == nil)
        }
    }

    @MainActor @Test func presentationHasNoAuthenticationOrLibrarySideEffects() {
        var backendCreations = 0
        let session = AccountSessionCoordinator(backendFactory: {
            backendCreations += 1
            throw URLError(.notConnectedToInternet)
        })
        _ = presentation(session.state, failed: true)
        #expect(backendCreations == 0 && session.state == .guest && session.preparedStore == nil)
        #expect(!AccountLibraryAccess().isReady(for: account))
    }

    @MainActor @Test func libraryRetryStaysGatedUntilTheExactAccountStoreIsReady() async throws {
        let account = account, access = AccountLibraryAccess()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("onboarding-readiness-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        await access.prepare(account, root: root, load: { throw URLError(.notConnectedToInternet) })
        #expect(access.failed && !access.isReady(for: account) && access.store == nil)
        #expect(presentation(.resolved(account), failed: access.failed).retry == .library)

        let rankingID = UUID()
        let json = """
        {"formatVersion":1,"accountID":"\(account.accountID)","deletions":[],"libraries":[{"key":"local","globalRankingID":"\(rankingID)","bridgeVersion":1}],"rankings":[{"id":"\(rankingID)","name":"My Cooking","createdAt":1000}],"dishes":[],"attempts":[],"items":[],"comparisons":[],"sources":[],"tags":[],"media":[],"legacyItemDates":[]}
        """
        let snapshot = AccountLibrarySnapshot(account: account, graph: try CookingGraph.decode(Data(json.utf8)))
        var reply: CheckedContinuation<AccountLibrarySnapshot, Never>?
        let retry = Task {
            await access.prepare(account, root: root, load: {
                await withCheckedContinuation { reply = $0 }
            })
        }
        for _ in 0..<500 { if reply != nil { break }; await Task.yield() }
        #expect(reply != nil)
        #expect(!access.failed && !access.isReady(for: account) && access.store == nil)
        #expect(presentation(.resolved(account), failed: access.failed).isWorking)
        reply?.resume(returning: snapshot)
        await retry.value
        #expect(access.isReady(for: account) && !access.failed)
        #expect(access.store?.scope == .account(account.accountID))
        access.reset()
        #expect(!access.isReady(for: account) && access.store == nil)
    }

}
