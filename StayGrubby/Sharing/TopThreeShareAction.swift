import SwiftUI

/// Reusable current leaderboard sharing, distinct from the first-unlock event.
struct TopThreeShareAction: View {
    let list: RankingList?
    var title = "Share My Top 3"
    var identifier = "profile-share-top-three"
    @Environment(\.cookingMediaRoot) private var mediaRoot
    @State private var sharing: RenderedDishShareCard?
    @State private var notice: ShareCardNotice?
    private var model: TopThreeShareCardModel? { list.flatMap { .make(in: $0) } }
    var body: some View {
        Button {
            guard let current = model else { return }
            do { sharing = try ShareCardRenderer.render(topThree: current, mediaRoot: mediaRoot) }
            catch { notice = .preparationFailed(error.localizedDescription) }
        } label: {
            Label(title, systemImage: model == nil ? "lock.fill" : "square.and.arrow.up").frame(maxWidth: .infinity)
        }
        .buttonStyle(SGButtonStyle())
        .disabled(model == nil)
        .accessibilityIdentifier(identifier)
        .accessibilityHint(model == nil ? "Rank \(ScoreUnlockPolicy.requiredRankedEntryCount) dishes or versions to unlock sharing" : "Shares your current top three dishes and versions as an image. Choose Save Image to save it to Photos.")
        .shareCardSheet(card: $sharing, notice: $notice)
        .onChange(of: model) { _, next in if next == nil { sharing = nil } }
    }
}
