import Foundation
import SwiftUI
import Testing
import UIKit
@testable import StayGrubby

@MainActor
struct ShareCardRendererTests {
    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("staygrubby-share-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func photo(root: URL, color: UIColor = UIColor(red: 0.08, green: 0.3, blue: 0.9, alpha: 1)) throws -> MediaTransfer {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let source = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 600), format: format).pngData { context in
            color.setFill(); context.fill(CGRect(x: 0, y: 0, width: 900, height: 600))
        }
        let prepared = try LocalPhotoStore.prepare(data: source)
        return MediaTransfer(try LocalPhotoStore.write(prepared, rootURL: root))
    }

    private func model(photo: MediaTransfer? = nil, achievement: ShareAchievement? = nil) -> ShareCardModel {
        ShareCardModel(title: "Sea Bass with Corn Velouté", versionSubtitle: "Crispy Skin", scoreText: "8.7", achievement: achievement, photo: photo)
    }

    /// Opt-in review artifacts in the test runner's temporary sandbox only.
    /// Disabled during ordinary tests; never writes to cooking media or a store.
    private func exportForReview(_ card: RenderedDishShareCard, name: String) throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["STAYGRUBBY_SHARE_REVIEW_EXPORTS"] == "1" ||
              environment["TEST_RUNNER_STAYGRUBBY_SHARE_REVIEW_EXPORTS"] == "1" else { return }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("StayGrubbyShareReview", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try #require(card.image.pngData()).write(to: root.appendingPathComponent("\(name).png"), options: .atomic)
    }

    /// Decode into a known RGBA order rather than assuming UIImage's backing
    /// bitmap color space/order. Pixel probes verify actual export content.
    private func pixel(_ image: UIImage, x: Int, y: Int) throws -> [UInt8] {
        let cg = try #require(image.cgImage)
        var bytes = [UInt8](repeating: 0, count: 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try #require(CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                                                bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.translateBy(x: CGFloat(-x), y: CGFloat(y + 1 - cg.height))
            context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        }
        return bytes
    }

    @Test func photoExportIsExactSharpOpaqueAndUsesSelectedLocalPhoto() throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let selected = try photo(root: root)
        _ = try photo(root: root, color: .systemOrange)
        let before = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("StayGrubbyMedia").path).sorted()
        let rendered = try ShareCardRenderer.render(model: model(photo: selected, achievement: .topFive), mediaRoot: root)
        #expect(rendered.hasPhoto)
        #expect(rendered.pixelSize == CGSize(width: 1_080, height: 1_350))
        #expect(rendered.image.scale == 1)
        let center = try pixel(rendered.image, x: 540, y: 770)
        #expect(center[2] > 190 && center[0] < 45 && center[1] < 110 && center[3] == 255)
        let cream = try pixel(rendered.image, x: 10, y: 500)
        #expect(abs(Int(cream[0]) - 250) <= 2 && abs(Int(cream[1]) - 243) <= 2 && abs(Int(cream[2]) - 236) <= 2)
        #expect(cream[3] == 255)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("StayGrubbyMedia").path).sorted() == before)
        try exportForReview(rendered, name: "photo-achievement")
    }

    @Test func noPhotoExportIsExactSquareWithNeutralRedOutline() throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let rendered = try ShareCardRenderer.render(model: model(), mediaRoot: root)
        #expect(!rendered.hasPhoto)
        #expect(rendered.pixelSize == CGSize(width: 1_080, height: 1_080))
        // Plate's leftmost point, inside the universal fallback region.
        let plate = try pixel(rendered.image, x: 471, y: 556)
        #expect(plate[0] > 200 && plate[1] < 90 && plate[2] < 90)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
        try exportForReview(rendered, name: "square-fallback")
    }

    @Test(arguments: ["missing", "corrupt", "dimensions", "traversal", "file-symlink", "directory-symlink", "oversized", "kind"])
    func unusableLocalBytesSafelySelectSquareWithoutReadingOtherMedia(mode: String) throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        var media = try photo(root: root)
        let directory = root.appendingPathComponent("StayGrubbyMedia")
        let display = directory.appendingPathComponent(media.displayFilename)
        switch mode {
        case "missing": try FileManager.default.removeItem(at: display)
        case "corrupt": try Data([1, 2, 3, 4]).write(to: display)
        case "dimensions": media.pixelWidth += 1
        case "traversal": media.displayFilename = "../outside.jpg"
        case "file-symlink":
            let target = root.appendingPathComponent("outside.jpg")
            try FileManager.default.moveItem(at: display, to: target)
            try FileManager.default.createSymbolicLink(at: display, withDestinationURL: target)
        case "directory-symlink":
            let other = root.appendingPathComponent("other")
            try FileManager.default.moveItem(at: directory, to: other)
            try FileManager.default.createSymbolicLink(at: directory, withDestinationURL: other)
        case "oversized": try Data(repeating: 0, count: CookingPhotoManifest.maximumBytes + 1).write(to: display)
        case "kind": media.kindCode = "video"
        default: break
        }
        let rendered = try ShareCardRenderer.render(model: model(photo: media), mediaRoot: root)
        #expect(!rendered.hasPhoto)
        #expect(rendered.pixelSize == CGSize(width: 1_080, height: 1_080))
    }

    @Test func reconstructedFilesAndOriginalFilesRenderIdentically() throws {
        let original = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: original) }
        let restored = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: restored) }
        let media = try photo(root: original)
        let directory = original.appendingPathComponent("StayGrubbyMedia")
        try FileManager.default.copyItem(at: directory, to: restored.appendingPathComponent("StayGrubbyMedia"))
        let first = try ShareCardRenderer.render(model: model(photo: media), mediaRoot: original)
        let second = try ShareCardRenderer.render(model: model(photo: media), mediaRoot: restored)
        #expect(first.image.pngData() == second.image.pngData())
        try exportForReview(first, name: "photo-no-achievement")
    }

    @Test func exportAppearanceIsFixedDespiteDarkModeAndAccessibilityType() throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let selected = try photo(root: root)
        let cardModel = model(photo: selected)
        let actual = try ShareCardRenderer.render(model: cardModel, mediaRoot: root)
        let localBytes = try CookingPhotoFiles.read(media: selected, thumbnail: false, root: root)
        let bytes = try #require(localBytes)
        let image = try #require(UIImage(data: bytes))
        let renderer = ImageRenderer(content: ShareCardView(model: cardModel, photo: image)
            .environment(\.colorScheme, .dark).environment(\.dynamicTypeSize, .accessibility5))
        renderer.scale = 1; renderer.isOpaque = true
        renderer.proposedSize = ProposedViewSize(width: 1_080, height: 1_350)
        #expect(actual.image.pngData() == renderer.uiImage?.pngData())
    }

    @Test func nativeActivityContainsOnlyTheRenderedImage() throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let rendered = try ShareCardRenderer.render(model: model(), mediaRoot: root)
        let items = NativeDishShareSheet.activityItems(for: rendered)
        #expect(items.count == 1)
        #expect((items[0] as? UIImage) === rendered.image)
        #expect(!(items[0] is URL) && !(items[0] is String))
    }

    @Test func longTitlesAndVersionAndAchievementStayInsideExactCanvas() throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let long = ShareCardModel(title: "Slow-Roasted Sea Bass with Corn Velouté, Charred Radicchio and Preserved Lemon Dressing", versionSubtitle: "Version 12 · Crispier Skin and Extra Lemon", scoreText: "2.3", achievement: .bestVersion, photo: nil)
        let rendered = try ShareCardRenderer.render(model: long, mediaRoot: root)
        #expect(rendered.pixelSize == CGSize(width: 1_080, height: 1_080))
        #expect(rendered.image.pngData() != nil)
        #expect(OfficialBrandWordmark.image?.size == CGSize(width: 1_121, height: 682))
        try exportForReview(rendered, name: "long-version-low-score")
    }
}
