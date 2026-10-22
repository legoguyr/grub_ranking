import Foundation

nonisolated enum SocialRelationship: String, Codable, Sendable {
    case none, incoming, outgoing, friends, blocked
    var label: String {
        switch self { case .none: "Add Sous Chef"; case .incoming: "Respond"; case .outgoing: "Requested"; case .friends: "Sous Chef"; case .blocked: "Blocked" }
    }
}
nonisolated struct SocialPerson: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let displayName: String
    let username: String
    var relationship: SocialRelationship
    var avatarPath: String? = nil
    var handle: String { "@" + username }
}
nonisolated struct SocialPeoplePage: Codable, Sendable {
    var people: [SocialPerson]
    var nextCursor: String?
    var isOwn: Bool? = nil
}
