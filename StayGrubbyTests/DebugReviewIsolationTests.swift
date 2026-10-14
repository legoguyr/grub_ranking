#if DEBUG
import Foundation
import SwiftData
import Testing
import UIKit
@testable import StayGrubby

@MainActor struct DebugReviewIsolationTests {
    @Test(arguments: [[], ["--test-large-type", "--test-light", "--test-reduce-motion", "--discovery-fixture"],
                      ["--ui-test-store", "invalid", "--comparison-fixture", "11", "--sharing-fixture", "result"],
                      ["--sharing-fixture", "photo"], ["--ui-test-store"]])
    func normalLaunchCannotEnableReview(arguments: [String]) {
        let review = DebugReviewConfiguration(arguments: arguments)
        #expect(review.storeID == nil)
        #expect(!review.light && !review.dark && !review.reduceMotion && !review.largeType && !review.discoveryFixture)
        #expect(review.comparisonMode == nil)
        #expect(review.sharingMode == nil)
        #expect(review.mediaRoot(in: URL(fileURLWithPath: "/tmp")) == nil)
    }

    @Test func testStoreAndMediaShareScopeWithoutUsingGuestPaths() throws {
        let first = UUID(), second = UUID(), root = URL(fileURLWithPath: "/tmp", isDirectory: true)
        let a = DebugReviewConfiguration(arguments: ["--ui-test-store", first.uuidString, "--test-light", "--discovery-fixture"])
        let b = DebugReviewConfiguration(arguments: ["--ui-test-store", second.uuidString])
        #expect(a.light && a.discoveryFixture)
        #expect(a.storeURL(in: root)?.lastPathComponent == "ui-test-\(first.uuidString).store")
        #expect(a.mediaRoot(in: root) != b.mediaRoot(in: root))
        #expect(try #require(a.mediaRoot(in: root)).deletingLastPathComponent() == root)
        #expect(a.mediaRoot(in: root)?.path.contains("Application Support") == false)
        let env = DebugReviewConfiguration(arguments: [], environment: ["GRUB_TEST_STORE": first.uuidString])
        #expect(env.mediaRoot(in: root) == a.mediaRoot(in: root))
        let invalid = DebugReviewConfiguration(arguments: ["--ui-test-store", "invalid"], environment: ["GRUB_TEST_STORE": first.uuidString])
        #expect(invalid.storeID == nil)
        let sharing = DebugReviewConfiguration(arguments: ["--ui-test-store", first.uuidString, "--sharing-fixture", "photo"])
        #expect(sharing.sharingMode == "photo" && sharing.mediaRoot(in: root) == a.mediaRoot(in: root))
    }

    @Test func discoveryPhotosStayInExplicitFixtureRootAcrossReload() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("review-isolation-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let mediaRoot = root.appendingPathComponent("photos", isDirectory: true)
        let store = root.appendingPathComponent("fixture.store")
        let guest = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                appropriateFor: nil, create: false).appendingPathComponent("StayGrubbyMedia")
        func guestFiles() -> [String] { (try? FileManager.default.contentsOfDirectory(atPath: guest.path).sorted()) ?? [] }
        let before = guestFiles()
        do {
            let container = try AppPersistence.open(url: store)
            try DiscoveryReviewFixture.seed(container: container, mediaDirectory: mediaRoot)
            #expect(try container.mainContext.fetchCount(FetchDescriptor<CookingAttempt>()) == 5)
        }
        let reopened = try AppPersistence.open(url: store)
        let media = try #require(reopened.mainContext.fetch(FetchDescriptor<CookingMedia>()).first)
        #expect(LocalPhotoStore.fileExists(for: media, thumbnail: false, rootURL: mediaRoot))
        #expect(LocalPhotoStore.data(for: media, thumbnail: true, rootURL: mediaRoot) != nil)
        #expect(guestFiles() == before)
        try DiscoveryReviewFixture.seed(container: reopened, mediaDirectory: mediaRoot)
        #expect(try reopened.mainContext.fetchCount(FetchDescriptor<CookingMedia>()) == 1)
        #expect(try FileManager.default.contentsOfDirectory(atPath: mediaRoot.appendingPathComponent("StayGrubbyMedia").path).count == 2)
    }
}

#endif
