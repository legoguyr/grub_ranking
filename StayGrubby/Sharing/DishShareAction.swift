import SwiftUI

/// Both entry points export the same card and pass only its image to iOS.
struct DishShareAction: View {
    let model: ShareCardModel
    var prominent = false
    var compact = false
    var identifier = "detail-share-dish"
    var currentModel: (() -> ShareCardModel)? = nil
    @Environment(\.cookingMediaRoot) private var mediaRoot
    @State private var card: RenderedDishShareCard?
    @State private var notice: ShareCardNotice?

    var body: some View {
        Group {
            if model.scoreText == nil {
                Label(compact ? "Share" : "Share Dish unlocks with your scores", systemImage: "lock.fill")
                    .font(compact ? SGTheme.TypeRole.headline : SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                    .accessibilityIdentifier("dish-sharing-locked")
                    .accessibilityLabel("Share locked. Rank \(ScoreUnlockPolicy.requiredRankedEntryCount) dishes or versions to unlock sharing.")
                    .frame(maxWidth: compact ? .infinity : nil, minHeight: compact ? SGTheme.Size.minimumTap : nil)
                    .background(compact ? SGTheme.ColorToken.elevatedSurface : .clear, in: RoundedRectangle(cornerRadius: SGTheme.Radius.field))
            } else {
                Button {
                    do { card = try ShareCardRenderer.render(model: currentModel?() ?? model, mediaRoot: mediaRoot) }
                    catch { notice = .preparationFailed(error.localizedDescription) }
                } label: {
                    Label(compact ? "Share" : "Share Dish", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }
                .buttonStyle(SGButtonStyle(prominent: prominent, compact: compact, prominentColor: SGTheme.ColorToken.buttonAccent))
                .accessibilityIdentifier(identifier)
                .accessibilityLabel("Share Dish")
                .accessibilityHint("Opens image sharing. Choose Save Image to save your card to Photos.")
            }
        }
        .shareCardSheet(card: $card, notice: $notice)
        .onChange(of: model.scoreText) { _, score in if score == nil { card = nil } }
    }
}
