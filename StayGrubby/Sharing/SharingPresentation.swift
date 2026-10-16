import SwiftUI

private struct ShareCardSheetPresentation: ViewModifier {
    @Binding var card: RenderedDishShareCard?
    @Binding var notice: ShareCardNotice?
    @State private var feedback = NativeShareFeedback()

    func body(content: Content) -> some View {
        content
            .sheet(item: $card, onDismiss: {
                if let completedNotice = feedback.dismissed() { notice = completedNotice }
            }) { card in
                NativeDishShareSheet(card: card) { outcome in
                    if let completedNotice = feedback.completed(with: outcome.notice) { notice = completedNotice }
                    self.card = nil
                }
                .onAppear { feedback.appeared() }
            }
            .alert(notice?.title ?? "", isPresented: Binding(
                get: { notice != nil }, set: { if !$0 { notice = nil } }
            )) {
                Button("OK", role: .cancel) { notice = nil }
            } message: { Text(notice?.message ?? "") }
    }
}

extension View {
    func shareCardSheet(card: Binding<RenderedDishShareCard?>, notice: Binding<ShareCardNotice?>) -> some View {
        modifier(ShareCardSheetPresentation(card: card, notice: notice))
    }
}

/// Displays the actual export bytes, with a description containing exportable
/// facts only. The surrounding result can separately describe private position.
struct ShareCardPreview: View {
    let card: RenderedDishShareCard
    let label: String
    let identifier: String

    var body: some View {
        Image(uiImage: card.image).resizable().scaledToFit()
            .frame(maxHeight: SGTheme.Size.sharingPreviewMaximumHeight)
            .clipShape(RoundedRectangle(cornerRadius: SGTheme.Radius.card))
            .accessibilityLabel(label)
            .accessibilityIdentifier(identifier)
    }
}

struct SharePreviewFailure: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: SGTheme.Space.small) {
            Text("Your ranking is saved.").font(SGTheme.TypeRole.headline)
            Text(message).font(SGTheme.TypeRole.body).foregroundStyle(.secondary)
            Button("Retry Preview", action: retry).buttonStyle(SGButtonStyle())
                .accessibilityIdentifier("share-preview-retry")
        }.multilineTextAlignment(.center).frame(maxWidth: .infinity).sgCard()
    }
}
