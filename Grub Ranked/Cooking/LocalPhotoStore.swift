import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated struct PreparedCookingPhoto: Sendable {
    let id: UUID
    let displayData: Data
    let thumbnailData: Data
    let pixelWidth: Int
    let pixelHeight: Int

    init(id: UUID = UUID(), displayData: Data, thumbnailData: Data,
         pixelWidth: Int, pixelHeight: Int) {
        self.id = id
        self.displayData = displayData
        self.thumbnailData = thumbnailData
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}

nonisolated enum LocalPhotoStore {
    enum PhotoError: LocalizedError {
        case unreadableImage, encodingFailed
        var errorDescription: String? {
            switch self {
            case .unreadableImage: "That photo could not be read."
            case .encodingFailed: "That photo could not be prepared for StayGrubby."
            }
        }
    }

    static let displayMaximumPixels = 1_200
    static let thumbnailMaximumPixels = 360

    /// ImageIO applies EXIF orientation while downsampling, avoiding a full-size
    /// decode. The resulting JPEGs are ready for future upload without recompression.
    static func prepare(data: Data) throws -> PreparedCookingPhoto {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let display = thumbnail(source: source, maximumPixels: displayMaximumPixels),
              let thumbnail = thumbnail(source: source, maximumPixels: thumbnailMaximumPixels)
        else { throw PhotoError.unreadableImage }
        guard let displayData = jpegData(display, preferredQuality: 0.84, softLimit: 300_000),
              let thumbnailData = jpegData(thumbnail, preferredQuality: 0.76, softLimit: 60_000)
        else { throw PhotoError.encodingFailed }
        return PreparedCookingPhoto(displayData: displayData, thumbnailData: thumbnailData,
                                    pixelWidth: display.width, pixelHeight: display.height)
    }

    static func write(_ photo: PreparedCookingPhoto, rootURL: URL? = nil) throws -> CookingMedia {
        let directory = try mediaDirectory(rootURL: rootURL)
        let display = "\(photo.id.uuidString)-display.jpg"
        let thumbnail = "\(photo.id.uuidString)-thumbnail.jpg"
        let displayURL = directory.appendingPathComponent(display)
        let thumbnailURL = directory.appendingPathComponent(thumbnail)
        do {
            try photo.displayData.write(to: displayURL, options: .atomic)
            try photo.thumbnailData.write(to: thumbnailURL, options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: displayURL)
            try? FileManager.default.removeItem(at: thumbnailURL)
            throw error
        }
        return CookingMedia(id: photo.id, displayFilename: display, thumbnailFilename: thumbnail,
                            pixelWidth: photo.pixelWidth, pixelHeight: photo.pixelHeight)
    }

    static func fileURL(for media: CookingMedia, thumbnail: Bool, rootURL: URL? = nil) -> URL? {
        guard let directory = try? mediaDirectory(rootURL: rootURL) else { return nil }
        return directory.appendingPathComponent(thumbnail ? media.thumbnailFilename : media.displayFilename)
    }

    static func data(for media: CookingMedia, thumbnail: Bool, rootURL: URL? = nil) -> Data? {
        guard let url = fileURL(for: media, thumbnail: thumbnail, rootURL: rootURL) else { return nil }
        return try? Data(contentsOf: url, options: [.mappedIfSafe])
    }

    static func deleteFiles(for media: CookingMedia, rootURL: URL? = nil) {
        deleteFiles(displayFilename: media.displayFilename,
                    thumbnailFilename: media.thumbnailFilename, rootURL: rootURL)
    }

    static func deleteFiles(displayFilename: String, thumbnailFilename: String, rootURL: URL? = nil) {
        guard let directory = try? mediaDirectory(rootURL: rootURL) else { return }
        for filename in [displayFilename, thumbnailFilename] {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(filename))
        }
    }

    static func fileExists(for media: CookingMedia, thumbnail: Bool, rootURL: URL? = nil) -> Bool {
        guard let url = fileURL(for: media, thumbnail: thumbnail, rootURL: rootURL) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    private static func mediaDirectory(rootURL: URL?) throws -> URL {
        let base: URL
        if let rootURL { base = rootURL }
        else {
            base = try FileManager.default.url(for: .applicationSupportDirectory,
                                               in: .userDomainMask, appropriateFor: nil, create: true)
        }
        let directory = base.appendingPathComponent("StayGrubbyMedia", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func thumbnail(source: CGImageSource, maximumPixels: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixels,
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func jpegData(_ image: CGImage, preferredQuality: CGFloat, softLimit: Int) -> Data? {
        var quality = preferredQuality
        var best: Data?
        repeat {
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)
            else { return nil }
            CGImageDestinationAddImage(destination, image,
                                       [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { return nil }
            best = data as Data
            quality -= 0.08
        } while (best?.count ?? 0) > softLimit && quality >= 0.60
        return best
    }
}
