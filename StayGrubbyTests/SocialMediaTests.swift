import Foundation
import Testing
import UIKit
@testable import StayGrubby

@MainActor struct SocialMediaTests {
    @Test func onlyBoundedJPEGAndStructuredSocialPathsAreAccepted() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).image { ctx in UIColor.orange.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 16, height: 16)) }
        let jpeg = try #require(image.jpegData(compressionQuality: 0.8))
        #expect(SocialMediaRules.validJPEG(jpeg))
        #expect(!SocialMediaRules.validJPEG(try #require(image.pngData())))
        #expect(!SocialMediaRules.validJPEG(Data(jpeg.prefix(20))))
        #expect(!SocialMediaRules.validJPEG(Data(repeating: 0, count: SocialMediaRules.maximumBytes + 1)))
        #expect(SocialMediaRules.validPath(UUID().uuidString + "/" + UUID().uuidString + ".jpg"))
        for path in ["../private.jpg", "/tmp/photo.jpg", "account/attempt.jpg", "https://example.com/photo.jpg", UUID().uuidString + "/../photo.jpg"] { #expect(!SocialMediaRules.validPath(path)) }
    }
    @Test func postDTOContainsNoPrivateCookingFields() throws {
        let post = SocialPost(id: UUID(), author: SocialPerson(id: UUID(), displayName: "Friend", username: "friend", relationship: .friends), title: "Soup", versionTitle: nil, scoreText: nil, achievement: nil, createdAt: 1000, photoPath: nil, published: true, isAuthor: false, moderationState: "active")
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(post)) as? [String: Any])
        for key in ["attemptID", "source_attempt_id", "notes", "tags", "allergens", "source", "comparisons", "strength", "rank", "email", "authUserID"] { #expect(object[key] == nil) }
        #expect(object["scoreText"] == nil)
    }
}
