import Foundation
import SwiftData
import Testing
import UIKit
@testable import StayGrubby

@MainActor private final class PhotoCloud: CookingPhotoTransport {
    var graph: CookingGraph
    var revision = 1
    var manifests: [UUID: CookingPhotoManifest] = [:]
    var objects: [String: Data] = [:]
    var offline = false
    var loseUploadReply = false
    var loseCompleteReply = false
    var corruptDownload = false
    var wrongOwner = false
    var beforeReply: (() throws -> Void)?
    var uploads = 0
    var downloads = 0
    var failDownloadAt: Int?
    var removals = 0
    var registrations = 0
    init(_ graph: CookingGraph) { self.graph = graph }
    func apply(_ envelope: SyncEnvelope) throws -> SyncReceipt {
        guard envelope.accountID == graph.accountID else { throw CookingSyncError.rejected }
        guard !offline else { throw CookingSyncError.unavailable }
        guard envelope.expectedRevision == revision else { throw CookingSyncError.conflict }
        graph = try JSONDecoder().decode(SyncChanges.self, from: envelope.payload).applying(to: graph)
        revision += 1
        return SyncReceipt(operationID: envelope.operationID, revision: revision)
    }
    func catalog(action: String, manifest: CookingPhotoManifest?) async throws -> CookingPhotoCatalog {
        guard !offline else { throw CookingPhotoError.unavailable }
        if action == "register", let manifest {
            try manifest.validate(owner: graph.accountID!)
            guard graph.media.contains(where: { $0.id == manifest.mediaID }) else { throw CookingPhotoError.obsolete }
            if let prior = manifests[manifest.mediaID], !prior.sameContent(as: manifest) { throw CookingPhotoError.integrity }
            manifests[manifest.mediaID] = manifests[manifest.mediaID] ?? manifest; registrations += 1
        }
        if action == "complete", let manifest {
            guard objects[manifest.displayKey]?.count == manifest.displayBytes,
                  objects[manifest.thumbnailKey]?.count == manifest.thumbnailBytes else { throw CookingPhotoError.pending }
            manifests[manifest.mediaID]?.state = "ready"
            if loseCompleteReply { loseCompleteReply = false; throw CookingPhotoError.unavailable }
        }
        if action == "cleaned", let manifest {
            guard !graph.media.contains(where: { $0.id == manifest.mediaID }),
                  objects[manifest.displayKey] == nil, objects[manifest.thumbnailKey] == nil else { throw CookingPhotoError.pending }
            manifests.removeValue(forKey: manifest.mediaID)
        }
        let entries = manifests.values.map { original in
            var value = original
            if !graph.media.contains(where: { $0.id == value.mediaID }) { value.state = "deleted" }
            return value
        }
        return CookingPhotoCatalog(accountID: wrongOwner ? UUID() : graph.accountID!, backups: entries)
    }
    func upload(path: String, bytes: Data) async throws {
        guard !offline else { throw CookingPhotoError.unavailable }
        guard manifests.values.contains(where: { manifest in graph.media.contains(where: { $0.id == manifest.mediaID }) && [manifest.displayKey,manifest.thumbnailKey].contains(path) }) else { throw CookingPhotoError.rejected }
        objects[path] = bytes; uploads += 1
        try beforeReply?()
        if loseUploadReply { loseUploadReply = false; throw CookingPhotoError.unavailable }
    }
    func download(path: String) async throws -> Data {
        guard !offline else { throw CookingPhotoError.unavailable }
        downloads += 1
        if failDownloadAt == downloads { throw CookingPhotoError.unavailable }
        guard let bytes = objects[path] else { throw CookingPhotoError.pending }
        try beforeReply?()
        return corruptDownload ? Data(bytes.dropLast()) : bytes
    }
    func remove(paths: [String]) async throws {
        guard !offline else { throw CookingPhotoError.unavailable }
        for path in paths { objects.removeValue(forKey: path) }; removals += 1
    }
    func snapshot(user: UUID) -> AccountLibrarySnapshot {
        .init(account: .init(formatVersion: 1, authUserID: user, accountID: graph.accountID!, syncRevision: revision, libraryState: .initialized), graph: graph)
    }
}

