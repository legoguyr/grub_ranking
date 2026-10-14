import Foundation
import SwiftUI
import Testing
import UIKit
@testable import StayGrubby

@MainActor struct TopThreeShareCardTests {
    private func row(_ position: Int, photo: MediaTransfer? = nil) -> TopThreeShareCardModel.Row {
        .init(position: position, dish: .init(title: position == 1 ? "Slow-Roasted Sea Bass with Corn Velouté and Preserved Lemon" : "Dish \(position)",
            versionSubtitle: position < 3 ? "Version \(position) · Crispy Sunday" : nil,
            scoreText: ["9.1", "8.6", "7.2"][position - 1], achievement: nil, photo: photo))
    }
    private func export(_ image: UIImage, name: String) throws {
        let e = ProcessInfo.processInfo.environment
        guard e["STAYGRUBBY_SHARE_REVIEW_EXPORTS"] == "1" || e["TEST_RUNNER_STAYGRUBBY_SHARE_REVIEW_EXPORTS"] == "1" else { return }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("StayGrubbyShareReview")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try #require(image.pngData()).write(to: root.appendingPathComponent(name + ".png"))
    }

    @Test func exactPortraitExportUsesSelectedLocalPhotoAndUniversalFallbacks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("top-three-render-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let bytes = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 400)).pngData { context in
            UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 600, height: 400))
        }
        let media = try LocalPhotoStore.write(LocalPhotoStore.prepare(data: bytes), rootURL: root)
        let model = TopThreeShareCardModel(rows: [row(1, photo: MediaTransfer(media)), row(2), row(3)])
        let result = try ShareCardRenderer.render(topThree: model, mediaRoot: root)
        #expect(result.pixelSize == CGSize(width: 1080, height: 1350) && result.hasPhoto)
        #expect(result.topThreeModel == model && result.model == nil)
        let image = try #require(result.image.cgImage)
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            let bitmap = try #require(CGContext(data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            bitmap.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        let blue = stride(from: 0, to: pixels.count, by: 4).filter { pixels[$0 + 2] > 190 && pixels[$0] < 50 && pixels[$0 + 1] < 50 }.count
        #expect(blue > 30_000)
        let items = NativeDishShareSheet.activityItems(for: result)
        #expect(items.count == 1 && (items[0] as? UIImage) === result.image)
        try export(result.image, name: "top-three-mixed-photo")
        try FileManager.default.removeItem(at: root.appendingPathComponent("StayGrubbyMedia").appendingPathComponent(media.displayFilename))
        let missing = try ShareCardRenderer.render(topThree: model, mediaRoot: root)
        #expect(!missing.hasPhoto && missing.pixelSize == CGSize(width: 1080, height: 1350))
        try export(missing.image, name: "top-three-all-fallback")
    }

    @Test func deterministicCreamGraphicIgnoresPhoneAppearanceAndType() throws {
        let model = TopThreeShareCardModel(rows: [row(1), row(2), row(3)])
        let actual = try ShareCardRenderer.render(topThree: model, mediaRoot: nil)
        let renderer = ImageRenderer(content: TopThreeShareCardView(model: model, photos: [nil, nil, nil])
            .environment(\.colorScheme, .dark).environment(\.dynamicTypeSize, .accessibility5))
        renderer.scale = 1; renderer.isOpaque = true
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1350)
        #expect(actual.image.pngData() == renderer.uiImage?.pngData())
    }

    @Test func lockedOrIncompleteTopThreeModelsCannotExport() throws {
        var rows = [row(1), row(2), row(3)]
        rows[0] = .init(position: 1, dish: .init(title: "Locked", versionSubtitle: nil, scoreText: nil, achievement: nil, photo: nil))
        #expect(throws: ShareCardRenderer.RenderError.scoresLocked) {
            try ShareCardRenderer.render(topThree: .init(rows: rows), mediaRoot: nil)
        }
        #expect(throws: ShareCardRenderer.RenderError.scoresLocked) {
            try ShareCardRenderer.render(topThree: .init(rows: [row(1)]), mediaRoot: nil)
        }
    }
}
