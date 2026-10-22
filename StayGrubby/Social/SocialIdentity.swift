import Foundation

nonisolated struct SocialIdentity: Codable, Equatable, Sendable {
    var displayName: String
    var username: String?
    var discoverable: Bool
    var avatarPath: String? = nil
    var automaticallyShareNewDishes: Bool? = nil
    var sharingDefault: Bool { isConfigured && automaticallyShareNewDishes == true }
    var isConfigured: Bool { username != nil }
    var handle: String { username.map { "@" + $0 } ?? "Choose a username" }
}

nonisolated enum SocialIdentityRules {
    static func name(_ value: String) -> String { value.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
    static func username(_ value: String) -> String {
        var result = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if result.hasPrefix("@") { result.removeFirst() }
        return result
    }
    static let reserved: Set<String> = ["staygrubby", "staygrubbyapp", "admin", "administrator", "support", "privacy", "help", "moderator", "system", "official", "staygrubbysupport"]
    static func valid(name value: String, username handle: String) -> Bool {
        let clean = name(value), user = username(handle)
        return (1...50).contains(clean.unicodeScalars.count) && !clean.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
            && (3...24).contains(user.count) && user.range(of: "^[a-z0-9]+(_[a-z0-9]+)*$", options: .regularExpression) != nil
            && !reserved.contains(user.replacingOccurrences(of: "_", with: ""))
    }
}

/// Social payloads never contain the private CookingGraph or credentials.
nonisolated struct SocialPayload: Codable, Sendable {
    var displayName: String?
    var username: String?
    var discoverable: Bool?
    var peerID: UUID?
    var query: String?
    var afterUsername: String?
    var targetType: String?
    var targetID: UUID?
    var reason: String?
    var context: String?
    var postID: UUID?
    var attemptID: UUID?
    var expectedRevision: Int?
    var confirmed: Bool?
    var includePhoto: Bool?
    var beforeTime: Double?
    var beforeID: UUID?
    var commentID: UUID?
    var body: String?
    var assetID: UUID?
    var avatarPath: String?
    var automaticallyShareNewDishes: Bool?
    var eventID: UUID?
    var originID: UUID?
    var participantIDs: [UUID]?
    var includeAttribution: Bool?
    var recipeID: UUID?
    var recipe: RecipeContent?
    var visibility: String?
    var postDescription: String?
}