@MainActor private final class PhotoAccountBackend: AccountPhotoBackend {
    let cloud: PhotoCloud
    let account: ProvisionedAccount
    var signedIn = true
    var duringDownload: (() async -> Void)?
    init(cloud: PhotoCloud, account: ProvisionedAccount) { self.cloud=cloud;self.account=account }
    func signInWithApple(_ credentials: AppleSignInCredentials) async throws -> AuthenticatedIdentity { throw CookingPhotoError.rejected }
    func restoredIdentity() async throws -> AuthenticatedIdentity? { signedIn ? .init(userID: account.authUserID) : nil }
    func provision(for identity: AuthenticatedIdentity) async throws -> ProvisionedAccount { account }
    func identityChanges() -> AsyncStream<AuthenticatedIdentity?> { AsyncStream { _ in } }
    func signOutLocally() async throws { signedIn=false }
    func openLibrary(for account: ProvisionedAccount) async throws -> AccountLibrarySnapshot { cloud.snapshot(user: account.authUserID) }
    func rememberReadyAccount(_ account: ProvisionedAccount) throws { }
    func offlineAccount(for identity: AuthenticatedIdentity) throws -> ProvisionedAccount? { nil }
    func photoCatalog(action: String, manifest: CookingPhotoManifest?) async throws -> CookingPhotoCatalog { try await cloud.catalog(action: action,manifest: manifest) }
    func uploadPhoto(path: String, bytes: Data) async throws { try await cloud.upload(path:path,bytes:bytes) }
    func downloadPhoto(path: String) async throws -> Data { await duringDownload?();return try await cloud.download(path:path) }
    func removePhotos(paths: [String]) async throws { try await cloud.remove(paths:paths) }
}

