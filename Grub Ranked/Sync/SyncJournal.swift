import Foundation
import SwiftData
import CryptoKit

@Model final class SyncStoreBinding {
    @Attribute(.unique) var key: String = "store"
    var storeID: UUID
    var accountID: UUID?
    var enabled: Bool
    var restorationRequired: Bool
    var acceptedRevision: Int
    var acceptedSnapshotData: Data?
    init(accountID: UUID, restorationRequired: Bool = true) {
        storeID = UUID(); self.accountID = accountID; enabled = false
        self.restorationRequired = restorationRequired; acceptedRevision = -1
    }
}

@Model final class SyncOperation {
    @Attribute(.unique) var id: UUID
    var storeID: UUID
    var accountID: UUID
    var sequence: Int
    var kind: String
    var payload: Data
    var payloadHash: String
    var expectedRevision: Int
    var predecessorID: UUID?
    var createdAt: Date
    var attemptCount: Int = 0
    var nextRetryAt: Date?
    var lastError: String?
    var acknowledgedRevision: Int?
    var acknowledgedAt: Date?
    init(binding: SyncStoreBinding, sequence: Int, kind: String, payload: Data, predecessorID: UUID?) {
        id = UUID(); storeID = binding.storeID; accountID = binding.accountID!
        self.sequence = sequence; self.kind = kind; self.payload = payload
        payloadHash = SyncJournal.digest(payload); expectedRevision = binding.acceptedRevision
        self.predecessorID = predecessorID; createdAt = .now
    }
}

@Model final class SyncTombstone {
    @Attribute(.unique) var key: String
    var entityCode: String
    var entityKey: String
    var deletedAt: Date
    var operationID: UUID?
    var acknowledgedRevision: Int?
    init(_ reference: SyncReference, operationID: UUID? = nil) {
        key = reference.identity; entityCode = reference.entity.rawValue; entityKey = reference.key
        deletedAt = .now; self.operationID = operationID
    }
    var reference: SyncReference? {
        SyncEntity(rawValue: entityCode).map { SyncReference(entity: $0, key: entityKey) }
    }
}

nonisolated struct SyncChanges: Codable, Equatable, Sendable {
    var upserts: [SyncRecord]
    var deletions: [SyncReference]
}
nonisolated struct SyncEnvelope: Codable, Equatable, Sendable {
    var operationID: UUID
    var storeID: UUID
    var accountID: UUID
    var kind: String
    var payload: Data
    var payloadHash: String
    var expectedRevision: Int
    var predecessorID: UUID?
}
nonisolated enum SyncFoundationError: Error, LocalizedError {
    case restorationRequired, wrongAccount, invalidGraph, pendingLocalChanges, staleRevision, revisionCollision, deletedIdentity, invalidReceipt
    var errorDescription: String? {
        switch self {
        case .restorationRequired: "Restore this account before opening its ranking. No new ranking has been created."
        case .wrongAccount: "The data belongs to a different account."
        case .invalidGraph: "The transferred cooking data is incomplete or invalid."
        case .pendingLocalChanges: "Local changes must be synchronized or resolved before applying remote data."
        case .staleRevision: "This remote state is older than the accepted account state."
        case .revisionCollision: "Different remote data used the same revision."
        case .deletedIdentity: "Remote data would restore an identity that was deleted."
        case .invalidReceipt: "The synchronization acknowledgment does not match the pending operation."
        }
    }
}

