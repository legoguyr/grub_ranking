import SwiftUI
import SwiftData

struct AccountView: View {
    @Environment(AccountSessionCoordinator.self) private var session
    @Environment(\.cookingSyncCoordinator) private var sync
    @Environment(\.modelContext) private var context
    @Query private var sharingCooks: [CookingAttempt]
    @Query private var sharingTombstones: [SyncTombstone]
    #if DEBUG
    @State private var restoreCheck: String?
    @State private var checkingRestore = false
    #endif
    #if DEBUG
    @Environment(\.endDevelopmentReview) private var endDevelopmentReview
    #endif
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SGTheme.Space.large) {
                Label("Your StayGrubby account",systemImage:"person.crop.circle").font(.title2.bold())
                TopThreeShareAction(list: sharingRanking)
                #if DEBUG
                if let endDevelopmentReview {
                    Text("Development library").font(.headline)
                    Text("Demo data only. No authenticated account or cloud upload.").foregroundStyle(.secondary)
                    Button("Exit development library",action:endDevelopmentReview).accessibilityIdentifier("development-exit")
                } else { connectedAccount }
                #else
                connectedAccount
                #endif
            }.padding(SGTheme.Space.large).frame(maxWidth:.infinity,alignment:.leading)
        }
        .background(SGTheme.ColorToken.background)
        .navigationTitle("Account").toolbar(.hidden,for:.navigationBar)
        .safeAreaInset(edge:.top) { StayGrubbyHeader(page:"Account",searchText:.constant(""),searching:.constant(false)) }
    }
    private var sharingRanking: RankingList? {
        _ = sharingCooks.count; _ = sharingTombstones.count
        return try? CookingStore.globalRanking(context: context)
    }
    @ViewBuilder private var connectedAccount: some View {
        if case .resolved(let account) = session.state {
            Label("Account connected",systemImage:"checkmark.circle.fill").foregroundStyle(SGTheme.ColorToken.accent)
            Text("Account ID: \(account.accountID.uuidString.lowercased())").font(.footnote).textSelection(.enabled)
            if let sync, sync.status != .idle {
                Text(sync.status.label).font(.footnote).foregroundStyle(.secondary)
                if [.savedLocally, .conflict, .needsReview].contains(sync.status) {
                    Button("Retry sync") { sync.request(forceRetry: true) }.font(.footnote)
                }
            }
            #if DEBUG
            Button("Verify fresh restore (development)") {
                checkingRestore = true; restoreCheck = nil
                Task {
                    defer { checkingRestore = false }
                    do {
                        guard try SyncJournal.pending(context).isEmpty, !context.hasChanges else {
                            restoreCheck = "Wait until local changes have synced before verifying."; return
                        }
                        let snapshot = try await session.openResolvedLibrary()
                        guard try SyncJournal.pending(context).isEmpty, !context.hasChanges,
                              try CookingGraphExport.snapshot(context: context).canonicalized() == snapshot.graph.canonicalized()
                        else { restoreCheck = "Wait for local and cloud cooking details to match, then retry."; return }
                        restoreCheck = try await FreshCookingRestoreCheck.verifyPhotos(snapshot, for: account,
                            transport: session.cookingPhotoTransport()).label
                    } catch CookingPhotoError.pending { restoreCheck = "Wait for photo backup to finish, then verify again. Your main local store was not changed." }
                    catch { restoreCheck = "Couldn't verify fresh restore. Your main local store was not changed." }
                }
            }.font(.footnote).disabled(checkingRestore).accessibilityIdentifier("development-verify-fresh-restore")
            if let restoreCheck { Text(restoreCheck).font(.footnote).foregroundStyle(.secondary) }
            #endif
            Button("Sign out") { Task { await session.signOut() } }
                .buttonStyle(.bordered).accessibilityIdentifier("account-sign-out")
        }
    }
}
