import Foundation
import CryptoKit
import Security
import Supabase
import AuthenticationServices

/// Ephemeral secrets are deliberately neither Codable nor part of observable UI state.
nonisolated struct AppleSignInNonce: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    let raw: String
    var hash: String { SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined() }
    static func generate() throws -> Self {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw AppleSignInError.randomnessUnavailable
        }
        // 256 random bits; base64url has no modulo bias or rejected-byte loop.
        return Self(raw: Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: ""))
    }
    var description: String { "AppleSignInNonce(redacted)" }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

nonisolated struct AppleSignInRequest: Equatable {
    let id: UUID
    let hashedNonce: String
    @MainActor func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.nonce = hashedNonce
        // Let Apple include the email claim for standard Supabase signup. The
        // app does not require callback email/name or use them as ownership.
        request.requestedScopes = [.email]
    }
}

nonisolated enum AppleSignInError: Error { case randomnessUnavailable, invalidToken }

nonisolated struct AppleSignInCredentials: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    private let identityToken: String
    private let rawNonce: String
    init(identityToken: Data?, nonce: AppleSignInNonce) throws {
        guard let identityToken, identityToken.count <= 16_384,
              let token = String(data: identityToken, encoding: .utf8) else { throw AppleSignInError.invalidToken }
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy {
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95
        } }) else { throw AppleSignInError.invalidToken }
        // Only structural validation here. Supabase verifies signature, claims and nonce.
        self.identityToken = token; rawNonce = nonce.raw
    }
    func supabaseCredentials() -> OpenIDConnectCredentials {
        OpenIDConnectCredentials(provider: .apple, idToken: identityToken, nonce: rawNonce)
    }
    var description: String { "AppleSignInCredentials(redacted)" }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}
