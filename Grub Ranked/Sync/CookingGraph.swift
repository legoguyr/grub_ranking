import Foundation
import SwiftData

// Codable dates use Swift reference-date doubles, never formatted display dates.
nonisolated struct LibraryTransfer: Codable, Equatable, Sendable {
    var key: String
    var globalRankingID: UUID
    var bridgeVersion: Int
    @MainActor init(_ value: CookingLibrary) {
        self.key = value.key
        self.globalRankingID = value.globalRankingID
        self.bridgeVersion = value.bridgeVersion
    }
}

nonisolated struct RankingTransfer: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var createdAt: Date
    @MainActor init(_ value: RankingList) {
        self.id = value.id
        self.name = value.name
        self.createdAt = value.createdAt
    }
}

nonisolated struct DishTransfer: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var defaultCategoryCode: String
    var createdAt: Date
    var sourceID: UUID?
    @MainActor init(_ value: Dish) {
        self.id = value.id
        self.name = value.name
        self.defaultCategoryCode = value.defaultCategoryCode
        self.createdAt = value.createdAt
        self.sourceID = value.source?.id
    }
}

nonisolated struct AttemptTransfer: Codable, Equatable, Sendable {
    var id: UUID
    var rankedItemID: UUID
    var cookedAt: Date?
    var versionTitle: String?
    var notes: String?
    var categoryCode: String
    var sequenceNumber: Int
    var createdAt: Date
    var updatedAt: Date
    var isLegacyImport: Bool
    var dishID: UUID?
    var tagKeys: [String]
    @MainActor init(_ value: CookingAttempt) {
        self.id = value.id
        self.rankedItemID = value.rankedItemID
        self.cookedAt = value.cookedAt
        self.versionTitle = value.versionTitle
        self.notes = value.notes
        self.categoryCode = value.categoryCode
        self.sequenceNumber = value.sequenceNumber
        self.createdAt = value.createdAt
        self.updatedAt = value.updatedAt
        self.isLegacyImport = value.isLegacyImport
        self.dishID = value.dish?.id
        self.tagKeys = value.tags.map(\.key).sorted()
    }
}

nonisolated struct RankedItemTransfer: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var createdAt: Date
    var strength: Double
    var uncertainty: Double
    var sessionDiagnosticsData: Data?
    var rankingID: UUID?
    @MainActor init(_ value: RankedItem) {
        self.id = value.id
        self.name = value.name
        self.createdAt = value.createdAt
        self.strength = value.strength
        self.uncertainty = value.uncertainty
        self.sessionDiagnosticsData = value.sessionDiagnosticsData
        self.rankingID = value.list?.id
    }
}

nonisolated struct ComparisonTransfer: Codable, Equatable, Sendable {
    var id: UUID
    var firstItemID: UUID
    var secondItemID: UUID
    var preferredItemID: UUID?
    var isTie: Bool
    var timestamp: Date
    var rankingID: UUID?
    @MainActor init(_ value: Comparison) {
        self.id = value.id
        self.firstItemID = value.firstItemID
        self.secondItemID = value.secondItemID
        self.preferredItemID = value.preferredItemID
        self.isTie = value.isTie
        self.timestamp = value.timestamp
        self.rankingID = value.list?.id
    }
}

nonisolated struct TagTransfer: Codable, Equatable, Sendable {
    var key: String
    var kindCode: String
    var value: String
    var label: String
    @MainActor init(_ value: CookingTag) {
        self.key = value.key
        self.kindCode = value.kindCode
        self.value = value.value
        self.label = value.label
    }
}

nonisolated struct MediaTransfer: Codable, Equatable, Sendable {
    var id: UUID
    var kindCode: String
    var displayFilename: String
    var thumbnailFilename: String
    var pixelWidth: Int
    var pixelHeight: Int
    var sortOrder: Int
    var createdAt: Date
    var attemptID: UUID?
    @MainActor init(_ value: CookingMedia) {
        self.id = value.id
        self.kindCode = value.kindCode
        self.displayFilename = value.displayFilename
        self.thumbnailFilename = value.thumbnailFilename
        self.pixelWidth = value.pixelWidth
        self.pixelHeight = value.pixelHeight
        self.sortOrder = value.sortOrder
        self.createdAt = value.createdAt
        self.attemptID = value.attempt?.id
    }
}