@MainActor struct CookingPhotoSyncTests {
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("photo-sync-test-\(UUID())") }
    private func setup(root: URL) throws -> (LocalStoreSession, PhotoCloud, ProvisionedAccount) {
        let owner = UUID(), user = UUID(), ranking = UUID()
        let graph = try CookingGraph.decode(Data("""
        {"formatVersion":1,"accountID":"\(owner)","deletions":[],"libraries":[{"key":"local","globalRankingID":"\(ranking)","bridgeVersion":1}],"rankings":[{"id":"\(ranking)","name":"My Cooking","createdAt":1000}],"dishes":[],"attempts":[],"items":[],"comparisons":[],"sources":[],"tags":[],"media":[],"legacyItemDates":[]}
        """.utf8))
        let store = try LocalStoreStartup.openAccount(owner, root: root); try store.restore(graph, revision: 1); try SyncJournal.enable(store.container.mainContext)
        return (store, PhotoCloud(graph), .init(formatVersion: 1, authUserID: user, accountID: owner, syncRevision: 1, libraryState: .initialized))
    }
    private func photo(_ color: UIColor = .red) throws -> PreparedCookingPhoto {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 800,height: 600))
        return try LocalPhotoStore.prepare(data: renderer.pngData { c in color.setFill(); c.fill(CGRect(x: 0,y: 0,width: 800,height: 600)) })
    }
    private func create(_ store: LocalStoreSession, color: UIColor = .red) throws -> CookingAttempt {
        var draft = CookingDraft(); draft.dishName = "Isolated photo fixture"; draft.pendingPhoto = try photo(color)
        let list = try CookingStore.globalRanking(context: store.container.mainContext)
        var session = RankingEngine(itemID: UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: .liked)
        while session.nextOpponent != nil { session.answer(.newItem) }
        return try CookingStore.create(draft: draft, existingDish: nil, session: session, context: store.container.mainContext, mediaDirectory: store.mediaRoot)
    }
    private func flush(_ store: LocalStoreSession, _ cloud: PhotoCloud) async throws {
        try await SyncDispatcher().flush(context: store.container.mainContext, transport: AuthorizedCookingTransport(sendOperation: { try await cloud.apply($0) }), now: .distantFuture)
    }
    private func run(_ store: LocalStoreSession, _ cloud: PhotoCloud, _ account: ProvisionedAccount, force: Bool = true) async throws -> Bool {
        try await CookingPhotoSync.run(store: store, account: account, transport: cloud, forceRetry: force, current: { try Task.checkCancellation() })
    }

    @Test func optimizedPairBacksUpAndFreshDeviceRestoresExactBytesWithoutUploadEcho() async throws {
        let a = root(), b = root(); defer { try? FileManager.default.removeItem(at: a); try? FileManager.default.removeItem(at: b) }
        let (store, cloud, account) = try setup(root: a); let attempt = try create(store)
        let original = MediaTransfer(attempt.primaryImage!); let display = try CookingPhotoFiles.read(media: original, thumbnail: false, root: store.mediaRoot!)
        try await flush(store, cloud); #expect(try await run(store,cloud,account)); #expect(cloud.objects.count == 2)
        let fresh = try LocalStoreStartup.openAccount(account.accountID, root: b)
        try fresh.restore(cloud.graph, revision: cloud.revision); try SyncJournal.enable(fresh.container.mainContext)
        let uploads = cloud.uploads; #expect(try await run(fresh,cloud,account)); #expect(cloud.uploads == uploads)
        #expect(try CookingPhotoFiles.read(media: original, thumbnail: false, root: fresh.mediaRoot!) == display)
        #expect(try SyncJournal.pending(fresh.container.mainContext).isEmpty)
        #expect(try CookingGraphExport.snapshot(context: fresh.container.mainContext).canonicalized() == cloud.graph.canonicalized())
    }
    @Test func offlineLocalSaveRestartResumesBothTransfers() async throws {
        let directory = root(); defer { try? FileManager.default.removeItem(at: directory) }
        let (store,cloud,account) = try setup(root: directory); cloud.offline = true
        let attempt = try create(store); #expect(attempt.primaryImage != nil); #expect(try SyncJournal.pending(store.container.mainContext).count == 1)
        do { _ = try await run(store,cloud,account); Issue.record("Offline transfer unexpectedly succeeded") } catch CookingPhotoError.unavailable { }
        #expect(try CookingPhotoJournal.load(owner: account.accountID, root: store.mediaRoot!).retryAt != nil)
        let reopened = try LocalStoreStartup.openAccount(account.accountID, root: directory); cloud.offline = false
        try await flush(reopened,cloud); #expect(try await run(reopened,cloud,account)); #expect(cloud.objects.count == 2)
    }
    @Test(arguments: ["upload", "complete"]) func ambiguousAcceptanceRetriesAfterDiskReopen(_ phase: String) async throws {
        let directory = root(); defer { try? FileManager.default.removeItem(at: directory) }
        let (store,cloud,account) = try setup(root: directory); _ = try create(store); try await flush(store,cloud)
        cloud.loseUploadReply = phase == "upload"; cloud.loseCompleteReply = phase == "complete"
        do { _ = try await run(store,cloud,account); Issue.record("Lost reply unexpectedly succeeded") } catch CookingPhotoError.unavailable { }
        let reopened = try LocalStoreStartup.openAccount(account.accountID, root: directory)
        #expect(try await run(reopened,cloud,account)); #expect(cloud.objects.count == 2); #expect(cloud.manifests.count == 1)
        let count = cloud.uploads; #expect(try await run(reopened,cloud,account)); #expect(cloud.uploads == count)
    }
    @Test func metadataBeforeBytesKeepsFreshRestorePendingAndThenRecovers() async throws {
        let a = root(),b = root(); defer { try? FileManager.default.removeItem(at: a); try? FileManager.default.removeItem(at: b) }
        let (store,cloud,account) = try setup(root: a); _ = try create(store); try await flush(store,cloud)
        let fresh = try LocalStoreStartup.openAccount(account.accountID, root: b); try fresh.restore(cloud.graph, revision: cloud.revision); try SyncJournal.enable(fresh.container.mainContext)
        #expect(try await run(fresh,cloud,account) == false); #expect(cloud.objects.isEmpty)
        do { _ = try await CookingPhotoSync.restoreOnly(graph: cloud.graph, root: fresh.mediaRoot!, owner: account.accountID, transport: cloud); Issue.record("Missing bytes claimed verified") } catch CookingPhotoError.pending { }
        #expect(try await run(store,cloud,account)); #expect(try await run(fresh,cloud,account))
    }
    @Test func corruptDownloadNeverInstallsEitherVariantAndRetryRecovers() async throws {
        let a=root(),b=root(); defer { try? FileManager.default.removeItem(at:a);try? FileManager.default.removeItem(at:b) }
        let (store,cloud,account)=try setup(root:a);_ = try create(store);try await flush(store,cloud);_ = try await run(store,cloud,account)
        let fresh=try LocalStoreStartup.openAccount(account.accountID,root:b);try fresh.restore(cloud.graph,revision:cloud.revision);try SyncJournal.enable(fresh.container.mainContext)
        cloud.corruptDownload=true
        do {_ = try await run(fresh,cloud,account);Issue.record("Corrupt bytes accepted")} catch CookingPhotoError.integrity { }
        let media=cloud.graph.media[0];#expect(try CookingPhotoFiles.read(media:media,thumbnail:false,root:fresh.mediaRoot!) == nil)
        #expect(try CookingPhotoFiles.read(media:media,thumbnail:true,root:fresh.mediaRoot!) == nil)
        cloud.corruptDownload=false;#expect(try await run(fresh,cloud,account));#expect(try SyncJournal.pending(fresh.container.mainContext).isEmpty)
    }
    @Test func replacementRetiresUUIDAndDeletesOldObjectsWithoutOldPhotoRestore() async throws {
        let directory=root();defer{try? FileManager.default.removeItem(at:directory)}
        let (store,cloud,account)=try setup(root:directory);let attempt=try create(store);let old=attempt.primaryImage!.id
        try await flush(store,cloud);_ = try await run(store,cloud,account);let oldPaths=Set(cloud.objects.keys)
        var edit=CookingDraft(attempt:attempt);edit.pendingPhoto=try photo(.blue)
        try CookingStore.edit(attempt,draft:edit,context:store.container.mainContext,mediaDirectory:store.mediaRoot)
        let new=attempt.primaryImage!.id;#expect(new != old);try await flush(store,cloud);#expect(try await run(store,cloud,account))
        #expect(cloud.objects.count == 2);#expect(oldPaths.isDisjoint(with:cloud.objects.keys));#expect(cloud.graph.media.map(\.id) == [new])
        #if DEBUG
        let result=try await FreshCookingRestoreCheck.verifyPhotos(cloud.snapshot(user:account.authUserID),for:account,transport:cloud);#expect(result.photos == 1)
        #endif
    }
    @Test(arguments: [false,true]) func deletionOrReplacementDuringPendingUploadIsGuardedAndCleanupResumes(_ replace: Bool) async throws {
        let directory=root();defer{try? FileManager.default.removeItem(at:directory)}
        let (store,cloud,account)=try setup(root:directory);let attempt=try create(store);try await flush(store,cloud)
        let oldID=attempt.primaryImage!.id
        cloud.beforeReply = {
            cloud.beforeReply=nil
            if replace {
                var edit=CookingDraft(attempt:attempt);edit.pendingPhoto=try photo(.green)
                try CookingStore.edit(attempt,draft:edit,context:store.container.mainContext,mediaDirectory:store.mediaRoot)
            } else { try CookingStore.delete(attempt,context:store.container.mainContext,mediaDirectory:store.mediaRoot) }
        }
        do {_ = try await run(store,cloud,account);Issue.record("Deleted local identity continued uploading")} catch CookingPhotoError.obsolete { }
        #expect(cloud.objects.count == 1);try await flush(store,cloud);#expect(try await run(store,cloud,account))
        #expect(cloud.objects.count == (replace ? 2 : 0));#expect(cloud.graph.media.count == (replace ? 1 : 0))
        #expect(!cloud.objects.keys.contains(where:{$0.contains(oldID.uuidString.lowercased())}))
    }
    @Test func finalDeletionAndRepeatedCleanupStayEmpty() async throws {
        let directory=root();defer{try? FileManager.default.removeItem(at:directory)}
        let (store,cloud,account)=try setup(root:directory);let attempt=try create(store);try await flush(store,cloud);_ = try await run(store,cloud,account)
        try CookingStore.delete(attempt,context:store.container.mainContext,mediaDirectory:store.mediaRoot);try await flush(store,cloud)
        #expect(try await run(store,cloud,account));#expect(try await run(store,cloud,account));#expect(cloud.objects.isEmpty);#expect(cloud.graph.dishes.isEmpty)
        #if DEBUG
        let result=try await FreshCookingRestoreCheck.verifyPhotos(cloud.snapshot(user:account.authUserID),for:account,transport:cloud);#expect(result.photos == 0 && result.dishes == 0)
        #endif
    }
    @Test func invalidCatalogAndGuestStoresCannotReachPhotoBytes() async throws {
        let directory=root();defer{try? FileManager.default.removeItem(at:directory)}
        let (store,cloud,account)=try setup(root:directory);_ = try create(store);try await flush(store,cloud);cloud.wrongOwner=true
        do {_ = try await run(store,cloud,account);Issue.record("Wrong owner accepted")} catch CookingPhotoError.integrity { }
        #expect(cloud.uploads == 0 && cloud.downloads == 0)
        let guest=try LocalStoreSession.open(.guest,root:directory.appendingPathComponent("guest"))
        do {_ = try await run(guest,cloud,account);Issue.record("Guest connected")} catch SyncFoundationError.wrongAccount { }
        #expect(cloud.uploads == 0)
    }
    @Test func cancelledReplyCannotInstallInPrimaryOrAnotherAccountRoot() async throws {
        let a=root(),b=root();defer{try? FileManager.default.removeItem(at:a);try? FileManager.default.removeItem(at:b)}
        let (store,cloud,account)=try setup(root:a);_ = try create(store);try await flush(store,cloud);_ = try await run(store,cloud,account)
        let fresh=try LocalStoreStartup.openAccount(account.accountID,root:b);try fresh.restore(cloud.graph,revision:cloud.revision);try SyncJournal.enable(fresh.container.mainContext)
        var authorized=true;cloud.beforeReply={authorized=false;cloud.beforeReply=nil}
        do {_ = try await CookingPhotoSync.run(store:fresh,account:account,transport:cloud,current:{if !authorized {throw CancellationError()}});Issue.record("Stale reply mounted")} catch is CancellationError { }
        #expect(try CookingPhotoFiles.read(media:cloud.graph.media[0],thumbnail:false,root:fresh.mediaRoot!) == nil)
        let wrong=try LocalStoreStartup.openAccount(UUID(),root:b)
        do {_ = try await CookingPhotoSync.run(store:wrong,account:account,transport:cloud,current:{});Issue.record("Account switch connected old media")} catch SyncFoundationError.wrongAccount { }
    }
    @Test(arguments:["hash","size","identity","path","truncated"]) func integrityManifestRejectsMismatches(_ field:String) throws {
        let directory=root();defer{try? FileManager.default.removeItem(at:directory)}
        let (store,_,account)=try setup(root:directory);let attempt=try create(store);let media=MediaTransfer(attempt.primaryImage!);let prepared=try photo()
        var manifest=try CookingPhotoManifest.make(owner:account.accountID,media:media,display:prepared.displayData,thumbnail:prepared.thumbnailData)
        var bytes=prepared.displayData;var changed=media
        switch field {case "hash":bytes=try photo(.blue).displayData;case "size":bytes.append(0);case "identity":changed.id=UUID();case "path":manifest.displayKey="other/account.jpg";default:bytes=Data(bytes.dropLast())}
        do {try manifest.validate(owner:account.accountID);try CookingPhotoFiles.validate(bytes,manifest:manifest,media:changed,thumbnail:false);Issue.record("Integrity mismatch accepted")} catch CookingPhotoError.integrity { }
    }
    @Test func statusNeverClaimsCompleteWhilePhotoUploadFailedAndAutomaticRetryWorks() async throws {
        let directory=root();defer{try? FileManager.default.removeItem(at:directory)}
        let (store,cloud,account)=try setup(root:directory);_ = try create(store);cloud.loseUploadReply=true
        let coordinator=CookingSyncCoordinator();defer{coordinator.disconnect()}
        try coordinator.connect(store:store,account:account,send:{try await cloud.apply($0)},load:{cloud.snapshot(user:account.authUserID)},photos:cloud)
        for _ in 0..<100 {if coordinator.status == .savedLocally{break};try await Task.sleep(for:.milliseconds(20))}
        #expect(coordinator.status == .savedLocally);#expect(cloud.objects.count == 1)
        for _ in 0..<200 {if coordinator.status == .current{break};try await Task.sleep(for:.milliseconds(20))}
        #expect(coordinator.status == .current);#expect(cloud.objects.count == 2)
    }
    @Test func interruptedDownloadRestartsWithoutHalfPairOrUpload() async throws {
        let a=root(),b=root();defer{try? FileManager.default.removeItem(at:a);try? FileManager.default.removeItem(at:b)}
        let (store,cloud,account)=try setup(root:a);_ = try create(store);try await flush(store,cloud);_ = try await run(store,cloud,account)
        let fresh=try LocalStoreStartup.openAccount(account.accountID,root:b);try fresh.restore(cloud.graph,revision:cloud.revision);try SyncJournal.enable(fresh.container.mainContext)
        cloud.failDownloadAt=cloud.downloads+2;let uploads=cloud.uploads
        do {_ = try await run(fresh,cloud,account);Issue.record("Interrupted pair claimed installed")} catch CookingPhotoError.unavailable { }
        #expect(try CookingPhotoFiles.read(media:cloud.graph.media[0],thumbnail:false,root:fresh.mediaRoot!) == nil)
        let reopened=try LocalStoreStartup.openAccount(account.accountID,root:b);cloud.failDownloadAt=nil
        #expect(try await run(reopened,cloud,account));#expect(cloud.uploads == uploads)
    }
    @Test func scratchPhotoVerifierDoesNotModifyPrimaryOrCloud() async throws {
        let directory=root();defer{try? FileManager.default.removeItem(at:directory)}
        let (store,cloud,account)=try setup(root:directory);_ = try create(store);try await flush(store,cloud);_ = try await run(store,cloud,account)
        let media=cloud.graph.media[0];let before=try CookingPhotoFiles.read(media:media,thumbnail:false,root:store.mediaRoot!)
        let uploads=cloud.uploads;let registrations=cloud.registrations;let graph=try CookingGraphExport.snapshot(context:store.container.mainContext)
        #if DEBUG
        let result=try await FreshCookingRestoreCheck.verifyPhotos(cloud.snapshot(user:account.authUserID),for:account,transport:cloud)
        #expect(result.photos == 1 && result.label.contains("1 photo"))
        #endif
        #expect(cloud.uploads == uploads && cloud.registrations == registrations)
        #expect(try CookingPhotoFiles.read(media:media,thumbnail:false,root:store.mediaRoot!) == before)
        #expect(try CookingGraphExport.snapshot(context:store.container.mainContext) == graph)
    }
    @Test func structuredConflictPreventsUnacceptedPhotoUpload() async throws {
        let directory=root();defer{try? FileManager.default.removeItem(at:directory)}
        let (store,cloud,account)=try setup(root:directory);_ = try create(store);cloud.revision += 1
        let coordinator=CookingSyncCoordinator();defer{coordinator.disconnect()}
        try coordinator.connect(store:store,account:account,send:{try await cloud.apply($0)},load:{cloud.snapshot(user:account.authUserID)},photos:cloud)
        for _ in 0..<100 {if coordinator.status == .conflict{break};try await Task.sleep(for:.milliseconds(20))}
        #expect(coordinator.status == .conflict);#expect(cloud.uploads == 0 && cloud.objects.isEmpty)
        #expect(try SyncJournal.pending(store.container.mainContext).count == 1)
    }
    @Test func sessionTransportRejectsSignOutReplyAndDebugReviewCannotConstructTransport() async throws {
        let directory=root();defer{try? FileManager.default.removeItem(at:directory)}
        let (store,cloud,account)=try setup(root:directory);_ = try create(store);try await flush(store,cloud);_ = try await run(store,cloud,account)
        let backend=PhotoAccountBackend(cloud:cloud,account:account)
        let session=AccountSessionCoordinator(backendFactory:{backend})
        do {_ = try session.cookingPhotoTransport();Issue.record("Unresolved session constructed transport")} catch AccountFoundationError.accountNotResolved { }
        await session.restoreSessionOnLaunch();let transport=try session.cookingPhotoTransport()
        backend.duringDownload={await session.signOut()}
        do {_ = try await transport.download(path:cloud.manifests[cloud.graph.media[0].id]!.displayKey);Issue.record("Stale session reply returned")} catch AccountFoundationError.identityChanged { } catch CookingPhotoError.pending {
            Issue.record("Test path must reach a byte reply rather than not-found")
        }
        #if DEBUG
        #expect(session.beginDevelopmentReview())
        do {_ = try session.cookingPhotoTransport();Issue.record("Demo constructed real Storage transport")} catch AccountFoundationError.accountNotResolved { }
        #endif
    }
}
