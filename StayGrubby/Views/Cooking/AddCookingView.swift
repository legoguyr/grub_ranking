import SwiftUI
import SwiftData

struct AddCookingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.cookingMediaRoot) private var mediaRoot
    @Environment(\.socialRequest) private var socialRequest
    @Environment(\.socialPublication) private var publication
    @Environment(\.sharedCooking) private var sharedCooking
    @Query private var attempts: [CookingAttempt]
    let list: RankingList
    let dish: Dish?
    let origin: SocialCookingClaim?
    let onResultClose: () -> Void
    @State private var draft: CookingDraft
    @State private var sharing = CookingSharingSelection()
    @State private var sharingChoice: Bool?
    @State private var sharingUnavailable = false
    @State private var choosingReaction = false
    @State private var session: RankingEngine?
    @State private var error: String?
    @State private var savedAttempt: CookingAttempt?
    @State private var saving = false
    @State private var saveFailed = false
    @State private var completionSnapshot: RankingCompletionSnapshot?
    @State private var cookedWith = Set<UUID>()

    init(list: RankingList, dish: Dish? = nil, origin: SocialCookingClaim? = nil, onResultClose: @escaping () -> Void = {}) {
        self.list = list; self.dish = dish; self.origin = origin; self.onResultClose = onResultClose
        _draft = State(initialValue: origin?.metadata.draft() ?? dish.map { CookingDraft(dish: $0) } ?? CookingDraft())
    }
    private var displayName: String {
        "\(draft.cleanDishName) — \(draft.cleanTitle ?? "Version \((dish?.attempts.map(\.sequenceNumber).max() ?? 0) + 1)")"
    }
    var body: some View {
        NavigationStack {
            Group {
                if let savedAttempt {
                    CookingRankingResultView(attempt: savedAttempt, event: completionSnapshot,
                                             onClose: { onResultClose(); dismiss() })
                        .safeAreaInset(edge: .top) {
                            if sharingUnavailable { Text("Your cook is saved privately. Sharing couldn’t be queued; use Share with Friends below to retry.").font(.footnote).padding() }
                            SharedCookingPending(itemID: savedAttempt.rankedItemID)
                        }
                } else if let session {
                    if let opponent = list.items.first(where: { $0.id == session.nextOpponent }) {
                        let opponentAttempt = attempts.first { $0.rankedItemID == opponent.id }
                        ComparisonView(newName: draft.cleanDishName,
                                       existingName: opponentAttempt?.dish?.name ?? opponent.name,
                                       newVersion: draft.cleanTitle ?? "Version \((dish?.attempts.map(\.sequenceNumber).max() ?? 0) + 1)",
                                       existingVersion: opponentAttempt?.versionLabel,
                                       newPreparedPhoto: draft.pendingPhoto,
                                       existingPhoto: opponentAttempt?.primaryImage,
                                       canUndo: session.canUndo,
                                       onAnswer: { self.session?.answer($0) }, onUndo: { self.session?.undo() })
                    } else {
                        VStack(spacing: SGTheme.Space.medium) {
                            if !saveFailed { ProgressView("Finishing your cook…") }
                            else {
                                Text("Your cook hasn’t been saved yet.")
                                Button("Retry", action: save).buttonStyle(SGButtonStyle(prominent: true))
                            }
                        }
                    }
                } else if choosingReaction {
                    InitialReactionView(name: displayName) { reaction in
                        session = RankingEngine(itemID: origin?.itemID ?? UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: reaction)
                    }
                } else {
                    CookingFormScroll(draft: $draft, existingDish: dish != nil, sharingSelection: socialRequest == nil ? nil : $sharing, cookedWith: socialRequest != nil && sharing.configured == true ? $cookedWith : nil)
                }
            }
            .navigationTitle(savedAttempt != nil ? "Ranking Result" : session == nil ? (dish == nil ? "New Dish" : "New Version") : "Rank this cook")
            .navigationBarTitleDisplayMode(.inline)
            .background(SGTheme.ColorToken.background)
            .toolbar {
                if savedAttempt == nil { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                if choosingReaction && session == nil {
                    ToolbarItem(placement: .confirmationAction) { Button("Edit Details") { choosingReaction = false; sharingChoice = nil } }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if savedAttempt == nil && !choosingReaction && session == nil {
                    Button { sharingChoice = sharing.selected; choosingReaction = true } label: {
                        Text("Continue").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SGButtonStyle(prominent: true)).disabled(draft.cleanDishName.isEmpty)
                    .padding(SGTheme.Space.medium).background(SGTheme.ColorToken.background)
                }
            }
            .interactiveDismissDisabled(session != nil)
            .task(id: session?.isComplete) { if session?.isComplete == true { save() } }
            .alert("Couldn't save cook", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("Retry", action: save)
                Button("Cancel", role: .cancel) { dismiss() }
            } message: { Text(error ?? "") }
        }
        .deferRemoteCookingUpdates()
        .task {
            guard let socialRequest else { return }
            do {
                let identity = try JSONDecoder().decode(SocialIdentity.self, from: await socialRequest("social_identity", "get", .init()))
                try Task.checkCancellation(); sharing.receive(identity)
            } catch is CancellationError { } catch { sharing.unavailable() }
        }
    }
    private func save() {
        guard let session, session.isComplete, savedAttempt == nil, !saving else { return }
        saving = true; error = nil; saveFailed = false
        defer { saving = false }
        do {
            let before = RankingCompletionSnapshot.capture(from: list)
            if !cookedWith.isEmpty || origin != nil {
                guard let sharedCooking else { throw AccountFoundationError.accountNotResolved }
                try sharedCooking.record(itemID: session.itemID, participants: cookedWith.sorted { $0.uuidString < $1.uuidString }, originID: origin?.id)
            }
            if sharingChoice == true {
                sharingUnavailable = publication?.record(itemID: session.itemID, includePhoto: draft.hasPhoto) != true
            } else {
                try publication?.cancelUnsavedCreation(session.itemID)
            }
            savedAttempt = try CookingStore.create(draft: draft, existingDish: dish, session: session, context: context, mediaDirectory: mediaRoot)
            completionSnapshot = before
            if let savedAttempt { publication?.privateSaveFinished(savedAttempt) }
            publication?.retry()
            sharedCooking?.retry()
        }
        catch { saveFailed = true; self.error = error.localizedDescription }
    }
}
