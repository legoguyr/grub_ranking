import Foundation
import Testing
import UIKit
@testable import StayGrubby

@MainActor struct SocialAvatarTests {
    @Test func initialsAndOptimizedUncroppedJPEG() throws {
        #expect(SocialAvatarRules.initials("  Guy Rettig  ") == "GR")
        #expect(SocialAvatarRules.initials("李") == "李")
        #expect(SocialAvatarRules.initials("123 🥘").isEmpty)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 400)).image { c in
            UIColor.red.setFill(); c.fill(CGRect(x: 0, y: 0, width: 800, height: 400))
        }
        let bytes = try SocialAvatarRules.prepare(#require(image.pngData()))
        #expect(SocialMediaRules.validJPEG(bytes))
        let decoded = try #require(UIImage(data: bytes))
        #expect(decoded.size.width == 360 && decoded.size.height == 180)
        #expect(SocialMediaAction.avatarDownload(path: "test").bucket == "profile-photos")
        #expect(SocialMediaAction.download(path: "test").bucket == "social-photos")
    }
    @Test func failedUploadRetainsPreviousAvatarAndRetryUsesSameAsset() async throws {
        let review = SocialReview(); review.identity = .init(displayName: "Cook", username: "cook", discoverable: false, avatarPath: "previous")
        let asset = UUID(), bytes = SocialReview.avatarFixture
        let request: SocialRequest = { try await review.request($0, $1, $2) }
        await #expect(throws: URLError.self) {
            try await SocialAvatarService.save(photo: bytes, remove: false, currentPath: "previous", assetID: asset, request: request, media: { _ in throw URLError(.notConnectedToInternet) })
        }
        #expect(review.identity.avatarPath == "previous")
        var uploaded = [String]()
        let media: SocialMediaRequest = { action in uploaded += action.paths; return Data() }
        try await SocialAvatarService.save(photo: bytes, remove: false, currentPath: "previous", assetID: asset, request: request, media: media)
        #expect(review.identity.avatarPath?.contains(asset.uuidString.lowercased()) == true)
        #expect(uploaded.count == 1)
        try await SocialAvatarService.save(photo: nil, remove: true, currentPath: review.identity.avatarPath, assetID: asset, request: request, media: media)
        #expect(review.identity.avatarPath == nil)
    }
}
