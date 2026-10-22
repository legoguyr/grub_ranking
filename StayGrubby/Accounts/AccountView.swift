import SwiftUI
import SwiftData

struct AccountView: View {
    @Environment(AccountSessionCoordinator.self) private var session
    @Environment(\.cookingSyncCoordinator) private var sync
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query private var sharingCooks: [CookingAttempt]
    @Query private var sharingTombstones: [SyncTombstone]
    @State private var showingPrivacyPolicy = false
    @State private var socialRoute: SocialPostRoute?
    @State private var confirmingDeletion = false
    @State private var showingDeletion = false
    #if DEBUG
    @State private var restoreCheck: String?
    @State private var checkingRestore = false
    #endif
    #if DEBUG
    @Environment(\.endDevelopmentReview) private var endDevelopmentReview
    @Environment(\.profileAccountReviewStatus) private var profileReviewStatus
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
                KitchenIdentityHeader()
                SocialPendingShares()
                SharedCookingPending()
                ShareMyKitchen()
                VStack(spacing: SGTheme.Space.small) {
                    SocialFriendsLink()
                    NotificationsLink().frame(maxWidth: .infinity, alignment: .leading)
                }
                SocialProfilePosts(open: { socialRoute = .post($0) })
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
                }
                #endif
            }
            .frame(maxWidth: SGTheme.Size.contentMaximum)
            .padding(SGTheme.Space.medium).padding(.bottom, SGTheme.Space.large)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(SGTheme.ColorToken.background)
        .navigationTitle("My Kitchen").toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) {
            HStack {
                Text("My Kitchen").font(SGTheme.TypeRole.title).accessibilityAddTraits(.isHeader)
                Spacer()
                NavigationLink { KitchenSettings { accountUtilities } } label: {
                    Image(systemName: "gearshape").frame(width: SGTheme.Size.minimumTap, height: SGTheme.Size.minimumTap)
                }.accessibilityLabel("Settings").accessibilityIdentifier("settings-open")
            }.padding(.horizontal, SGTheme.Space.medium).background(SGTheme.ColorToken.background)
        }
        .navigationDestination(item: $socialRoute) { SocialPostDestination(route: $0) }
        .navigationDestination(for: UUID.self) { id in if let cook = sharingCooks.first(where: { $0.id == id }) { AttemptDetailView(attempt: cook) } }
    }

    @ViewBuilder private var accountUtilities: some View {
        if case .resolved = session.state {
            connectedAccount
        } else {
            Section("Account") { Text("No connected account. This local development library does not synchronize with an account.").foregroundStyle(.secondary) }
        }
        #if DEBUG
        if let profileReviewStatus { Text(profileReviewStatus()).font(.caption).accessibilityIdentifier("profile-review-status") }
        #endif
    }
    private var sharingRanking: RankingList? {
        _ = sharingCooks.count; _ = sharingTombstones.count
        return try? CookingStore.globalRanking(context: context)
    }
    @ViewBuilder private var connectedAccount: some View {
        if case .resolved(let account) = session.state {
            Section("Sign-in & synchronization") {
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
            }
            Section("Privacy") {
            Button("Privacy Policy") { showingPrivacyPolicy = true }
                .accessibilityIdentifier("privacy-policy-open")
                .sheet(isPresented: $showingPrivacyPolicy) { PrivacyPolicyView() }
            }
            Section("Account Actions") {
            Button("Sign out") { Task { await session.signOut() } }
                .accessibilityIdentifier("account-sign-out")
            Button("Delete account…", role: .destructive) { confirmingDeletion = true }
                .accessibilityIdentifier("account-delete-start")
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
        }
    }
}
