import Foundation
import ImageIO
import SwiftData
import Testing
import UIKit
@testable import Grub_Ranked

@MainActor
struct CookingMediaTests {
    private struct EvidenceSnapshot: Equatable {
        let id: UUID
        let first: UUID
        let second: UUID
        let preferred: UUID?
        let tie: Bool
        let timestamp: Date

        init(_ comparison: Comparison) {
            id = comparison.id; first = comparison.firstItemID; second = comparison.secondItemID
            preferred = comparison.preferredItemID; tie = comparison.isTie
            timestamp = comparison.timestamp
        }
    }

    private func memory() throws -> ModelContainer {
        try ModelContainer(for: AppPersistence.schema,
                           configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    }

    private func imageData(width: Int = 2_400, height: Int = 1_600, color: UIColor = .systemOrange) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.pngData { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            UIColor.white.setFill()
            context.fill(CGRect(x: width / 4, y: height / 4, width: width / 2, height: height / 2))
        }
    }

    private func draft(photo: PreparedCookingPhoto? = nil) -> CookingDraft {
        var draft = CookingDraft()
        draft.dishName = "Photo Pasta"
        draft.cookedAt = Date(timeIntervalSince1970: 1_700_000_000)
        draft.pendingPhoto = photo
        return draft
    }

    private func create(_ context: ModelContext, draft: CookingDraft,
                        dish: Dish? = nil, mediaDirectory: URL) throws -> CookingAttempt {
        let list = try CookingStore.globalRanking(context: context)
        var session = RankingEngine(itemID: UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: .liked)
        while session.nextOpponent != nil { session.answer(.newItem) }
        return try CookingStore.create(draft: draft, existingDish: dish, session: session,
                                       context: context, mediaDirectory: mediaDirectory)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("staygrubby-media-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func importCreatesBoundedDisplayAndThumbnailFiles() throws {
        let prepared = try LocalPhotoStore.prepare(data: imageData())
        #expect(max(prepared.pixelWidth, prepared.pixelHeight) == 1_200)
        #expect(prepared.displayData.count < imageData().count)
        let thumbnailSource = try #require(CGImageSourceCreateWithData(prepared.thumbnailData as CFData, nil))
        let rawProperties = CGImageSourceCopyPropertiesAtIndex(thumbnailSource, 0, nil)
        let properties = try #require(rawProperties as? [CFString: Any])
        let width = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
        let height = try #require(properties[kCGImagePropertyPixelHeight] as? Int)
        #expect(max(width, height) == LocalPhotoStore.thumbnailMaximumPixels)
    }

    @Test func mediaReferencePersistsAcrossStoreReload() throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = directory.appendingPathComponent("model.store")
        let prepared = try LocalPhotoStore.prepare(data: imageData())
        var attemptID = UUID(); var mediaID = UUID()
        do {
            let container = try AppPersistence.open(url: store); let context = ModelContext(container)
            try CookingStore.prepare(context: context)
            let attempt = try create(context, draft: draft(photo: prepared), mediaDirectory: directory)
            let media = try #require(attempt.primaryImage)
            attemptID = attempt.id; mediaID = media.id
            #expect(LocalPhotoStore.fileExists(for: media, thumbnail: false, rootURL: directory))
            #expect(LocalPhotoStore.fileExists(for: media, thumbnail: true, rootURL: directory))
        }
        let container = try AppPersistence.open(url: store); let context = ModelContext(container)
        let attempt = try #require(context.fetch(FetchDescriptor<CookingAttempt>()).first { $0.id == attemptID })
        #expect(attempt.primaryImage?.id == mediaID)
        #expect(try context.fetchCount(FetchDescriptor<CookingMedia>()) == 1)
        let media = try #require(attempt.primaryImage)
        #expect(LocalPhotoStore.data(for: media, thumbnail: true, rootURL: directory) != nil)
    }

    @Test func replacingAndRemovingPhotoPreserveRankingIdentityAndEvidence() throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let container = try memory(); let context = ModelContext(container)
        let list = try CookingStore.prepare(context: context)
        let firstPhoto = try LocalPhotoStore.prepare(data: imageData(color: .systemOrange))
        let first = try create(context, draft: draft(photo: firstPhoto), mediaDirectory: directory)
        _ = try create(context, draft: draft(), mediaDirectory: directory)
        let itemID = first.rankedItemID
        let evidence = list.comparisons.map(EvidenceSnapshot.init)
        let oldMedia = try #require(first.primaryImage)
        let oldMediaID = oldMedia.id
        let oldDisplayURL = try #require(LocalPhotoStore.fileURL(for: oldMedia, thumbnail: false, rootURL: directory))

        var edit = CookingDraft(attempt: first)
        edit.pendingPhoto = try LocalPhotoStore.prepare(data: imageData(color: .systemGreen))
        try CookingStore.edit(first, draft: edit, context: context, mediaDirectory: directory)
        #expect(first.rankedItemID == itemID)
        #expect(first.primaryImage?.id != oldMediaID)
        #expect(!FileManager.default.fileExists(atPath: oldDisplayURL.path))
        #expect(list.comparisons.map(EvidenceSnapshot.init) == evidence)

        edit = CookingDraft(attempt: first); edit.removeExistingPhoto = true
        try CookingStore.edit(first, draft: edit, context: context, mediaDirectory: directory)
        #expect(first.primaryImage == nil)
        #expect(try context.fetchCount(FetchDescriptor<CookingMedia>()) == 0)
        #expect(first.rankedItemID == itemID && list.comparisons.count == evidence.count)
    }

    @Test func deletingCookDeletesItsOwnedFiles() throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let container = try memory(); let context = ModelContext(container)
        try CookingStore.prepare(context: context)
        let prepared = try LocalPhotoStore.prepare(data: imageData())
        let attempt = try create(context, draft: draft(photo: prepared), mediaDirectory: directory)
        let media = try #require(attempt.primaryImage)
        try CookingStore.delete(attempt, context: context, mediaDirectory: directory)
        #expect(!LocalPhotoStore.fileExists(for: media, thumbnail: false, rootURL: directory))
        #expect(!LocalPhotoStore.fileExists(for: media, thumbnail: true, rootURL: directory))
        #expect(try context.fetchCount(FetchDescriptor<CookingMedia>()) == 0)
    }

    @Test func noPhotoAndNewVersionRemainValid() throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let container = try memory(); let context = ModelContext(container)
        try CookingStore.prepare(context: context)
        let first = try create(context, draft: draft(), mediaDirectory: directory)
        let version = try create(context, draft: CookingDraft(dish: try #require(first.dish)),
                                 dish: first.dish, mediaDirectory: directory)
        #expect(first.primaryImage == nil && version.primaryImage == nil)
        #expect(first.dish?.id == version.dish?.id)
        #expect(first.rankedItemID != version.rankedItemID)
    }
}
