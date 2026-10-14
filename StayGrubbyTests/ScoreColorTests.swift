import Foundation
import SwiftUI
import Testing
import UIKit
@testable import StayGrubby

@MainActor struct ScoreColorTests {
    @Test(arguments: ["1.0", "3.5", "4.9", "5.0", "6.8", "7.5", "7.6", "9.2", "10.0"])
    func confirmedRangesAndBoundaries(score: String) {
        let expected: [String: SGTheme.ScoreColor.Band] = [
            "1.0": .coral, "3.5": .coral, "4.9": .coral,
            "5.0": .orange, "6.8": .orange, "7.5": .orange,
            "7.6": .gold, "9.2": .gold, "10.0": .gold]
        #expect(SGTheme.ScoreColor.band(forDisplayedScore: score) == expected[score])
    }

    @Test func classificationUsesExistingVisibleDecimalWithoutChangingScoreOrUnlock() throws {
        let unlocked = ScoreUnlockState(rankedEntryCount: 10)
        for (score, band) in [(4.94, SGTheme.ScoreColor.Band.coral), (4.96, .orange), (7.54, .orange), (7.59, .gold)] {
            #expect(SGTheme.ScoreColor.band(forDisplayedScore: try #require(unlocked.scoreText(score))) == band)
        }
        #expect(ScoreUnlockState(rankedEntryCount: 9).scoreText(9.2) == nil)
        #expect(SGTheme.ScoreColor.band(forDisplayedScore: "nan") == nil)
        #expect(SGTheme.ScoreColor.band(forDisplayedScore: "") == nil)
    }

    private func rgb(_ color: Color, style: UIUserInterfaceStyle) -> [Double] {
        let value = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        value.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [Double(r), Double(g), Double(b)]
    }
    private func luminance(_ rgb: [Double]) -> Double {
        zip(rgb, [0.2126, 0.7152, 0.0722]).reduce(0) { sum, pair in
            sum + pair.1 * (pair.0 <= 0.04045 ? pair.0 / 12.92 : pow((pair.0 + 0.055) / 1.055, 2.4))
        }
    }
    @Test func warmPaletteHasReadableContrastOnPagesCardsAndTintedBadges() {
        for mode in [UIUserInterfaceStyle.light, .dark] {
            for color in [SGTheme.ScoreColor.gold, SGTheme.ScoreColor.orange, SGTheme.ScoreColor.coral] {
                let ink = rgb(color, style: mode)
                for surface in [SGTheme.ColorToken.background, SGTheme.ColorToken.surface] {
                    let base = rgb(surface, style: mode)
                    for background in [base, zip(ink, base).map { 0.10 * $0.0 + 0.90 * $0.1 }] {
                        let a = luminance(ink), b = luminance(background)
                        #expect((max(a, b) + 0.05) / (min(a, b) + 0.05) >= 4.5)
                    }
                }
            }
        }
    }

