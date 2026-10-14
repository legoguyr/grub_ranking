import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated enum CookingPhotoError: Error, Equatable {
    case integrity, pending, rejected, obsolete, authenticationRequired, unavailable
    var diagnostic: String {
        switch self {
        case .integrity: "photo-integrity"
        case .pending: "photo-pending"
        case .rejected: "photo-rejected"
        case .obsolete: "photo-obsolete"
        case .authenticationRequired: "photo-authentication"
        case .unavailable: "photo-network"
        }
    }
}

nonisolated struct CookingPhotoManifest: Codable, Equatable, Sendable {
    let accountID: UUID
    let mediaID: UUID
    let displayHash: String
    let thumbnailHash: String
    let displayBytes: Int
    let thumbnailBytes: Int
    var displayKey: String
    var thumbnailKey: String
    var state: String
    static let bucket = "cooking-photos"
    static let maximumBytes = 2_097_152
    func path(thumbnail: Bool) -> String {
        "\(accountID.uuidString.lowercased())/\(mediaID.uuidString.lowercased())/\(thumbnail ? "thumbnail" : "display")-\(thumbnail ? thumbnailHash : displayHash).jpg"
    }
    func validate(owner: UUID) throws {
        guard accountID == owner, [displayHash, thumbnailHash].allSatisfy({ hash in
            hash.count == 64 && hash.allSatisfy { "0123456789abcdef".contains($0) }
        }), (1...Self.maximumBytes).contains(displayBytes), (1...Self.maximumBytes).contains(thumbnailBytes),
              displayKey == path(thumbnail: false), thumbnailKey == path(thumbnail: true),
              ["pending", "ready", "deleted"].contains(state)
        else { throw CookingPhotoError.integrity }
    }
    func sameContent(as other: Self) -> Bool {
        accountID == other.accountID && mediaID == other.mediaID && displayHash == other.displayHash &&
        thumbnailHash == other.thumbnailHash && displayBytes == other.displayBytes && thumbnailBytes == other.thumbnailBytes &&
        displayKey == other.displayKey && thumbnailKey == other.thumbnailKey
    }
    static func make(owner: UUID, media: MediaTransfer, display: Data, thumbnail: Data) throws -> Self {
        try CookingPhotoFiles.validateJPEG(display, media: media, thumbnail: false)
        try CookingPhotoFiles.validateJPEG(thumbnail, media: media, thumbnail: true)
        var value = Self(accountID: owner, mediaID: media.id, displayHash: SyncJournal.digest(display),
            thumbnailHash: SyncJournal.digest(thumbnail), displayBytes: display.count, thumbnailBytes: thumbnail.count,
            displayKey: "", thumbnailKey: "", state: "pending")
        value.displayKey = value.path(thumbnail: false); value.thumbnailKey = value.path(thumbnail: true)
        try value.validate(owner: owner)
        return value
    }
}
nonisolated struct CookingPhotoCatalog: Codable, Sendable {
    let accountID: UUID
    let backups: [CookingPhotoManifest]
    func validate(owner: UUID) throws {
        guard accountID == owner, Set(backups.map(\.mediaID)).count == backups.count else { throw CookingPhotoError.integrity }
        for backup in backups { try backup.validate(owner: owner) }
    }
}

@MainActor protocol CookingPhotoTransport {
    func catalog(action: String, manifest: CookingPhotoManifest?) async throws -> CookingPhotoCatalog
    func upload(path: String, bytes: Data) async throws
    func download(path: String) async throws -> Data
    func remove(paths: [String]) async throws
}

nonisolated enum CookingPhotoFiles {
    static func url(media: MediaTransfer, thumbnail: Bool, root: URL) throws -> URL {
        let filename = thumbnail ? media.thumbnailFilename : media.displayFilename
        guard !filename.isEmpty, !filename.contains("/"), !filename.contains("\\"), filename != ".", filename != "..",
              !root.path.isEmpty else { throw CookingPhotoError.integrity }
        let directory = root.appendingPathComponent("StayGrubbyMedia", isDirectory: true)
        let target = directory.appendingPathComponent(filename)
        guard (try? directory.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true,
              (try? target.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true,
              target.resolvingSymlinksInPath() == directory.resolvingSymlinksInPath().appendingPathComponent(filename)
        else { throw CookingPhotoError.integrity }
        return target
    }
    static func read(media: MediaTransfer, thumbnail: Bool, root: URL) throws -> Data? {
        let target = try url(media: media, thumbnail: thumbnail, root: root)
        guard FileManager.default.fileExists(atPath: target.path) else { return nil }
        let size = try target.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard (1...CookingPhotoManifest.maximumBytes).contains(size) else { throw CookingPhotoError.integrity }
        return try Data(contentsOf: target)
    }
    static func validateJPEG(_ bytes: Data, media: MediaTransfer, thumbnail: Bool) throws {
        guard (1...CookingPhotoManifest.maximumBytes).contains(bytes.count), bytes.suffix(2) == Data([0xff,0xd9]),
              let source = CGImageSourceCreateWithData(bytes as CFData, nil),
              CGImageSourceGetType(source) == UTType.jpeg.identifier as CFString,
              CGImageSourceGetStatus(source) == .statusComplete,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, max(width,height) <= (thumbnail ? LocalPhotoStore.thumbnailMaximumPixels : LocalPhotoStore.displayMaximumPixels),
              thumbnail || (width == media.pixelWidth && height == media.pixelHeight),
              CGImageSourceCreateImageAtIndex(source, 0, nil) != nil
        else { throw CookingPhotoError.integrity }
    }
    static func validate(_ bytes: Data, manifest: CookingPhotoManifest, media: MediaTransfer, thumbnail: Bool) throws {
        guard manifest.mediaID == media.id, bytes.count == (thumbnail ? manifest.thumbnailBytes : manifest.displayBytes),
              SyncJournal.digest(bytes) == (thumbnail ? manifest.thumbnailHash : manifest.displayHash)
        else { throw CookingPhotoError.integrity }
        try validateJPEG(bytes, media: media, thumbnail: thumbnail)
    }
    static func install(display: Data, thumbnail: Data, manifest: CookingPhotoManifest, media: MediaTransfer, root: URL) throws {
        try validate(display, manifest: manifest, media: media, thumbnail: false)
        try validate(thumbnail, manifest: manifest, media: media, thumbnail: true)
        let displayURL = try url(media: media, thumbnail: false, root: root)
        let thumbnailURL = try url(media: media, thumbnail: true, root: root)
        try FileManager.default.createDirectory(at: displayURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Both variants are validated before either atomic write. Interrupted pairs
        // are detected/repaired on the next run; partial file bytes are never exposed.
        try display.write(to: displayURL, options: .atomic)
        try thumbnail.write(to: thumbnailURL, options: .atomic)
    }
}

extension Notification.Name { static let cookingPhotoFilesRestored = Notification.Name("StayGrubby.cooking-photo-files-restored") }
