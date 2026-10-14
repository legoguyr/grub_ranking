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
    @State private var failed = false

    var body: some View {
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
            catch { failed = true }
        } label: {
            Label(compact ? "Share" : "Share Dish", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
        }
        .buttonStyle(SGButtonStyle(prominent: prominent, compact: compact, prominentColor: SGTheme.ColorToken.buttonAccent))
        .accessibilityIdentifier(identifier)
        .sheet(item: $card) { NativeDishShareSheet(card: $0) }
        .alert("Couldn’t prepare share card", isPresented: $failed) {
            Button("OK", role: .cancel) { }
        } message: { Text("Please try sharing again.") }
        }
    }
}
