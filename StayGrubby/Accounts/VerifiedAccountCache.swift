import Foundation
import Security

/// A prior server-verified mapping, separate from SDK session credentials. No token/nonce.
nonisolated enum VerifiedAccountCache {
    private static var service: String { (Bundle.main.bundleIdentifier ?? "com.guyrettig.StayGrubby") + ".verified-account" }
    private static func query(_ user: UUID) -> [String: Any] {
        [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:user.uuidString]
    }
    static func save(_ account: ProvisionedAccount) throws {
        let data = try JSONEncoder().encode(account), q = query(account.authUserID)
        let result = SecItemUpdate(q as CFDictionary,[kSecValueData as String:data] as CFDictionary)
        if result == errSecItemNotFound {
            var values = q; values[kSecValueData as String] = data
            values[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(values as CFDictionary,nil) == errSecSuccess else { throw AccountFoundationError.invalidResolution }
        } else if result != errSecSuccess { throw AccountFoundationError.invalidResolution }
    }
    static func load(_ identity: AuthenticatedIdentity) throws -> ProvisionedAccount? {
        var q = query(identity.userID); q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?; let status = SecItemCopyMatching(q as CFDictionary,&result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw AccountFoundationError.invalidResolution }
        let account = try JSONDecoder().decode(ProvisionedAccount.self,from:data)
        try account.validate(for:identity)
        guard account.libraryState == .initialized else { return nil }
        return account
    }
    static func remove(_ identity: AuthenticatedIdentity) { SecItemDelete(query(identity.userID) as CFDictionary) }
}

nonisolated func isOfflineConnectionError(_ error: Error) -> Bool {
    let value = error as NSError
    return value.domain == NSURLErrorDomain && [NSURLErrorNotConnectedToInternet,NSURLErrorTimedOut,NSURLErrorNetworkConnectionLost,NSURLErrorCannotFindHost,NSURLErrorCannotConnectToHost,NSURLErrorDNSLookupFailed].contains(value.code)
}
