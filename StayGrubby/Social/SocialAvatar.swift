import PhotosUI
import SwiftUI

nonisolated enum SocialAvatarRules {
    static func initials(_ name: String) -> String {
        let words = name.split(whereSeparator: \.isWhitespace).filter { $0.contains(where: \.isLetter) }
        return words.prefix(2).compactMap { $0.first(where: \.isLetter).map(String.init) }.joined().uppercased()
    }
    /// Reuse the pure metadata-stripping/downsampling encoder; no cooking-media files or graph writes.
    static func prepare(_ data: Data) throws -> Data { try LocalPhotoStore.prepare(data: data).thumbnailData }
}

struct SocialAvatar: View {
    let name: String
    let path: String?
    var size: CGFloat = 44
    var preview: Data? = nil
    @Environment(\.socialMedia) private var media
    @State private var loaded: UIImage?
    @State private var loadedPath: String?
    var body: some View {
        ZStack {
            SGTheme.ColorToken.accent.opacity(0.12)
            if let image = preview.flatMap(UIImage.init(data:)) ?? (loadedPath == path ? loaded : nil) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                let initials = SocialAvatarRules.initials(name)
                if initials.isEmpty { Image(systemName: "fork.knife").font(.system(size: size * 0.35, weight: .medium)) }
                else { Text(initials).font(.system(size: size * 0.34, weight: .semibold, design: .rounded)) }
            }
        }.foregroundStyle(SGTheme.ColorToken.primaryText).frame(width: size, height: size).clipShape(Circle())
            .overlay(Circle().strokeBorder(SGTheme.ColorToken.border))
            .accessibilityHidden(true)
            .task(id: path) {
                loaded = nil; loadedPath = nil
                guard let path, let media else { return }
                do {
                    let bytes = try await media(.avatarDownload(path: path))
                    guard !Task.isCancelled, SocialMediaRules.validJPEG(bytes) else { return }
                    loaded = UIImage(data: bytes); loadedPath = path
                } catch { }
            }
    }
}

struct SocialAvatarPicker: View {
    let name: String
    let path: String?
    @Binding var photo: Data?
    @Binding var removePhoto: Bool
    @State private var selection: PhotosPickerItem?
    @State private var loading = false
    @State private var failed = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SocialAvatar(name: name, path: removePhoto ? nil : path, size: 88, preview: photo)
                .accessibilityHidden(false).accessibilityLabel(photo != nil ? "Selected profile photo preview" : removePhoto || path == nil ? "Profile photo initials fallback" : "Current profile photo")
                .accessibilityIdentifier("avatar-preview")
            PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
                Label(photo != nil || (path != nil && !removePhoto) ? "Replace profile photo" : "Choose profile photo", systemImage: "photo")
            }.disabled(loading).accessibilityIdentifier("avatar-choose")
            if photo != nil || (path != nil && !removePhoto) {
                Button("Remove profile photo", role: .destructive) { photo = nil; removePhoto = true; selection = nil }
                    .accessibilityIdentifier("avatar-remove")
            }
            if loading { ProgressView("Preparing profile photo") }
            if failed { Text("Couldn’t read that photo. Choose it again or try another image.").font(.footnote) }
            Text("Optional. Visible wherever your social identity is visible. A circular preview keeps the full photo unchanged.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .task(id: selection) {
            guard let selection else { return }
            loading = true; failed = false; defer { loading = false }
            do {
                guard let data = try await selection.loadTransferable(type: Data.self) else { throw URLError(.cannotDecodeContentData) }
                let prepared = try await Task.detached { try SocialAvatarRules.prepare(data) }.value
                try Task.checkCancellation(); photo = prepared; removePhoto = false
            } catch is CancellationError { } catch { failed = true }
        }
        #if DEBUG
        .onAppear {
            if DebugReviewConfiguration.current.storeID != nil && ProcessInfo.processInfo.arguments.contains("--social-review-avatar-selection") {
                photo = SocialReview.avatarFixture
            }
        }
        #endif
    }
}

@MainActor enum SocialAvatarService {
    private struct Draft: Decodable { let path: String; let published: Bool? }
    private struct Cleanup: Decodable { let paths: [String] }
    static func save(photo: Data?, remove: Bool, currentPath: String?, assetID: UUID,
                     request: SocialRequest, media: SocialMediaRequest?) async throws {
        if let photo {
            guard let media, SocialMediaRules.validJPEG(photo) else { throw AccountFoundationError.invalidResolution }
            let draft = try JSONDecoder().decode(Draft.self, from: await request("social_avatar", "prepare", .init(assetID: assetID)))
            if draft.published != true {
                _ = try await media(.avatarUpload(path: draft.path, bytes: photo))
                _ = try await request("social_avatar", "publish", .init(avatarPath: draft.path))
            }
        } else if remove { _ = try await request("social_avatar", "remove", .init(avatarPath: currentPath)) }
        await cleanup(request: request, media: media)
    }
    static func cleanup(request: SocialRequest, media: SocialMediaRequest?) async {
        guard let media else { return }
        do {
            for _ in 0..<4 {
                let page = try JSONDecoder().decode(Cleanup.self, from: await request("social_avatar", "cleanup", .init()))
                guard !page.paths.isEmpty else { return }
                _ = try await media(.avatarRemove(paths: page.paths))
            }
        } catch { } // Retired paths are already unreadable. Retry cleanup on the next profile visit/change/deletion.
    }
}
