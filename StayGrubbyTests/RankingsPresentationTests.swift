import Foundation
import SwiftData
import Testing
import SwiftUI
import UIKit
@testable import StayGrubby

@MainActor struct RankingsPresentationTests {
    @Test func highestMatchingVersionsKeepGlobalRanksWithoutChangingTheGraph() throws {
        let f = try CookingReRankingWorkflowTests().fixture(9); defer { withExtendedLifetime(f) {} }
        let existing = try #require(f.cooks.first)
        var draft = CookingDraft(dish: try #require(existing.dish)); draft.versionTitle = "Best grilled"; draft.category = .side
        var session = RankingEngine(itemID: UUID(), orderedIDs: f.list.orderedItems.map(\.id), reaction: .liked)
        while session.nextOpponent != nil { session.answer(.newItem) }
        let version = try CookingStore.create(draft: draft, existingDish: existing.dish, session: session, context: f.context)
        let before = try CookingGraphExport.snapshot(context: f.context)
        let eligible = ScoreUnlockPolicy.entries(in: f.context)
        let all = RankingsPresentation.entries(eligible, matching: eligible, mode: .allVersions)
        let top = RankingsPresentation.entries(eligible, matching: eligible, mode: .topVersion)
        #expect(all.count == 10 && top.count == 9)
        #expect(top.first { $0.attempt.dish?.id == existing.dish?.id }?.id == version.id)
        #expect(top.map(\.globalRank) == eligible.filter { $0.id != existing.id }.map(\.globalRank))
        #expect(!top.contains { $0.id == existing.id })
        let attempts = try f.context.fetch(FetchDescriptor<CookingAttempt>())
        let search = CookingDiscovery.entries(in: f.list, attempts: attempts, query: "Best grilled")
        #expect(RankingsPresentation.entries(eligible, matching: search, mode: .topVersion).map(\.id) == [version.id])
        let filter = CookingDiscovery.entries(in: f.list, attempts: attempts, filters: .init(category: existing.category))
        let filtered = RankingsPresentation.entries(eligible, matching: filter, mode: .topVersion)
        #expect(filtered.contains { $0.id == existing.id } && !filtered.contains { $0.id == version.id })
        #expect(ScoreUnlockPolicy.state(in: f.context).rankedEntryCount == 10)
        #expect(try CookingGraphExport.snapshot(context: f.context) == before)
        try CookingStore.delete(version, context: f.context)
        #expect(!ScoreUnlockPolicy.state(in: f.context).isUnlocked)
        let remaining = ScoreUnlockPolicy.entries(in: f.context)
        #expect(RankingsPresentation.entries(remaining, matching: remaining, mode: .topVersion).contains { $0.id == existing.id })
        #expect(RankingsPresentation.entries([], matching: [], mode: .topVersion).isEmpty)
    }
    @Test func normalTopThreeOmitsMilestoneClaimWhileActualUnlockMayIncludeIt() throws {
        let f = try CookingReRankingWorkflowTests().fixture(10); defer { withExtendedLifetime(f) {} }
        let normal = try #require(TopThreeShareCardModel.make(in: f.list))
        let milestone = try #require(TopThreeShareCardModel.make(in: f.list, milestone: true))
        #expect(!normal.isUnlockMilestone && milestone.isUnlockMilestone)
        #expect(normal.rows == milestone.rows)
        let a = try ShareCardRenderer.render(topThree: normal, mediaRoot: nil)
        let b = try ShareCardRenderer.render(topThree: milestone, mediaRoot: nil)
        #expect(a.pixelSize == CGSize(width: 1080, height: 1350) && b.pixelSize == a.pixelSize)
        #expect(a.image.pngData() != b.image.pngData())
        #expect(NativeDishShareSheet.activityItems(for: a).count == 1)
    }
    @Test func semanticRedAndButtonColorsHaveReadableContrastInBothAppearances() {
        func luminance(_ color: UIColor) -> Double {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            func linear(_ x: CGFloat) -> Double { x <= 0.04045 ? Double(x / 12.92) : pow(Double((x + 0.055) / 1.055), 2.4) }
            return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        }
        for mode in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: mode)
            let red = UIColor(SGTheme.ColorToken.accent).resolvedColor(with: traits)
            let surface = UIColor(SGTheme.ColorToken.surface).resolvedColor(with: traits)
            let l = luminance(red), background = luminance(surface)
            #expect((max(l, background) + 0.05) / (min(l, background) + 0.05) >= 4.5)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            red.getRed(&r, green: &g, blue: &b, alpha: &a)
            #expect(r > g * 2 && r > b * 2)
        }
        #expect((1.05) / (luminance(UIColor(SGTheme.ColorToken.buttonAccent)) + 0.05) >= 4.5)
    }
    @Test func explicitlyRedProgressExportsRedInDarkMode() throws {
        let renderer = ImageRenderer(content: ProgressView(value: 0.9).progressViewStyle(StayGrubbyUnlockProgressStyle())
            .frame(width: 200, height: 6).background(SGTheme.Brand.cream).environment(\.colorScheme, .dark))
        renderer.scale = 1; renderer.isOpaque = true
        let image = try #require(renderer.uiImage?.cgImage)
        var bytes = [UInt8](repeating: 0, count: 200 * 6 * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let ctx = try #require(CGContext(data: buffer.baseAddress, width: 200, height: 6, bitsPerComponent: 8,
                bytesPerRow: 800, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: 200, height: 6))
        }
        let red = stride(from: 0, to: bytes.count, by: 4).filter { bytes[$0] > 200 && bytes[$0 + 1] < 40 && bytes[$0 + 2] < 40 }.count
        #expect(red > 800)
    }
}
