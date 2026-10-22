import Foundation

nonisolated struct SharedCookingMetadata: Codable, Sendable {
    var title: String?
    var course: String?
    var cuisine: Cuisine?
    var source: Attribution?
    struct Attribution: Codable, Sendable { var type: String; var name: String?; var author: String?; var recipe: String?; var page: String? }
    @MainActor func draft() -> CookingDraft {
        var value = CookingDraft()
        value.dishName = title ?? ""; value.category = course.flatMap(DishCategory.init(rawValue:)) ?? .main; value.cuisine = cuisine
        if let source {
            var s = DishSourceDraft()
            switch source.type {
            case "cookbook": s.type = .cookbook; s.cookbookTitle = source.name ?? ""; s.cookbookAuthors = source.author ?? ""; s.cookbookRecipeName = source.recipe ?? ""; s.cookbookPage = source.page ?? ""
            case "restaurant": s.type = .restaurant; s.restaurantName = source.name ?? ""; s.restaurantDishName = source.recipe ?? ""
            case "onlineRecipe": s.type = .onlineRecipe; s.onlineWebsite = source.name ?? ""; s.onlineRecipeName = source.recipe ?? ""
            case "socialMedia": s.type = .socialMedia; s.socialCreator = source.name ?? ""; s.socialDishName = source.recipe ?? ""
            default: return value
            }
            value.source = s
        }
        return value
    }
}
nonisolated struct SocialCookingClaim: Codable, Identifiable, Sendable {
    let id: UUID
    let itemID: UUID
    let kind: String
    let completed: Bool
    let metadata: SharedCookingMetadata
}
nonisolated struct SharedCookingEvent: Codable, Identifiable, Sendable {
    let id: UUID
    let owner: SocialPerson
    let metadata: SharedCookingMetadata
    let isOwner: Bool
    let participants: [Participant]
    struct Participant: Codable, Identifiable, Sendable {
        let person: SocialPerson
        let state: String
        var id: UUID { person.id }
    }
}
nonisolated struct CookingProvenance: Codable, Identifiable, Sendable {
    let id: UUID
    let kind: String
    let itemID: UUID
    let completed: Bool
    let creator: SocialPerson?
    let eventID: UUID?
}
nonisolated struct CookingProvenancePage: Codable, Sendable { let origins: [CookingProvenance]; let events: [SharedCookingEvent] }
nonisolated struct SocialProvenance: Codable, Sendable { let kind: String; var creator: SocialPerson?; var people: [SocialPerson]? }

nonisolated struct CookingSocialIntent: Codable, Equatable, Identifiable, Sendable {
    let id: UUID // Actual independently ranked item, never a foreign private attempt.
    var eventID: UUID
    let participants: [UUID]
    let originID: UUID?
    var cancelRequested: Bool? = nil
}
nonisolated struct CookingSocialJournal: Codable, Sendable {
    let version: Int
    let accountID: UUID
    var intents: [CookingSocialIntent]
    static func url(_ root: URL) -> URL { root.appendingPathComponent("SharedCookingOutbox.json") }
    static func load(root: URL, accountID: UUID) throws -> Self {
        let url = url(root)
        guard (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true else { throw SyncFoundationError.wrongAccount }
        guard FileManager.default.fileExists(atPath: url.path) else { return .init(version: 1, accountID: accountID, intents: []) }
        let bytes = try Data(contentsOf: url)
        guard bytes.count <= 2_097_152 else { throw SyncFoundationError.wrongAccount }
        let saved = try JSONDecoder().decode(Self.self, from: bytes)
        guard saved.version == 1, saved.accountID == accountID, Set(saved.intents.map(\.id)).count == saved.intents.count,
              saved.intents.allSatisfy({ $0.participants.count <= 8 && Set($0.participants).count == $0.participants.count }) else { throw SyncFoundationError.wrongAccount }
        return saved
    }
    func save(root: URL) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var url = Self.url(root)
        try JSONEncoder().encode(self).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        var values = URLResourceValues(); values.isExcludedFromBackup = true; try url.setResourceValues(values)
    }
}
