import Foundation
import SwiftUI
import UIKit

struct RenderedDishShareCard: Identifiable {
    let id = UUID()
    let image: UIImage
    let model: ShareCardModel?
    let hasPhoto: Bool
    var topThreeModel: TopThreeShareCardModel? = nil
    var pixelSize: CGSize { CGSize(width: image.cgImage?.width ?? 0, height: image.cgImage?.height ?? 0) }
}

@MainActor enum ShareCardRenderer {
    enum RenderError: LocalizedError, Equatable {
        case missingBrandAsset, renderingFailed, scoresLocked
        var errorDescription: String? {
            switch self {
            case .missingBrandAsset: "The StayGrubby logo could not be loaded."
            case .renderingFailed: "The share card could not be prepared. Please try again."
            case .scoresLocked: "Rank \(ScoreUnlockPolicy.requiredRankedEntryCount) dishes or versions to unlock sharing with scores."
            }
        }
    }

    /// Local bytes only. Missing, damaged, oversized or unsafe files deliberately
    /// select the square fallback; sharing never invokes photo/cloud transport.
    static func render(model: ShareCardModel, mediaRoot: URL?) throws -> RenderedDishShareCard {
        guard model.scoreText != nil else { throw RenderError.scoresLocked }
        guard OfficialBrandWordmark.image != nil else { throw RenderError.missingBrandAsset }
        let photo = localPhoto(for: model.photo, mediaRoot: mediaRoot)
        let size = CGSize(width: 1_080, height: photo == nil ? 1_080 : 1_350)
        let image = try renderImage(ShareCardView(model: model, photo: photo), size: size)
        return RenderedDishShareCard(image: image, model: model, hasPhoto: photo != nil)
    }

    static func render(topThree model: TopThreeShareCardModel, mediaRoot: URL?) throws -> RenderedDishShareCard {
        guard model.rows.count == 3, model.rows.allSatisfy({ $0.dish.scoreText != nil }) else { throw RenderError.scoresLocked }
        guard OfficialBrandWordmark.image != nil else { throw RenderError.missingBrandAsset }
        let photos = model.rows.map { localPhoto(for: $0.dish.photo, mediaRoot: mediaRoot) }
        let image = try renderImage(TopThreeShareCardView(model: model, photos: photos), size: CGSize(width: 1_080, height: 1_350))
        return RenderedDishShareCard(image: image, model: nil, hasPhoto: photos.contains { $0 != nil }, topThreeModel: model)
    }

    private static func renderImage<V: View>(_ view: V, size: CGSize) throws -> UIImage {
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 1
        renderer.isOpaque = true
        guard let image = renderer.uiImage, let pixels = image.cgImage,
              pixels.width == Int(size.width), pixels.height == Int(size.height)
        else { throw RenderError.renderingFailed }
        return image
    }

    private static func localPhoto(for media: MediaTransfer?, mediaRoot: URL?) -> UIImage? {
        guard let media, media.kindCode == "image" else { return nil }
        let root: URL
        if let mediaRoot { root = mediaRoot }
        else {
            // Normal guest development storage has no explicit environment root.
            // DEBUG fixture launches are routed to their own media tree.
            #if DEBUG
            if let fixtureRoot = DebugReviewConfiguration.current.mediaRoot(in: FileManager.default.temporaryDirectory) {
                root = fixtureRoot
            } else {
                guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                else { return nil }
                root = support
            }
            #else
            guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            else { return nil }
            root = support
            #endif
        }
        guard let bytes = try? CookingPhotoFiles.read(media: media, thumbnail: false, root: root),
              (try? CookingPhotoFiles.validateJPEG(bytes, media: media, thumbnail: false)) != nil
        else { return nil }
        return UIImage(data: bytes)
    }
}
