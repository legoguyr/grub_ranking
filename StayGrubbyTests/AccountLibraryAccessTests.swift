import Foundation
import SwiftData
import Testing
@testable import StayGrubby

@MainActor struct AccountLibraryAccessTests {
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("account-gate-\(UUID())") }
    private func receipt(_ account: UUID = UUID(), user: UUID = UUID(), revision: Int = 1) -> ProvisionedAccount {
        ProvisionedAccount(formatVersion:1,authUserID:user,accountID:account,syncRevision:revision,libraryState:.initialized)
    }
    private func empty(_ account: ProvisionedAccount) throws -> AccountLibrarySnapshot {
        let id = UUID()
        let json = """
        {"formatVersion":1,"accountID":"\(account.accountID)","deletions":[],"libraries":[{"key":"local","globalRankingID":"\(id)","bridgeVersion":1}],"rankings":[{"id":"\(id)","name":"My Cooking","createdAt":1000}],"dishes":[],"attempts":[],"items":[],"comparisons":[],"sources":[],"tags":[],"media":[],"legacyItemDates":[]}
        """
        return AccountLibrarySnapshot(account:account,graph:try CookingGraph.decode(Data(json.utf8)))
    }
    @Test func resolvedAccountAloneDoesNotGrantAccess() throws {
        let access = AccountLibraryAccess(), account = receipt()
        #expect(!access.isReady(for:account) && access.store == nil)
    }
    @Test func newAccountHydratesOnlyOneEmptyRankingAndNoDemoMedia() async throws {
        let access = AccountLibraryAccess(), account = receipt(), base = root(), snapshot = try empty(account)
        defer { try? FileManager.default.removeItem(at:base) }
        await access.prepare(account,root:base,load:{snapshot})
        #expect(access.isReady(for:account) && !access.failed)
        let store = try #require(access.store), context = store.container.mainContext
        #expect(try context.fetchCount(FetchDescriptor<RankingList>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<CookingLibrary>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Dish>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<CookingAttempt>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<RankedItem>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Comparison>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<CookingMedia>()) == 0)
        #expect(store.scope == .account(account.accountID) && store.mediaRoot != nil)
        #expect(try SyncJournal.binding(context)?.restorationRequired == false)
        #expect(try SyncJournal.pending(context).isEmpty)
        #expect(!FileManager.default.fileExists(atPath:base.appendingPathComponent("default.store").path))
        #expect(!FileManager.default.fileExists(atPath:store.mediaRoot!.appendingPathComponent("StayGrubbyMedia").path))
    }
    @Test func existingSnapshotRestoresIdentityAndEvidenceRatherThanStartingEmpty() async throws {
        let base = root(), account = receipt(), access = AccountLibraryAccess()
        defer { try? FileManager.default.removeItem(at:base) }
        let source = try ModelContainer(for:AppPersistence.schema,configurations:[ModelConfiguration(isStoredInMemoryOnly:true)])
        source.mainContext.insert(SyncStoreBinding(accountID:account.accountID,restorationRequired:false));try source.mainContext.save()
        let list = try CookingStore.prepare(context:source.mainContext)
        var draft = CookingDraft();draft.dishName="Existing personal recipe"
        let engine = RankingEngine(itemID:UUID(),orderedIDs:[],reaction:.liked)
        _ = try CookingStore.create(draft:draft,existingDish:nil,session:engine,context:source.mainContext)
        let graph = try CookingGraphExport.snapshot(context:source.mainContext)
        let snapshot = AccountLibrarySnapshot(account:account,graph:graph)
        await access.prepare(account,root:base,load:{snapshot})
        let store = try #require(access.store)
        #expect(try CookingGraphExport.snapshot(context:store.container.mainContext) == graph)
        #expect(try store.prepare().id == list.id)
        #expect(try store.container.mainContext.fetchCount(FetchDescriptor<Dish>()) == 1)
        #expect(!access.isReady(for:receipt(user:account.authUserID)))
    }
    @Test func setupFailureNeverMountsPartialOrDemoStore() async {
        let access = AccountLibraryAccess(), account = receipt()
        await access.prepare(account,root:root(),load:{throw URLError(.notConnectedToInternet)})
        #expect(access.failed && access.store == nil && !access.isReady(for:account))
    }
    @Test func wrongAccountSnapshotRejectedBeforeSelectingAnyStore() async throws {
        let access = AccountLibraryAccess(), account = receipt(), wrong = try empty(receipt()), base=root()
        await access.prepare(account,root:base,load:{wrong})
        #expect(access.failed && access.store == nil)
        #expect(!FileManager.default.fileExists(atPath:base.path))
    }
    @Test func resetDiscardsDelayedSetupReply() async throws {
        let access = AccountLibraryAccess(), account = receipt(), snapshot = try empty(account), base=root()
        var continuation: CheckedContinuation<AccountLibrarySnapshot,Never>?
        let work = Task { await access.prepare(account,root:base,load:{await withCheckedContinuation { continuation=$0 }}) }
        for _ in 0..<100 { if continuation != nil { break };await Task.yield() }
        access.reset();continuation?.resume(returning:snapshot);await work.value
        #expect(access.store == nil && !access.isReady(for:account))
        #expect(!FileManager.default.fileExists(atPath:base.path))
    }
    @Test func offlineRequiresPreviouslyReadyAccountAndKeepsLocalEdits() async throws {
        let base=root(), account=receipt(), snapshot=try empty(account), access=AccountLibraryAccess()
        defer { try? FileManager.default.removeItem(at:base) }
        await access.prepare(account,root:base,load:{snapshot})
        let store=try #require(access.store), context=store.container.mainContext
        var draft=CookingDraft();draft.dishName="Offline personal recipe"
        _ = try CookingStore.create(draft:draft,existingDish:nil,session:RankingEngine(itemID:UUID(),orderedIDs:[],reaction:.liked),context:context)
        let before=try CookingGraphExport.snapshot(context:context)
        #expect(try SyncJournal.pending(context).count == 1)
        access.reset()
        await access.prepare(account,root:base,offline:true,load:{Issue.record("Offline path must not load network");return snapshot})
        #expect(access.offline && access.isReady(for:account))
        #expect(try CookingGraphExport.snapshot(context:access.store!.container.mainContext) == before)
        await access.prepare(account,root:base,load:{snapshot})
        #expect(access.isReady(for:account))
        #expect(try CookingGraphExport.snapshot(context:access.store!.container.mainContext) == before)
        await access.prepare(receipt(),root:base,offline:true,load:{snapshot})
        #expect(access.failed && access.store == nil)
    }
    @Test func networkFailureClassifierDoesNotTreatAuthDenialAsOffline() {
        #expect(isOfflineConnectionError(URLError(.notConnectedToInternet)))
        #expect(!isOfflineConnectionError(URLError(.userAuthenticationRequired)))
        #expect(!isOfflineConnectionError(AccountFoundationError.invalidResolution))
    }
    #if DEBUG
    @Test func developmentLaunchRequiresExplicitFixtureOrFlag() {
        var backendCreations=0
        let session=AccountSessionCoordinator(backendFactory:{ backendCreations += 1;throw URLError(.notConnectedToInternet) })
        #expect(session.beginDevelopmentReview())
        #expect(backendCreations == 0 && session.preparedStore == nil && session.state == .guest)
        #expect(DebugReviewConfiguration(arguments:[]).storeID == nil)
        #expect(DebugReviewConfiguration(arguments:["--ui-test-store","invalid"]).storeID == nil)
    }
    #endif
}

