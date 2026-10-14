import SwiftUI
import UIKit

/// Both entry points share precisely one rendered local image. No screen capture,
/// account metadata, link, or cloud service is included in the activity items.
struct NativeDishShareSheet: UIViewControllerRepresentable {
    let card: RenderedDishShareCard
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: Self.activityItems(for: card), applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
    static func activityItems(for card: RenderedDishShareCard) -> [Any] { [card.image] }
}
