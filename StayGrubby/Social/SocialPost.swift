import Foundation

nonisolated struct SocialPost: Codable, Identifiable, Sendable {
    let id: UUID
    let author: SocialPerson
    let title: String
    let versionTitle: String?
    let scoreText: String?
    let achievement: String?
    let createdAt: Double
    let photoPath: String?
    let published: Bool
    let isAuthor: Bool
    let moderationState: String
    var likeCount: Int? = nil
    var commentCount: Int? = nil
    var liked: Bool? = nil
    var provenance: SocialProvenance? = nil
    var recipeID: UUID? = nil
    var postDescription: String? = nil
    var metadata: SharedCookingMetadata? = nil
    var date: Date { Date(timeIntervalSince1970: createdAt) }
}
nonisolated struct SocialPostsPage: Codable, Sendable { var posts: [SocialPost] }
nonisolated struct SocialCleanupPage: Codable, Sendable {
    struct Item: Codable, Sendable { let postID: UUID; let path: String }
    let paths: [Item]
}
@MainActor enum SocialPhotoCleanup {
    static func run(request: SocialRequest, media: SocialMediaRequest?) async {
        guard let media else { return }
        do {
            let page = try JSONDecoder().decode(SocialCleanupPage.self, from: await request("social_content", "cleanup", .init()))
            for item in page.paths.prefix(25) {
                try Task.checkCancellation()
                _ = try await media(.remove(paths: [item.path]))
                _ = try await request("social_content", "cleaned", .init(postID: item.postID))
            }
        } catch { /* Retired bytes remain private and retry on a later social refresh. */ }
    }
}
