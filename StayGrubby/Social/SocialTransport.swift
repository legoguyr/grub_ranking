import SwiftUI
import Supabase

@MainActor protocol SocialBackend: AccountBackend {
    func socialRequest(endpoint: String, action: String, payload: SocialPayload) async throws -> Data
}
extension SupabaseAccountBackend: SocialBackend {
    func socialRequest(endpoint: String, action: String, payload: SocialPayload) async throws -> Data {
        guard ["social_identity", "social_people", "social_report", "social_content", "social_feed"].contains(endpoint), let user = client.auth.currentSession?.user.id else { throw AccountFoundationError.accountNotResolved }
        struct Parameters: Encodable { let action: String; let payload: SocialPayload }
        let response = try await client.schema("api").rpc(endpoint, params: Parameters(action: action, payload: payload)).execute()
        try Task.checkCancellation()
        guard client.auth.currentSession?.user.id == user else { throw AccountFoundationError.identityChanged }
        return response.data
    }
}
typealias SocialRequest = @MainActor (String, String, SocialPayload) async throws -> Data
private struct SocialRequestKey: EnvironmentKey { static let defaultValue: SocialRequest? = nil }
extension EnvironmentValues {
    var socialRequest: SocialRequest? { get { self[SocialRequestKey.self] } set { self[SocialRequestKey.self] = newValue } }
}