@MainActor private final class OfflineResolutionBackend: AccountLibraryBackend {
    let identity = AuthenticatedIdentity(userID:UUID())
    let owner = UUID()
    var cached: ProvisionedAccount?
    var denied = false
    var reads = 0, provisions = 0
    func signInWithApple(_ credentials:AppleSignInCredentials) async throws -> AuthenticatedIdentity { identity }
    func restoredIdentity() async throws -> AuthenticatedIdentity? { reads += 1;return identity }
    func provision(for identity:AuthenticatedIdentity) async throws -> ProvisionedAccount {
        provisions += 1
        if denied { throw AccountFoundationError.invalidResolution }
        throw URLError(.notConnectedToInternet)
    }
    func identityChanges() -> AsyncStream<AuthenticatedIdentity?> { AsyncStream { _ in } }
    func signOutLocally() async throws { cached=nil }
    func offlineAccount(for identity:AuthenticatedIdentity) throws -> ProvisionedAccount? { cached }
    func rememberReadyAccount(_ account:ProvisionedAccount) throws { cached=account }
    func openLibrary(for account:ProvisionedAccount) async throws -> AccountLibrarySnapshot { throw URLError(.notConnectedToInternet) }
}

@MainActor struct OfflineAccountGateTests {
    @Test func offlineRestorationNeedsVerifiedMatchingReadyMapping() async {
        let backend=OfflineResolutionBackend(), session=AccountSessionCoordinator(backendFactory:{backend})
        await session.restoreSession()
        #expect(session.state == .retryRequired(.provision,backend.identity) && !session.offlineResolution)
        backend.cached=ProvisionedAccount(formatVersion:1,authUserID:backend.identity.userID,accountID:backend.owner,syncRevision:1,libraryState:.initialized)
        await session.retry()
        #expect(session.state == .resolved(backend.cached!) && session.offlineResolution)
        #expect(session.preparedStore == nil) // Cache alone still cannot mount a library.
        await session.signOut()
        #expect(session.state == .guest && !session.offlineResolution && backend.cached == nil)
    }
    @Test func authDenialAndWrongCachedOwnerCannotUnlockOffline() async {
        let backend=OfflineResolutionBackend(), session=AccountSessionCoordinator(backendFactory:{backend})
        backend.cached=ProvisionedAccount(formatVersion:1,authUserID:UUID(),accountID:backend.owner,syncRevision:1,libraryState:.initialized)
        await session.restoreSession()
        #expect(!session.offlineResolution)
        backend.cached=ProvisionedAccount(formatVersion:1,authUserID:backend.identity.userID,accountID:backend.owner,syncRevision:1,libraryState:.initialized)
        backend.denied=true;await session.retry()
        #expect(!session.offlineResolution && session.state == .retryRequired(.provision,backend.identity))
        await session.signOut()
    }
}
