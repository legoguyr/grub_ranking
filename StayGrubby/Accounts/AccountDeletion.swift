import Foundation
import SwiftUI
import AuthenticationServices

nonisolated enum AccountDeletionCleanupJournal {
    private static let key = "staygrubby.pending-account-deletion-cleanup"
    static var pendingAccountID: UUID? {
        UserDefaults.standard.string(forKey: key).flatMap(UUID.init(uuidString:))
    }
    static func record(_ accountID: UUID) throws {
        UserDefaults.standard.set(accountID.uuidString.lowercased(), forKey: key)
    }
    static func clear(_ accountID: UUID) {
        guard pendingAccountID == accountID else { return }
        UserDefaults.standard.removeObject(forKey: key)
    }
}

nonisolated enum LocalAccountDataDeletion {
    static func directory(for accountID: UUID, root: URL) -> URL {
        root.appendingPathComponent("StayGrubbyAccounts", isDirectory: true)
            .appendingPathComponent(accountID.uuidString.lowercased(), isDirectory: true)
    }
    static func remove(_ accountID: UUID, root: URL? = nil) throws {
        let base = try root ?? FileManager.default.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = directory(for: accountID, root: base)
        guard directory.deletingLastPathComponent().lastPathComponent == "StayGrubbyAccounts" else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }
}

struct AccountDeletionAuthorizationView: View {
    @Environment(AccountSessionCoordinator.self) private var session
    @Environment(\.colorScheme) private var colorScheme
    let canCancel: Bool
    let cancel: () -> Void
    @State private var requestID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
            Text("Permanently delete account")
                .font(.system(.title2, design: .rounded, weight: .bold)).accessibilityAddTraits(.isHeader)
            Text("This permanently removes your StayGrubby account, cooking records, rankings, comparison history, and backed-up photos. This cannot be undone.")
                .font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if session.deletionProgress == .deleting {
                HStack { ProgressView(); Text("Deleting your account…") }
                    .accessibilityElement(children: .combine)
            } else {
                Text(session.deletionProgress == .failed
                     ? "Deletion did not complete. Your account has not been reported deleted. Verify with Apple and try again."
                     : "Verify with the Apple account linked to StayGrubby to continue.")
                    .font(.footnote).foregroundStyle(session.deletionProgress == .failed ? .red : .secondary)
                SignInWithAppleButton(.continue) { request in
                    guard let attempt = session.beginAccountDeletionAuthorization() else { return }
                    requestID = attempt.id; attempt.configure(request)
                } onCompletion: { result in
                    guard let id = requestID else { return }; requestID = nil
                    switch result {
                    case .success(let value):
                        let credential = value.credential as? ASAuthorizationAppleIDCredential
                        Task { await session.completeAccountDeletion(requestID: id,
                            identityToken: credential?.identityToken, authorizationCode: credential?.authorizationCode) }
                    case .failure(let error):
                        session.accountDeletionAuthorizationFailed(requestID: id,
                            cancelled: (error as? ASAuthorizationError)?.code == .canceled)
                    }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50).accessibilityIdentifier("account-delete-apple")
            }
            if canCancel && session.deletionProgress != .deleting {
                Button("Cancel") { session.cancelAccountDeletionRequest(); cancel() }
                    .buttonStyle(.bordered).accessibilityIdentifier("account-delete-cancel")
            }
        }
        .padding(SGTheme.Space.large).background(SGTheme.ColorToken.background)
        .interactiveDismissDisabled(session.deletionProgress == .deleting)
    }
}
