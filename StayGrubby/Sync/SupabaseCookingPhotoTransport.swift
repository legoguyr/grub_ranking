import Foundation
import Supabase

@MainActor protocol AccountPhotoBackend: AccountLibraryBackend {
    func photoCatalog(action: String, manifest: CookingPhotoManifest?) async throws -> CookingPhotoCatalog
    func uploadPhoto(path: String, bytes: Data) async throws
    func downloadPhoto(path: String) async throws -> Data
    func removePhotos(paths: [String]) async throws
}

extension SupabaseAccountBackend: AccountPhotoBackend {
    private func photoRequest<T>(_ action: () async throws -> T) async throws -> T {
        guard let identity = client.auth.currentSession?.user.id else { throw CookingPhotoError.authenticationRequired }
        try Task.checkCancellation()
        do {
            let result = try await action()
            try Task.checkCancellation()
            guard client.auth.currentSession?.user.id == identity else { throw AccountFoundationError.identityChanged }
            return result
        } catch let error as PostgrestError {
            switch error.code {
            case "40001": throw CookingPhotoError.obsolete
            case "42501", "PGRST301", "PGRST302": throw CookingPhotoError.authenticationRequired
            case "55000": throw CookingPhotoError.pending
            case "23505": throw CookingPhotoError.integrity
            default: throw CookingPhotoError.rejected
            }
        } catch let error as StorageError {
            switch error.statusCode {
            case "401", "403": throw CookingPhotoError.authenticationRequired
            case "404": throw CookingPhotoError.pending
            default: throw CookingPhotoError.unavailable
            }
        }
    }
    func photoCatalog(action: String, manifest: CookingPhotoManifest?) async throws -> CookingPhotoCatalog {
        struct Parameters: Encodable { let action: String; let manifest: CookingPhotoManifest? }
        return try await photoRequest {
            let response = try await client.schema("api").rpc("media_backup", params: Parameters(action: action, manifest: manifest)).execute()
            return try JSONDecoder().decode(CookingPhotoCatalog.self, from: response.data)
        }
    }
    func uploadPhoto(path: String, bytes: Data) async throws {
        try await photoRequest {
            _ = try await client.storage.from(CookingPhotoManifest.bucket).upload(path, data: bytes,
                options: FileOptions(cacheControl: "0", contentType: "image/jpeg", upsert: true))
        }
    }
    func downloadPhoto(path: String) async throws -> Data {
        try await photoRequest {
            try await client.storage.from(CookingPhotoManifest.bucket).download(path: path, cacheNonce: UUID().uuidString)
        }
    }
    func removePhotos(paths: [String]) async throws {
        try await photoRequest { _ = try await client.storage.from(CookingPhotoManifest.bucket).remove(paths: paths) }
    }
}

/// Captures the exact resolved-account generation, not a free-standing SDK client.
@MainActor struct SessionCookingPhotoTransport: CookingPhotoTransport {
    let backend: any AccountPhotoBackend
    let authorize: () throws -> Void
    func catalog(action: String, manifest: CookingPhotoManifest?) async throws -> CookingPhotoCatalog {
        try authorize(); let result = try await backend.photoCatalog(action: action, manifest: manifest); try authorize(); return result
    }
    func upload(path: String, bytes: Data) async throws {
        try authorize(); try await backend.uploadPhoto(path: path, bytes: bytes); try authorize()
    }
    func download(path: String) async throws -> Data {
        try authorize(); let result = try await backend.downloadPhoto(path: path); try authorize(); return result
    }
    func remove(paths: [String]) async throws {
        try authorize(); try await backend.removePhotos(paths: paths); try authorize()
    }
}
