import SwiftUI

/// Receives a persisted cook, never a draft or a pending ranking session.
struct CookingRankingResultView: View {
    let attempt: CookingAttempt
    let onClose: () -> Void
    @Environment(\.sgReduceMotion) private var reduceMotion
    private var rank: Int? {
        attempt.rankedItem?.list?.orderedItems.firstIndex { $0.id == attempt.rankedItemID }.map { $0 + 1 }
    }
    var body: some View {
        ScrollView {
            VStack(spacing: SGTheme.Space.large) {
                Text("Your new cook, ranked").font(SGTheme.TypeRole.headline).foregroundStyle(.secondary)
                if attempt.primaryImage != nil {
                    SGHeroMedia(media: attempt.primaryImage, name: attempt.dish?.name ?? "Dish")
                }
                VStack(spacing: SGTheme.Space.small) {
                    Text(attempt.dish?.name ?? "Dish").font(SGTheme.TypeRole.title)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(attempt.versionLabel).font(SGTheme.TypeRole.body).foregroundStyle(.secondary)
                    if let item = attempt.rankedItem {
                        ScoreBadge(score: item.score).accessibilityIdentifier("result-score")
                    }
                    if let rank {
                        Text("#\(rank) overall").font(SGTheme.TypeRole.headline).accessibilityIdentifier("result-rank")
                    }
                }.multilineTextAlignment(.center)
                SGIconButton(title: "Close ranking result", symbol: "xmark", action: onClose)
                    .accessibilityIdentifier("ranking-result-close")
            }
            .frame(maxWidth: SGTheme.Size.contentMaximum).padding(SGTheme.Space.large).frame(maxWidth: .infinity)
        }
        .background(SGTheme.ColorToken.background)
        .accessibilityIdentifier("ranking-result")
        .transition(reduceMotion ? .identity : .opacity)
    }
}
