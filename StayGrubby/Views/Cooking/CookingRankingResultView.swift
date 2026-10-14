import SwiftUI

/// Receives a persisted cook once its comparison session has been saved.
/// Private rank/history stay outside the reusable exported card.
struct CookingRankingResultView: View {
    let attempt: CookingAttempt
    var event: RankingCompletionSnapshot? = nil
    let onClose: () -> Void
    @Environment(\.sgReduceMotion) private var reduceMotion
    @Environment(\.cookingMediaRoot) private var mediaRoot
    @Environment(\.scoreMilestoneScope) private var milestoneScope
    @State private var card: RenderedDishShareCard?
    @State private var appeared = false
    @State private var fileRevision = 0
    @State private var milestone = false
    private struct PreviewRequest: Equatable {
        let model: ShareCardModel
        let fileRevision: Int
    }

    private var model: ShareCardModel { .make(for: attempt, event: event) }
    private var scores: ScoreUnlockState { ScoreUnlockPolicy.state(for: attempt) }
    private var rank: Int? {
        attempt.rankedItem?.list?.orderedItems.firstIndex { $0.id == attempt.rankedItemID }.map { $0 + 1 }
    }
    private var movement: Int? {
        guard let previous = event?.position(of: attempt.rankedItemID), let rank,
              previous != rank else { return nil }
        return previous - rank
    }

    var body: some View {
        if milestone, scores.isUnlocked, let list = attempt.rankedItem?.list {
            ScoreUnlockMilestoneView(list: list, onClose: onClose)
        } else {
        ScrollView {
            VStack(spacing: SGTheme.Space.large) {
                VStack(spacing: SGTheme.Space.xSmall) {
                    Image(systemName: "sparkles").font(.title2).foregroundStyle(SGTheme.ColorToken.accent)
                        .accessibilityHidden(true)
                    Text("Your dish is ranked!").font(SGTheme.TypeRole.title)
                    Text(scores.isUnlocked ? "Here’s how it did." : scores.completionText)
                        .font(SGTheme.TypeRole.body).foregroundStyle(.secondary)
                }.multilineTextAlignment(.center)
                if model.scoreText != nil, let card {
                    Image(uiImage: card.image).resizable().scaledToFit()
                        .frame(maxHeight: SGTheme.Size.sharingPreviewMaximumHeight)
                        .clipShape(RoundedRectangle(cornerRadius: SGTheme.Radius.card))
                        .accessibilityLabel([model.title, model.versionSubtitle,
                                             model.scoreText.map { "\($0) out of 10" }, model.achievement?.title]
                            .compactMap { $0 }.joined(separator: ", "))
                        .accessibilityIdentifier("ranking-share-preview")
                } else if scores.isUnlocked { ProgressView("Preparing your card") }
                VStack(spacing: SGTheme.Space.small) {
                    // Accessible score text complements the raster preview.
                    if let score = model.scoreText {
                    Text("\(score) / 10").font(SGTheme.TypeRole.score)
                        .foregroundStyle(SGTheme.ScoreColor.color(forDisplayedScore: score))
                        .accessibilityLabel("Score \(score)")
                        .accessibilityIdentifier("result-score")
                    } else { LockedScoreIndicator() }
                    if let rank {
                        Text("#\(rank) overall").font(SGTheme.TypeRole.headline)
                            .accessibilityIdentifier("result-rank")
                    }
                    if let movement {
                        Label("\(movement > 0 ? "Up" : "Down") \(abs(movement)) \(abs(movement) == 1 ? "spot" : "spots")",
                              systemImage: movement > 0 ? "arrow.up" : "arrow.down")
                            .font(SGTheme.TypeRole.body).foregroundStyle(.secondary)
                            .accessibilityIdentifier("result-movement")
                    }
                }.frame(maxWidth: .infinity).sgCard()
            }
            .frame(maxWidth: SGTheme.Size.sharingContentMaximum).padding(SGTheme.Space.large).frame(maxWidth: .infinity)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 8)
        }
        .accessibilityIdentifier("ranking-result")
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: SGTheme.Space.small) {
                DishShareAction(model: model, prominent: true, identifier: "result-share-dish", currentModel: { self.model })
                if scores.isUnlocked, model.achievement == .newNumberOne {
                    TopThreeShareAction(list: attempt.rankedItem?.list, title: "Share Updated Top 3", identifier: "result-share-updated-top-three")
                }
                Button("Done", action: onClose).buttonStyle(SGButtonStyle())
                    .frame(maxWidth: .infinity).accessibilityIdentifier("ranking-result-close")
            }
            .frame(maxWidth: SGTheme.Size.sharingContentMaximum).padding(SGTheme.Space.medium).frame(maxWidth: .infinity)
            .background(SGTheme.ColorToken.background)
        }
        .background(SGTheme.ColorToken.background)
        .task(id: PreviewRequest(model: model, fileRevision: fileRevision)) {
            card = model.scoreText == nil ? nil : try? ShareCardRenderer.render(model: model, mediaRoot: mediaRoot)
            if let list = attempt.rankedItem?.list, TopThreeShareCardModel.make(in: list) != nil {
                milestone = ScoreUnlockMilestones.claim(scope: milestoneScope,
                    previous: event?.eligibleRankedEntryCount, current: scores)
            }
            withAnimation(reduceMotion ? nil : SGTheme.Motion.standard) { appeared = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cookingPhotoFilesRestored)) { notification in
            if notification.object as? URL == mediaRoot,
               notification.userInfo?["mediaID"] as? UUID == model.photo?.id { fileRevision += 1 }
        }
        }
    }
}