    private func pixels(_ image: UIImage) throws -> (width: Int, height: Int, bytes: [UInt8]) {
        let cg = try #require(image.cgImage)
        var bytes = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try #require(CGContext(data: buffer.baseAddress, width: cg.width, height: cg.height,
                bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        }
        return (cg.width, cg.height, bytes)
    }
    private func countInk(_ data: (width: Int, height: Int, bytes: [UInt8]), rgb: [Double], region: CGRect? = nil) -> Int {
        let region = region ?? CGRect(x: 0, y: 0, width: data.width, height: data.height)
        var count = 0
        for y in Int(region.minY)..<min(data.height, Int(region.maxY)) {
            for x in Int(region.minX)..<min(data.width, Int(region.maxX)) {
                let i = (y * data.width + x) * 4
                if (0..<3).allSatisfy({ abs(Double(data.bytes[i + $0]) - rgb[$0] * 255) <= 3 }) { count += 1 }
            }
        }
        return count
    }
    private func exportReview(_ image: UIImage, name: String) throws {
        let env = ProcessInfo.processInfo.environment
        guard env["STAYGRUBBY_SHARE_REVIEW_EXPORTS"] == "1" || env["TEST_RUNNER_STAYGRUBBY_SHARE_REVIEW_EXPORTS"] == "1" else { return }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("StayGrubbyScoreColorReview", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try #require(image.pngData()).write(to: root.appendingPathComponent(name + ".png"))
    }
    @Test func actualBadgesAndNativeScoreTextRenderSemanticInkInBothAppearances() throws {
        for (scheme, style, name) in [(ColorScheme.light, UIUserInterfaceStyle.light, "light"), (.dark, .dark, "dark")] {
            let view = VStack(spacing: 24) {
                Text("In-app dish scores").font(.headline).foregroundStyle(SGTheme.ColorToken.primaryText)
                HStack(spacing: 14) { ForEach([4.9, 5.0, 7.5, 7.6], id: \.self) { ScoreBadge(score: $0) } }
                HStack(spacing: 20) {
                    ForEach(["3.5", "6.8", "9.2"], id: \.self) { score in
                        Text(score + " / 10").font(SGTheme.TypeRole.score)
                            .foregroundStyle(SGTheme.ScoreColor.color(forDisplayedScore: score))
                    }
                }
            }.frame(width: 420, height: 190).background(SGTheme.ColorToken.background)
                .environment(\.scoreUnlockState, ScoreUnlockState(rankedEntryCount: 10))
                .environment(\.colorScheme, scheme)
            let renderer = ImageRenderer(content: view); renderer.scale = 1; renderer.isOpaque = true
            let image = try #require(renderer.uiImage), data = try pixels(image)
            for color in [SGTheme.ScoreColor.gold, SGTheme.ScoreColor.orange, SGTheme.ScoreColor.coral] {
                #expect(countInk(data, rgb: rgb(color, style: style)) > 80)
            }
            try exportReview(image, name: name)
        }
    }
    @Test(arguments: ["3.5", "6.8", "9.2"])
    func individualPhotoFallbackAndNewLeaderExportsKeepOfficialRed(score: String) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("score-color-export-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let source = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400)).pngData { context in
            UIColor.gray.setFill(); context.fill(CGRect(x: 0, y: 0, width: 400, height: 400))
        }
        let photo = MediaTransfer(try LocalPhotoStore.write(LocalPhotoStore.prepare(data: source), rootURL: root))
        for media in [nil, photo] {
            let model = ShareCardModel(title: "Cooking review", versionSubtitle: "Version 2", scoreText: score,
                achievement: .newNumberOne, photo: media)
            let card = try ShareCardRenderer.render(model: model, mediaRoot: root)
            #expect(card.pixelSize == CGSize(width: 1080, height: media == nil ? 1080 : 1350))
            let region = CGRect(x: 250, y: media == nil ? 760 : 1202, width: 580, height: media == nil ? 84 : 64)
            let data = try pixels(card.image)
            #expect(countInk(data, rgb: rgb(SGTheme.Brand.red, style: .light), region: region) > 500)
            for color in [SGTheme.ScoreColor.gold, SGTheme.ScoreColor.orange, SGTheme.ScoreColor.coral] {
                #expect(countInk(data, rgb: rgb(color, style: .light), region: region) == 0)
            }
            try exportReview(card.image, name: "individual-\(score)-\(media == nil ? "fallback" : "photo")")
        }
    }
    @Test func normalUpdatedAndMilestoneTopThreeUseRedAcrossAllScoreBands() throws {
        let rows = ["9.2", "6.8", "3.5"].enumerated().map {
            TopThreeShareCardModel.Row(position: $0.offset + 1,
                dish: ShareCardModel(title: "Dish \($0.offset + 1)", versionSubtitle: nil, scoreText: $0.element,
                    achievement: nil, photo: nil))
        }
        for milestone in [false, true] {
            let card = try ShareCardRenderer.render(topThree: .init(rows: rows, isUnlockMilestone: milestone), mediaRoot: nil)
            #expect(card.pixelSize == CGSize(width: 1080, height: 1350))
            let data = try pixels(card.image), region = CGRect(x: 895, y: 260, width: 120, height: 980)
            #expect(countInk(data, rgb: rgb(SGTheme.Brand.red, style: .light), region: region) > 500)
            for color in [SGTheme.ScoreColor.gold, SGTheme.ScoreColor.orange, SGTheme.ScoreColor.coral] {
                #expect(countInk(data, rgb: rgb(color, style: .light), region: region) == 0)
            }
            try exportReview(card.image, name: milestone ? "top-three-milestone" : "top-three-normal-updated")
        }
    }
}