nonisolated struct SourceTransfer: Codable, Equatable, Sendable {
    var id: UUID
    var typeCode: String
    var createdAt: Date
    var updatedAt: Date
    var dishID: UUID?
    var cookbookTitle: String?
    var cookbookAuthors: String?
    var cookbookRecipeName: String?
    var cookbookPage: String?
    var restaurantName: String?
    var restaurantDishName: String?
    var restaurantLocation: String?
    var onlineRecipeName: String?
    var onlineWebsite: String?
    var onlineURL: String?
    var socialCreator: String?
    var socialPlatform: String?
    var socialURL: String?
    var socialDishName: String?
    var friendName: String?
    var friendNote: String?
    var otherName: String?
    var otherDetails: String?
    @MainActor init(_ value: DishSource) {
        self.id = value.id
        self.typeCode = value.typeCode
        self.createdAt = value.createdAt
        self.updatedAt = value.updatedAt
        self.dishID = value.dish?.id
        self.cookbookTitle = value.cookbookTitle
        self.cookbookAuthors = value.cookbookAuthors
        self.cookbookRecipeName = value.cookbookRecipeName
        self.cookbookPage = value.cookbookPage
        self.restaurantName = value.restaurantName
        self.restaurantDishName = value.restaurantDishName
        self.restaurantLocation = value.restaurantLocation
        self.onlineRecipeName = value.onlineRecipeName
        self.onlineWebsite = value.onlineWebsite
        self.onlineURL = value.onlineURL
        self.socialCreator = value.socialCreator
        self.socialPlatform = value.socialPlatform
        self.socialURL = value.socialURL
        self.socialDishName = value.socialDishName
        self.friendName = value.friendName
        self.friendNote = value.friendNote
        self.otherName = value.otherName
        self.otherDetails = value.otherDetails
    }
}

nonisolated enum SyncEntity: String, Codable, CaseIterable, Sendable {
    case library, ranking, dish, attempt, rankedItem, comparison, source, tag, media, legacyArchive
}
nonisolated struct SyncReference: Codable, Hashable, Sendable {
    var entity: SyncEntity
    var key: String
    var identity: String { "\(entity.rawValue):\(UUID(uuidString: key)?.uuidString ?? key)" }
}
nonisolated struct SyncRecord: Codable, Equatable, Sendable {
    var reference: SyncReference
    var data: Data
}
nonisolated struct CookingGraph: Codable, Equatable, Sendable {
    var formatVersion = 1
    var deletions: [SyncReference] = []
    var accountID: UUID?
    var libraries: [LibraryTransfer]
    var rankings: [RankingTransfer]
    var dishes: [DishTransfer]
    var attempts: [AttemptTransfer]
    var items: [RankedItemTransfer]
    var comparisons: [ComparisonTransfer]
    var sources: [SourceTransfer]
    var tags: [TagTransfer]
    var media: [MediaTransfer]
    // The legacy starter Item has no stable domain ID. Preserve its values as an archive.
    var legacyItemDates: [Date]

    func encoded() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
    static func decode(_ data: Data) throws -> Self { try JSONDecoder().decode(Self.self, from: data) }
    func records() throws -> [SyncRecord] {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        var result: [SyncRecord] = []
        func append<T: Encodable>(_ values: [T], _ entity: SyncEntity, key: (T) -> String) throws {
            for value in values { result.append(SyncRecord(reference: SyncReference(entity: entity, key: key(value)), data: try encoder.encode(value))) }
        }
        try append(libraries, .library) { $0.key }
        try append(rankings, .ranking) { $0.id.uuidString }
        try append(dishes, .dish) { $0.id.uuidString }
        try append(attempts, .attempt) { $0.id.uuidString }
        try append(items, .rankedItem) { $0.id.uuidString }
        try append(comparisons, .comparison) { $0.id.uuidString }
        try append(sources, .source) { $0.id.uuidString }
        try append(tags, .tag) { $0.key }
        try append(media, .media) { $0.id.uuidString }
        result.append(SyncRecord(reference: SyncReference(entity: .legacyArchive, key: "items"), data: try encoder.encode(legacyItemDates)))
        return result
    }
}

@MainActor enum CookingGraphExport {
    static func snapshot(context: ModelContext) throws -> CookingGraph {
        func fetch<T: PersistentModel>(_ type: T.Type) throws -> [T] {
            try context.fetch(FetchDescriptor<T>()).filter { !$0.isDeleted }
        }
        return CookingGraph(deletions: try fetch(SyncTombstone.self).compactMap(\.reference).sorted { $0.identity < $1.identity },
            accountID: try SyncJournal.binding(context)?.accountID,
            libraries: try fetch(CookingLibrary.self).map(LibraryTransfer.init).sorted { $0.key < $1.key },
            rankings: try fetch(RankingList.self).map(RankingTransfer.init).sorted { $0.id.uuidString < $1.id.uuidString },
            dishes: try fetch(Dish.self).map(DishTransfer.init).sorted { $0.id.uuidString < $1.id.uuidString },
            attempts: try fetch(CookingAttempt.self).map(AttemptTransfer.init).sorted { $0.id.uuidString < $1.id.uuidString },
            items: try fetch(RankedItem.self).map(RankedItemTransfer.init).sorted { $0.id.uuidString < $1.id.uuidString },
            comparisons: try fetch(Comparison.self).map(ComparisonTransfer.init).sorted { $0.id.uuidString < $1.id.uuidString },
            sources: try fetch(DishSource.self).map(SourceTransfer.init).sorted { $0.id.uuidString < $1.id.uuidString },
            tags: try fetch(CookingTag.self).map(TagTransfer.init).sorted { $0.key < $1.key },
            media: try fetch(CookingMedia.self).map(MediaTransfer.init).sorted { $0.id.uuidString < $1.id.uuidString },
            legacyItemDates: try fetch(Item.self).map(\.timestamp).sorted())
    }
}