@MainActor enum SyncJournal {
    struct Baseline { let records: [SyncRecord] }
    nonisolated static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func binding(_ context: ModelContext) throws -> SyncStoreBinding? {
        let bindings = try context.fetch(FetchDescriptor<SyncStoreBinding>())
        guard bindings.count <= 1 else { throw SyncFoundationError.wrongAccount }
        return bindings.first
    }
    static func requireReady(_ context: ModelContext) throws {
        if try binding(context)?.restorationRequired == true { throw SyncFoundationError.restorationRequired }
    }
    static func enable(_ context: ModelContext) throws {
        guard let binding = try binding(context), binding.accountID != nil else { throw SyncFoundationError.wrongAccount }
        try requireReady(context)
        try CookingGraphExport.snapshot(context: context).validate()
        binding.enabled = true
        try context.save()
    }
    static func begin(_ context: ModelContext) throws -> Baseline? {
        guard let binding = try binding(context), binding.enabled else { return nil }
        guard binding.accountID != nil else { throw SyncFoundationError.wrongAccount }
        try requireReady(context)
        let graph = try CookingGraphExport.snapshot(context: context)
        try graph.validate()
        return Baseline(records: try graph.records())
    }
    /// Stages infrastructure in the caller's domain transaction; never saves separately.
    static func stage(_ baseline: Baseline?, kind: String, context: ModelContext) throws {
        guard let baseline, let binding = try binding(context) else { return }
        let graph = try CookingGraphExport.snapshot(context: context)
        try graph.validate()
        let before = Dictionary(uniqueKeysWithValues: baseline.records.map { ($0.reference, $0.data) })
        let after = try graph.records()
        let surviving = Set(after.map(\.reference))
        let removed = baseline.records.map(\.reference).filter { !surviving.contains($0) }
        let changed = after.filter { before[$0.reference] != $0.data }
        guard !changed.isEmpty || !removed.isEmpty else { return }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let payload = try encoder.encode(SyncChanges(upserts: changed, deletions: removed))
        let previous = try context.fetch(FetchDescriptor<SyncOperation>()).max { $0.sequence < $1.sequence }
        let operation = SyncOperation(binding: binding, sequence: (previous?.sequence ?? 0) + 1,
                                      kind: kind, payload: payload, predecessorID: previous?.id)
        context.insert(operation)
        let existing = Set(try context.fetch(FetchDescriptor<SyncTombstone>()).map(\.key))
        for reference in removed where !existing.contains(reference.identity) {
            context.insert(SyncTombstone(reference, operationID: operation.id))
        }
    }
    static func pending(_ context: ModelContext) throws -> [SyncOperation] {
        try context.fetch(FetchDescriptor<SyncOperation>(predicate: #Predicate { $0.acknowledgedRevision == nil }))
            .sorted { $0.sequence < $1.sequence }
    }
    static func envelope(_ operation: SyncOperation) -> SyncEnvelope {
        SyncEnvelope(operationID: operation.id, storeID: operation.storeID, accountID: operation.accountID,
                     kind: operation.kind, payload: operation.payload, payloadHash: operation.payloadHash,
                     expectedRevision: operation.expectedRevision, predecessorID: operation.predecessorID)
    }
    static func acknowledge(_ envelope: SyncEnvelope, revision: Int, context: ModelContext) throws {
        guard let binding = try binding(context), binding.accountID == envelope.accountID,
              binding.storeID == envelope.storeID,
              let operation = try context.fetch(FetchDescriptor<SyncOperation>()).first(where: { $0.id == envelope.operationID }),
              self.envelope(operation) == envelope else { throw SyncFoundationError.invalidReceipt }
        if let accepted = operation.acknowledgedRevision {
            guard accepted == revision else { throw SyncFoundationError.invalidReceipt }; return
        }
        guard try pending(context).first?.id == operation.id, revision > binding.acceptedRevision else { throw SyncFoundationError.invalidReceipt }
        do {
            operation.acknowledgedRevision = revision; operation.acknowledgedAt = .now
            operation.nextRetryAt = nil; operation.lastError = nil
            binding.acceptedRevision = revision; binding.acceptedSnapshotData = nil
            for tombstone in try context.fetch(FetchDescriptor<SyncTombstone>()) where tombstone.operationID == operation.id {
                tombstone.acknowledgedRevision = revision
            }
            try context.save()
        } catch { context.rollback(); throw error }
    }
}

nonisolated struct SyncReceipt: Sendable { var operationID: UUID; var revision: Int }
nonisolated protocol SyncTransport: Sendable {
    func send(_ envelope: SyncEnvelope) async throws -> SyncReceipt
}

/// Explicitly invoked infrastructure; no network worker is started by guest launch.
@MainActor final class SyncDispatcher {
    private var sending = false
    func flush(context callerContext: ModelContext, transport: any SyncTransport, now: Date = .now) async throws {
        guard !sending else { return }; sending = true; defer { sending = false }
        // Network suspension must never roll back another caller's unsaved edits.
        let context = ModelContext(callerContext.container)
        guard try SyncJournal.binding(context)?.enabled == true else { return }
        for operation in try SyncJournal.pending(context) {
            if let retry = operation.nextRetryAt, retry > now { return }
            let envelope = SyncJournal.envelope(operation)
            do {
                operation.attemptCount += 1; try context.save()
                let receipt = try await transport.send(envelope)
                guard receipt.operationID == operation.id else { throw SyncFoundationError.invalidReceipt }
                try SyncJournal.acknowledge(envelope, revision: receipt.revision, context: context)
            } catch {
                context.rollback()
                // Refetch after rollback; keep the original immutable operation payload/UUID.
                if let saved = try SyncJournal.pending(context).first(where: { $0.id == envelope.operationID }) {
                    saved.lastError = String(describing: error)
                    saved.nextRetryAt = now.addingTimeInterval(min(300, pow(2, Double(min(saved.attemptCount, 8)))))
                    try context.save()
                }
                throw error
            }
        }
    }
}
