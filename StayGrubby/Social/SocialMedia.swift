import SwiftUI
import Supabase
import ImageIO

nonisolated enum SocialMediaAction: Sendable {
    case upload(path: String, bytes: Data), download(path: String), remove(paths: [String])
    case avatarUpload(path: String, bytes: Data), avatarDownload(path: String), avatarRemove(paths: [String])
    var isDownload: Bool { switch self { case .download, .avatarDownload: true; default: false } }
    var bucket: String { switch self { case .avatarUpload, .avatarDownload, .avatarRemove: "profile-photos"; default: "social-photos" } }
    var paths: [String] {
        switch self { case .upload(let path, _), .download(let path), .avatarUpload(let path, _), .avatarDownload(let path): [path]; case .remove(let paths), .avatarRemove(let paths): paths }
    }
}
nonisolated enum SocialMediaRules {
    static let maximumBytes = 2_097_152
    static func validPath(_ path: String) -> Bool {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        return parts.count == 2 && UUID(uuidString: String(parts[0])) != nil && parts[1].hasSuffix(".jpg")
            && UUID(uuidString: String(parts[1].dropLast(4))) != nil
    }
    static func validJPEG(_ data: Data) -> Bool {
        guard !data.isEmpty, data.count <= maximumBytes,
              let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetStatus(source) == .statusComplete,
              CGImageSourceGetType(source) as String? == "public.jpeg",
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return false }
        return width > 0 && height > 0 && width <= 4096 && height <= 4096
    }
}
@MainActor protocol SocialMediaBackend: SocialBackend {
    func socialMedia(_ action: SocialMediaAction) async throws -> Data
}
extension SupabaseAccountBackend: SocialMediaBackend {
    func socialMedia(_ action: SocialMediaAction) async throws -> Data {
        guard let user = client.auth.currentSession?.user.id, action.paths.count <= 25,
              action.paths.allSatisfy(SocialMediaRules.validPath) else { throw AccountFoundationError.invalidResolution }
        let bucket = client.storage.from(action.bucket)
        let result: Data
        switch action {
        case .upload(let path, let bytes), .avatarUpload(let path, let bytes):
            guard SocialMediaRules.validJPEG(bytes) else { throw AccountFoundationError.invalidResolution }
            _ = try await bucket.upload(path, data: bytes, options: FileOptions(cacheControl: "0", contentType: "image/jpeg", upsert: true)); result = Data()
        case .download(let path), .avatarDownload(let path): result = try await bucket.download(path: path, cacheNonce: UUID().uuidString)
        case .remove(let paths), .avatarRemove(let paths): _ = try await bucket.remove(paths: paths); result = Data()
        }
        try Task.checkCancellation()
        guard client.auth.currentSession?.user.id == user else { throw AccountFoundationError.identityChanged }
        return result
    }
}
typealias SocialMediaRequest = @MainActor (SocialMediaAction) async throws -> Data
private struct SocialMediaKey: EnvironmentKey { static let defaultValue: SocialMediaRequest? = nil }
extension EnvironmentValues {
    var socialMedia: SocialMediaRequest? { get { self[SocialMediaKey.self] } set { self[SocialMediaKey.self] = newValue } }
}

struct SocialPhoto: View {
    let path: String?
    @Environment(\.socialMedia) private var media
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { ZStack { SGTheme.ColorToken.surface; Image(systemName: "fork.knife").font(.largeTitle).foregroundStyle(.secondary) } }
        }.clipped().accessibilityHidden(true)
            .task(id: path) {
                image = nil
                guard let path, let media else { return }
                do {
                    let bytes = try await media(.download(path: path))
                    guard !Task.isCancelled, SocialMediaRules.validJPEG(bytes), let source = CGImageSourceCreateWithData(bytes as CFData, nil),
                          let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 1024, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary)
                    else { return }
                    image = UIImage(cgImage: thumbnail)
                } catch { if !Task.isCancelled { image = nil } }
            }
    }
}
