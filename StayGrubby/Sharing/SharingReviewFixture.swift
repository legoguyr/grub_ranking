#if DEBUG
import SwiftUI
import SwiftData

/// Explicit isolated-store review only. Uses test-color imagery, never the demo
/// library, account transport, photo uploads, or native Apple authorization.
struct SharingReviewFixture: View {
    let mode: String
    @Environment(\.modelContext) private var context
    @Environment(\.cookingMediaRoot) private var mediaRoot
    @State private var attempt: CookingAttempt?
    @State private var card: RenderedDishShareCard?
    @State private var event: RankingCompletionSnapshot?
    @State private var closed = false
    @State private var failure = false

    var body: some View {
        Group {
            if closed { Text("Review result dismissed").accessibilityIdentifier("review-result-dismissed") }
            else if let attempt {
                if mode == "result" || mode == "new-leader" {
                    CookingRankingResultView(attempt: attempt, event: event, onClose: { closed = true })
                } else if mode == "detail" { AttemptDetailView(attempt: attempt) }
                else {
                    ScrollView {
                        VStack(spacing: SGTheme.Space.medium) {
                            Text("Isolated share-card review").font(.caption)
                            if let card {
                                Image(uiImage: card.image).resizable().scaledToFit()
                                    .accessibilityIdentifier("sharing-review-preview")
                                Text(String(format: "%d × %d", Int(card.pixelSize.width), Int(card.pixelSize.height)))
                                    .accessibilityIdentifier("sharing-review-dimensions")
                            }
                            DishShareAction(model: .make(for: attempt), prominent: true)
                        }.padding().frame(maxWidth: 440).frame(maxWidth: .infinity)
                    }.background(SGTheme.ColorToken.background)
                }
            } else if failure { Text("Could not prepare isolated review") }
            else { ProgressView("Preparing isolated review") }
        }
        .task { prepare() }
    }

    private func prepare() {
        guard attempt == nil, !failure, DebugReviewConfiguration.current.storeID != nil,
              let mediaRoot, DebugReviewConfiguration.current.mediaRoot(in: FileManager.default.temporaryDirectory) == mediaRoot else { return }
        do {
            try DiscoveryReviewFixture.seed(container: context.container, mediaDirectory: mediaRoot)
            let list = try CookingStore.globalRanking(context: context)
            var cooks = try context.fetch(FetchDescriptor<CookingAttempt>())
            // Individual numerical-card review requires an eligible unlocked
            // temporary library. Existing discovery/filter fixtures stay small.
            let remaining = ScoreUnlockPolicy.requiredRankedEntryCount - ScoreUnlockPolicy.state(in: context).rankedEntryCount
            if remaining > 0 {
                for index in 0..<remaining {
                    var draft = CookingDraft(); draft.dishName = "Isolated supporting dish \(index)"; draft.category = .side
                    var session = RankingEngine(itemID: UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: .disliked)
                    while session.nextOpponent != nil { session.answer(.existingItem) }
                    _ = try CookingStore.create(draft: draft, session: session, context: context, mediaDirectory: mediaRoot)
                }
                cooks = try context.fetch(FetchDescriptor<CookingAttempt>())
            }
            if mode == "new-leader" {
                guard let candidate = cooks.first(where: { $0.rankedItemID == list.orderedItems.last?.id }) else { return }
                for _ in 0..<30 {
                    let workflow = CookingReRankingWorkflow(attempt: candidate)
                    try workflow.choose(.liked, context: context)
                    while workflow.session?.nextOpponent != nil { workflow.answer(.newItem) }
                    try workflow.finish(context: context)
                    if ShareAchievement.eligible(for: candidate, event: workflow.completionSnapshot) == .newNumberOne {
                        attempt = candidate; event = workflow.completionSnapshot; return
                    }
                }
                throw CookingStore.StoreError.incompleteSession
            }
            if mode == "plain" || mode == "long" {
                if !cooks.contains(where: { $0.dish?.name.hasPrefix("Slow-Roasted") == true }) {
                    var draft = CookingDraft()
                    draft.dishName = "Slow-Roasted Cauliflower with Lemon, Herbs and Toasted Sesame"
                    draft.versionTitle = mode == "long" ? "Sunday supper with extra lemon and crispy edges" : ""
                    draft.category = .side
                    if let photo = cooks.compactMap(\.primaryImage).first,
                       let data = LocalPhotoStore.data(for: photo, thumbnail: false, rootURL: mediaRoot) {
                        draft.pendingPhoto = try LocalPhotoStore.prepare(data: data)
                    }
                    var session = RankingEngine(itemID: UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: .disliked)
                    while session.nextOpponent != nil { session.answer(.existingItem) }
                    _ = try CookingStore.create(draft: draft, session: session, context: context, mediaDirectory: mediaRoot)
                    cooks = try context.fetch(FetchDescriptor<CookingAttempt>())
                }
                attempt = cooks.first { $0.dish?.name.hasPrefix("Slow-Roasted") == true }
            } else if mode == "fallback" { attempt = cooks.first { $0.dish?.name == "Apple Cake" } }
            else { attempt = cooks.first { $0.primaryImage != nil } }
            if let attempt { card = try ShareCardRenderer.render(model: .make(for: attempt), mediaRoot: mediaRoot) }
        } catch { failure = true }
    }
}
#endif
