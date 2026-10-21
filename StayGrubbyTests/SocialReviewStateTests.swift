#if DEBUG
import Foundation
import Testing
@testable import StayGrubby

@MainActor struct SocialReviewStateTests {
    @Test func deletingFixtureCommentChangesSubsequentResponse() async throws {
        let review = SocialReview(), postID = UUID(), commentID = UUID()
        _ = try await review.request("social_content", "prepare", .init(postID: postID, confirmed: true))
        _ = try await review.request("social_interactions", "comment", .init(postID: postID, commentID: commentID, body: "Fixture comment"))
        let before = try JSONDecoder().decode(SocialCommentsPage.self, from: await review.request("social_interactions", "comments", .init(postID: postID)))
        #expect(before.comments.map(\.id) == [commentID])
        _ = try await review.request("social_interactions", "deleteComment", .init(postID: postID, commentID: commentID))
        let after = try JSONDecoder().decode(SocialCommentsPage.self, from: await review.request("social_interactions", "comments", .init(postID: postID)))
        #expect(after.comments.isEmpty)
        #expect(review.comments[postID]?.isEmpty == true)
    }
}
#endif
