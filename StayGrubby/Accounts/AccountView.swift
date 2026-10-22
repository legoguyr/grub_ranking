import SwiftUI
import SwiftData

struct AccountView: View {
    @Environment(AccountSessionCoordinator.self) private var session
    @Environment(\.cookingSyncCoordinator) private var sync
    @Environment(\.modelContext) private var context
    @Query private var sharingCooks: [CookingAttempt]
    @Query private var sharingTombstones: [SyncTombstone]
    @State private var showingPrivacyPolicy = false
    @State private var confirmingDeletion = false
    @State private var showingDeletion = false
    #if DEBUG
    @State private var restoreCheck: String?
    @State private var checkingRestore = false
    #endif
    #if DEBUG
    @Environment(\.endDevelopmentReview) private var endDevelopmentReview
    #endif
    var body: some View {
        #if DEBUG
        if endDevelopmentReview != nil, ProfileAccountReview.requested {
            ProfileAccountReview()
        } else { profile }
        #else
        profile
        #endif
    }

    @ViewBuilder private var profile: some View {
        let ranking = sharingRanking
        let snapshot = ProfileSnapshot(context: context, list: ranking)
        ScrollView {
            VStack(alignment: .leading, spacing: SGTheme.Space.large) {
                identity
                SocialPendingShares()
                SharedCookingPending()
                SocialIdentitySection()
                SocialFriendsLink()
                NotificationsLink()
                ProfileCookingContent(snapshot: snapshot, ranking: ranking)
                #if DEBUG
                if let endDevelopmentReview {
                    VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                        Text("Development library").font(SGTheme.TypeRole.headline)
                        Text("Demo data only. No authenticated account or cloud upload.")
                            .font(SGTheme.TypeRole.body).foregroundStyle(.secondary)
                        Button("Exit development library", action: endDevelopmentReview)
                            .buttonStyle(SGButtonStyle()).accessibilityIdentifier("development-exit")
                    }.sgCard()
                } else { accountUtilities }
                #else
                accountUtilities
                #endif
            }
            .frame(maxWidth: SGTheme.Size.contentMaximum)
            .padding(SGTheme.Space.medium).padding(.bottom, SGTheme.Space.large)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(SGTheme.ColorToken.background)
        .navigationTitle("Profile").toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) {
            StayGrubbyHeader(page: "Profile", searchText: .constant(""), searching: .constant(false))
        }
        .sheet(isPresented: $showingPrivacyPolicy) { PrivacyPolicyView() }
        .sheet(isPresented: $showingDeletion) {
            AccountDeletionAuthorizationView(canCancel: true) { showingDeletion = false }
                .presentationDetents([.medium, .large])
        }
        .alert("Permanently delete your account?", isPresented: $confirmingDeletion) {
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .destructive) {
                session.requestAccountDeletion(); showingDeletion = true
            }
        } message: {
            Text("Your StayGrubby account, cooking library, rankings, comparison history, and backed-up photos will be permanently deleted. This cannot be undone.")
        }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            Image(systemName: "person.crop.circle.fill").font(.largeTitle)
                .foregroundStyle(SGTheme.ColorToken.accent).accessibilityHidden(true)
            Text("Your cooking profile").font(.system(.largeTitle, design: .rounded, weight: .bold))
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            Text("Cook. Rank. Make it again.").font(SGTheme.TypeRole.body).foregroundStyle(.secondary)
            if case .resolved(let account) = session.state {
                Text("Account · \(account.accountID.uuidString.suffix(8).lowercased())")
                    .font(SGTheme.TypeRole.secondary.monospaced())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Account ending in \(account.accountID.uuidString.suffix(8).lowercased())")
            }
        }.padding(.vertical, SGTheme.Space.small).accessibilityIdentifier("profile-identity")
    }

    @ViewBuilder private var accountUtilities: some View {
        if case .resolved = session.state {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: SGTheme.Space.medium) { connectedAccount }
                    .padding(.top, SGTheme.Space.medium)
            } label: {
                VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                    Label("Account & sync", systemImage: "gearshape").font(SGTheme.TypeRole.headline)
                        .foregroundStyle(SGTheme.ColorToken.primaryText)
                        .accessibilityIdentifier("profile-account-utilities")
                    if let sync, sync.status != .idle {
                        Text(sync.status.label).font(SGTheme.TypeRole.secondary).foregroundStyle(Color.secondary)
                    }
                }
            }.tint(SGTheme.ColorToken.accent).sgCard()
        }
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
                    Button("Retry sync") { sync.request(forceRetry: true) }
                        .buttonStyle(SGButtonStyle(compact: true))
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
            }.buttonStyle(SGButtonStyle(compact: true)).disabled(checkingRestore)
                .accessibilityIdentifier("development-verify-fresh-restore")
            if let restoreCheck { Text(restoreCheck).font(.footnote).foregroundStyle(.secondary) }
            #endif
            Button("Privacy Policy") { showingPrivacyPolicy = true }
                .buttonStyle(.bordered).controlSize(.large).accessibilityIdentifier("privacy-policy-open")
            Button("Sign out") { Task { await session.signOut() } }
                .buttonStyle(.bordered).controlSize(.large).accessibilityIdentifier("account-sign-out")
            Button("Delete account…", role: .destructive) { confirmingDeletion = true }
                .buttonStyle(.bordered).controlSize(.large).accessibilityIdentifier("account-delete-start")
        }
    }
}
