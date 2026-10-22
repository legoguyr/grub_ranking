#if DEBUG
import Foundation
import Testing
@testable import StayGrubby

@MainActor struct SocialPostDescriptionTests {
    @Test func legacyPostDecodesWithoutDescriptionOrMetadata() throws {
        let data = try legacyPost()
        let post = try JSONDecoder().decode(SocialPost.self, from: data)
        #expect(post.postDescription == nil && post.metadata == nil)
    }
    private func legacyPost() throws -> Data {
        let author = SocialPerson(id: UUID(), displayName: "Cook", username: "a_cook", relationship: .friends)
        return try JSONEncoder().encode(SocialPost(id: UUID(), author: author, title: "Soup", versionTitle: nil, scoreText: nil, achievement: nil, createdAt: 1000, photoPath: nil, published: true, isAuthor: false, moderationState: "active"))
    }
    @Test func publisherSendsOnlyIntentionallyAuthoredDescription() async throws {
        let review = SocialReview()
        var preparations: [[String: Any]] = []
        let request: SocialRequest = { endpoint, action, payload in
            if endpoint == "social_content" && action == "prepare" {
                preparations.append(try JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as! [String: Any])
            }
            return try await review.request(endpoint, action, payload)
        }
        let explicit = "A Sunday worth cooking for."
        let post = try await SocialPostPublisher.publish(attemptID: UUID(), postID: UUID(), revision: 0, includePhoto: false, photo: nil, request: request, media: nil, postDescription: explicit)
        #expect(post.postDescription == explicit)
        _ = try await SocialPostPublisher.publish(attemptID: UUID(), postID: UUID(), revision: 0, includePhoto: false, photo: nil, request: request, media: nil)
        #expect(preparations.count == 2)
        #expect(preparations[0]["postDescription"] as? String == explicit)
        #expect(preparations[1]["postDescription"] == nil) // Automatic publication has no note-to-caption path.
        for payload in preparations {
            #expect(Set(payload.keys).isSubset(of: ["postID", "attemptID", "expectedRevision", "confirmed", "includePhoto", "includeAttribution", "postDescription"]))
        }
    }
}
#endif
