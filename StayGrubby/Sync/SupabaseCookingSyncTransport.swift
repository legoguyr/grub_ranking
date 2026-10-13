import Foundation
import Supabase

nonisolated enum CookingSyncError: Error, Equatable {
    case conflict, rejected, authenticationRequired, unavailable
    var diagnosticCode: String {
        switch self {
        case .conflict: "revision-conflict"
        case .rejected: "operation-rejected"
        case .authenticationRequired: "authentication-required"
        case .unavailable: "network-unavailable"
        }
    }
}

@MainActor protocol AccountSyncBackend: AccountLibraryBackend {
    func applyCookingOperation(_ envelope: SyncEnvelope) async throws -> SyncReceipt
}

nonisolated struct CookingOperationReceipt: Codable, Sendable {
    let operationID: UUID
    let storeID: UUID
    let accountID: UUID
    let payloadHash: String
    let revision: Int
    func validated(for envelope: SyncEnvelope) throws -> SyncReceipt {
        guard operationID == envelope.operationID, storeID == envelope.storeID,
              accountID == envelope.accountID, payloadHash == envelope.payloadHash, revision > envelope.expectedRevision
        else { throw SyncFoundationError.invalidReceipt }
        return SyncReceipt(operationID: operationID, revision: revision)
    }
}

/// SDK adds the current authenticated session. There is no service credential or media byte path.
extension SupabaseAccountBackend: AccountSyncBackend {
    func applyCookingOperation(_ envelope: SyncEnvelope) async throws -> SyncReceipt {
        guard let user = client.auth.currentSession?.user.id else { throw CookingSyncError.authenticationRequired }
        struct Parameters: Encodable { let envelope: SyncEnvelope }
        do {
            let response = try await client.schema("api").rpc("apply_cooking_operation", params: Parameters(envelope: envelope)).execute()
            try Task.checkCancellation()
            guard client.auth.currentSession?.user.id == user else { throw AccountFoundationError.identityChanged }
            return try JSONDecoder().decode(CookingOperationReceipt.self, from: response.data).validated(for: envelope)
        } catch let error as PostgrestError {
            // SQL errors can include user data: expose/persist only a fixed diagnostic code.
            switch error.code {
            case "40001": throw CookingSyncError.conflict
            case "42501", "PGRST301", "PGRST302": throw CookingSyncError.authenticationRequired
            default: throw CookingSyncError.rejected
            }
        }
    }
}

nonisolated struct AuthorizedCookingTransport: SyncTransport {
    let sendOperation: @Sendable (SyncEnvelope) async throws -> SyncReceipt
    func send(_ envelope: SyncEnvelope) async throws -> SyncReceipt { try await sendOperation(envelope) }
}
