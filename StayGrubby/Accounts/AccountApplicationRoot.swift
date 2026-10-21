import SwiftUI
import SwiftData

struct AccountApplicationRoot: View {
    @Environment(AccountSessionCoordinator.self) private var session
    @State private var access = AccountLibraryAccess()
    @State private var retryID = 0
    @State private var sync = CookingSyncCoordinator()
    @Environment(\.scenePhase) private var scenePhase
    #if DEBUG
    @State private var development: DevelopmentLibraryAccess?
    @State private var developmentFailed = false
    #endif
    var body: some View {
        Group {
            #if DEBUG
            if let development {
                if let mode = DebugReviewConfiguration.current.comparisonMode { ComparisonReviewFixture(mode:mode) }
                else {
                    ContentView().modelContainer(development.container)
                        .environment(\.cookingMediaRoot,development.mediaRoot)
                        .environment(\.scoreMilestoneScope, "development.\(DebugReviewConfiguration.current.storeID?.uuidString ?? "demo")")
                        .environment(\.endDevelopmentReview,{ self.development = nil })
                        .id("development")
                        .safeAreaInset(edge:.top) {
                            if !development.isolated { Text("DEVELOPMENT · DEMO LIBRARY").font(.caption.bold()).foregroundStyle(.secondary) }
                        }
                }
            } else { gatedContent }
            #else
            gatedContent
            #endif
        }
        .task {
            session.finishPendingLocalDeletion()
            #if DEBUG
            if DevelopmentLibraryAccess.requestedOnLaunch { openDevelopment(); return }
            #endif
            await session.restoreSessionOnLaunch()
        }
        .task(id:session.state) {
            if case .resolved = session.state {} else { sync.disconnect() }
            await prepareAccess()
        }
        .onChange(of: scenePhase) { _, phase in sync.setActive(phase == .active) }
        .task(id:retryID) { if retryID > 0 { await prepareAccess() } }
    }
    @ViewBuilder private var gatedContent: some View {
        if case .resolved(let account) = session.state, access.isReady(for:account), let store = access.store {
            ContentView().modelContainer(store.container).environment(\.cookingMediaRoot,store.mediaRoot)
                .environment(\.scoreMilestoneScope, "account.\(account.accountID.uuidString.lowercased())")
                .id(account.accountID)
                .environment(\.socialMedia, { action in try await session.performSocialMedia(action) })
                .environment(\.socialRequest, { endpoint, action, payload in
                    try await session.performSocialRequest(endpoint: endpoint, action: action, payload: payload)
                })
                .environment(\.cookingSyncCoordinator, sync)
                .task(id: account.accountID) {
                    do {
                        let token = try sync.connect(store: store, account: account,
                            send: { envelope in try await session.applyResolvedOperation(envelope) },
                            load: { try await session.openResolvedLibrary() }, active: scenePhase == .active,
                            photos: try session.cookingPhotoTransport(),
                            remember: { try session.rememberReadyAccount($0) })
                        defer { sync.disconnect(token) }
                        try await Task.sleep(for: .seconds(31_536_000)) // Cancelled when the account tree unmounts.
                    } catch { }
                }
        } else {
            VStack(spacing:0) {
                AuthenticationGateView(setupFailed:access.failed,retrySetup:{ retryID += 1 })
                #if DEBUG
                Button("Open development library") { openDevelopment() }
                    .font(.footnote).padding().accessibilityIdentifier("development-library-open")
                    .disabled(!mayOpenDevelopment)
                if developmentFailed { Text("Couldn't open the preserved development store.").font(.footnote) }
                #endif
            }.background(SGTheme.ColorToken.background)
        }
    }
    private func prepareAccess() async {
        access.reset()
        guard case .resolved(let account) = session.state else {
            await Task.yield()
            session.finishPendingLocalDeletion()
            return
        }
        await access.prepare(account,offline:session.offlineResolution,
            load:{ try await session.openResolvedLibrary() },remember:{ try session.rememberReadyAccount($0) })
    }
    #if DEBUG
    private var mayOpenDevelopment: Bool {
        guard !session.isSigningOut else { return false }
        switch session.state {
        case .guest, .signInFailed, .retryRequired(.restoreSession, nil): return true
        default: return false
        }
    }
    private func openDevelopment() {
        guard session.beginDevelopmentReview() else { return }
        do { development = try DevelopmentLibraryAccess.open(); developmentFailed = false }
        catch { developmentFailed = true }
    }
    #endif
}
