import SwiftUI
import AuthenticationServices
import Accessibility

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

/// Presentation only. AccountApplicationRoot remains the sole authority for app access.
struct AuthenticationGateView: View {
    @Environment(AccountSessionCoordinator.self) private var session
    @Environment(\.dynamicTypeSize) private var typeSize
    let setupFailed: Bool
    let retrySetup: () -> Void
    @State private var showingPrivacyPolicy = false

    private var presentation: AuthenticationGatePresentation {
        .init(state: session.state, setupFailed: setupFailed, isSigningOut: session.isSigningOut)
    }

    var body: some View {
        // Large text gets one continuous scroll, so the action area can never
        // consume the entire screen. At standard sizes, sign-in stays in reach.
        ScrollView {
            VStack(alignment: .leading, spacing: SGTheme.Space.large) {
                introduction
                if typeSize.isAccessibilitySize { authentication }
            }
            .frame(maxWidth: SGTheme.Size.sharingContentMaximum, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, SGTheme.Space.large)
            .padding(.vertical, SGTheme.Space.medium)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !typeSize.isAccessibilitySize {
                authentication
                    .frame(maxWidth: SGTheme.Size.sharingContentMaximum)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, SGTheme.Space.large)
                    .padding(.vertical, SGTheme.Space.medium)
                    .background(SGTheme.ColorToken.background)
            }
        }
        .background(SGTheme.ColorToken.background)
        .tint(SGTheme.ColorToken.accent)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("authentication-gate")
        .sheet(isPresented: $showingPrivacyPolicy) { PrivacyPolicyView() }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
            // The canonical PNG includes transparent margins; display the
            // existing artwork without reconstructing its lettering.
            Image("StayGrubbyWordmark")
                .resizable().scaledToFit()
                .frame(width: 168, height: 168)
                .frame(height: 100).clipped()
                .accessibilityRepresentation {
                    Text("#stayGRUBBY").accessibilityIdentifier("onboarding-brand")
                }

            VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                SGEyebrow(text: "Cook · Rank · Share")
                Text("Good food.\nYour signature.")
                    .font(SGTheme.TypeRole.hero)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("Keep your cooks in your Food Bible. Find your Signature Dishes. Share a little inspiration.")
                    .font(.body).foregroundStyle(.secondary)
            }

            comparisonExample

            VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
                story("Your Food Bible", detail: "Save dishes, photos, and every new version.", symbol: "book.closed")
                story("Share your favorites", detail: "Send a dish, your Signature Dishes or your Kitchen when you want.", symbol: "square.and.arrow.up")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding-story")
    }

    private var comparisonExample: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            Text("Which would you cook again?").font(.headline)
            HStack(spacing: SGTheme.Space.medium) {
                exampleDish("🍝", name: "Sunday pasta")
                Image(systemName: "arrow.left.arrow.right")
                    .font(.subheadline).foregroundStyle(.secondary)
                exampleDish("🌮", name: "Taco night")
            }
            Text("Rank by comparison. No made-up numbers.")
                .font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .sgCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank by comparison. Which would you cook again: Sunday pasta or Taco night? No made-up numbers.")
        .accessibilityIdentifier("onboarding-comparison-example")
    }

    private func exampleDish(_ emoji: String, name: String) -> some View {
        VStack(spacing: SGTheme.Space.hairline) {
            Text(emoji).font(.system(size: 36))
            Text(name).font(.caption.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private func story(_ title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: SGTheme.Space.medium) {
            Image(systemName: symbol)
                .font(.title3).frame(width: 28)
                .foregroundStyle(.secondary).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: SGTheme.Space.hairline) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private var authentication: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                HStack(alignment: .firstTextBaseline, spacing: SGTheme.Space.small) {
                    if presentation.isWorking { ProgressView().accessibilityHidden(true) }
                    Text(presentation.title).font(.headline)
                }
                Text(presentation.message)
                    .font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(presentation.isError ? "account-sign-in-error" : "account-status")
            .onChange(of: presentation.title) { _, _ in
                if presentation.isError {
                    AccessibilityNotification.Announcement("\(presentation.title) \(presentation.message)").post()
                }
            }

            if case .deletionRequired = session.state {
                AccountDeletionAuthorizationView(canCancel: false, cancel: {})
            } else {
                // Never conditionally replace this control while Apple owns its request.
                NativeAppleAuthenticationButton()
            }

            if let retry = presentation.retry {
                Button("Try again") {
                    switch retry {
                    case .account: Task { await session.retry() }
                    case .library: retrySetup()
                    }
                }
                .buttonStyle(SGButtonStyle(prominent: true))
                .disabled(session.isSigningOut)
                .accessibilityIdentifier(retry == .account ? "account-retry" : "library-retry")
            }
            if let label = presentation.signOutTitle {
                Button(label) { Task { await session.signOut() } }
                    .font(.subheadline).frame(minHeight: SGTheme.Size.minimumTap)
                    .disabled(session.isSigningOut)
                    .accessibilityIdentifier("account-sign-out")
            }
            if session.remoteSignOutFailed {
                Text("Signed out on this device. The server couldn’t confirm sign-out.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Button("Privacy Policy") { showingPrivacyPolicy = true }
                .font(.footnote).frame(minHeight: SGTheme.Size.minimumTap)
                .accessibilityIdentifier("privacy-policy-open")
        }
    }
}

#Preview("Welcome · Dark") {
    AuthenticationGateView(setupFailed: false, retrySetup: {})
        .environment(AccountSessionCoordinator()).preferredColorScheme(.dark)
}

#Preview("Welcome · Large text") {
    AuthenticationGateView(setupFailed: false, retrySetup: {})
        .environment(AccountSessionCoordinator())
        .environment(\.dynamicTypeSize, .accessibility3).preferredColorScheme(.light)
}

#Preview("Sign-in retry") {
    let session = AccountSessionCoordinator()
    let request = session.beginAppleSignIn()
    if let request { session.appleAuthorizationFailed(requestID: request.id, cancelled: false) }
    return AuthenticationGateView(setupFailed: false, retrySetup: {})
        .environment(session).preferredColorScheme(.dark)
}
