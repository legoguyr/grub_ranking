import Foundation

/// A separate account-root transfer checkpoint. No SwiftData/domain schema changes.
/// Remote immutable manifests and tombstones also make the work reconstructible.
nonisolated struct CookingPhotoJournal: Codable {
    struct Entry: Codable {
        var manifest: CookingPhotoManifest?
        var phase = "pending"
        var attempts = 0
        var diagnostic: String?
        var retryAt: Date?
    }
    let accountID: UUID
    var entries: [String: Entry] = [:]
    static func url(root: URL) -> URL { root.appendingPathComponent("CookingPhotoTransfers.json") }
    static func load(owner: UUID, root: URL) throws -> Self {
        let file = url(root: root)
        guard (try? file.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true else { throw CookingPhotoError.integrity }
        guard FileManager.default.fileExists(atPath: file.path) else { return Self(accountID: owner) }
        let value = try JSONDecoder().decode(Self.self, from: Data(contentsOf: file))
        guard value.accountID == owner else { throw SyncFoundationError.wrongAccount }
        for (key, entry) in value.entries {
            guard UUID(uuidString: key) != nil else { throw CookingPhotoError.integrity }
            if let manifest = entry.manifest { try manifest.validate(owner: owner); guard manifest.mediaID == UUID(uuidString: key) else { throw CookingPhotoError.integrity } }
        }
        return value
    }
    func save(root: URL) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: Self.url(root: root), options: .atomic)
    }
    var retryAt: Date? { entries.values.compactMap(\.retryAt).min() }
}
