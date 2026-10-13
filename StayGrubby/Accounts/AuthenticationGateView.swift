import SwiftUI
import AuthenticationServices

struct NativeAppleAuthenticationButton: View {
    @Environment(AccountSessionCoordinator.self) private var session
    @Environment(\.colorScheme) private var colorScheme
    @State private var requestID: UUID?
    private var available: Bool { session.state == .guest || session.state == .signInFailed || session.state == .authorizingApple }
    var body: some View {
        // Keep the control mounted while Apple's sheet owns the request.
        SignInWithAppleButton(.signIn) { request in
            guard let attempt = session.beginAppleSignIn() else { return }
            requestID = attempt.id; attempt.configure(request)
        } onCompletion: { result in
            guard let id = requestID else { return }; requestID = nil
            switch result {
            case .success(let value):
                let token = (value.credential as? ASAuthorizationAppleIDCredential)?.identityToken
                Task { await session.completeAppleSignIn(requestID: id, identityToken: token) }
            case .failure(let error):
                session.appleAuthorizationFailed(requestID: id, cancelled: (error as? ASAuthorizationError)?.code == .canceled)
            }
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: available && !session.isSigningOut ? 50 : 0)
        .opacity(available && !session.isSigningOut ? 1 : 0)
        .accessibilityHidden(!available || session.isSigningOut)
        .disabled(!available || session.isSigningOut || session.state == .authorizingApple)
        .accessibilityIdentifier("account-sign-in-apple")
    }
}

struct AuthenticationGateView: View {
    @Environment(AccountSessionCoordinator.self) private var session
    let setupFailed: Bool
    let retrySetup: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SGTheme.Space.large) {
                Text("StayGrubby").font(.largeTitle.bold()).accessibilityIdentifier("onboarding-brand")
                Image(systemName: "fork.knife.circle.fill").font(.system(size: 64)).foregroundStyle(SGTheme.ColorToken.accent)
                Text("Cook. Remember. Rank.").font(.title.bold())
                Text("Keep the dishes you cook, remember what worked, and find your favorites through simple comparisons.")
                    .foregroundStyle(.secondary)
                status
                NativeAppleAuthenticationButton()
                if session.remoteSignOutFailed { Text("Signed out on this device. The server couldn't confirm sign-out.").font(.footnote).foregroundStyle(.secondary) }
            }.padding(SGTheme.Space.large).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(SGTheme.ColorToken.background)
        .accessibilityIdentifier("authentication-gate")
    }
    @ViewBuilder private var status: some View {
        switch session.state {
        case .guest: Text("Sign in with Apple to start your own cooking library.")
        case .signInFailed: Text("Couldn't sign in. Check your connection and try again.").accessibilityIdentifier("account-sign-in-error")
        case .authorizingApple: ProgressView("Waiting for Apple…")
        case .authenticating: ProgressView("Signing in…"); signOut("Cancel sign-in")
        case .loadingSession: ProgressView("Restoring your account…"); signOut("Sign out")
        case .provisioning: ProgressView("Setting up your account…"); signOut("Sign out")
        case .retryRequired:
            Text("Couldn't finish account setup. Your personal library stays protected.")
            Button("Try again") { Task { await session.retry() } }.buttonStyle(.borderedProminent).accessibilityIdentifier("account-retry")
            signOut("Sign out")
        case .resolved:
            if setupFailed {
                Text("Couldn't open your personal library. Your saved data has not been reset.")
                Button("Try again",action:retrySetup).buttonStyle(.borderedProminent).accessibilityIdentifier("library-retry")
            } else { ProgressView("Opening your cooking library…") }
            signOut("Sign out")
        }
    }
    private func signOut(_ label: String) -> some View {
        Button(label) { Task { await session.signOut() } }.buttonStyle(.bordered)
            .disabled(session.isSigningOut).accessibilityIdentifier("account-sign-out")
    }
}
