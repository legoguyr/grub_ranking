import SwiftUI

struct AccountView: View {
    @Environment(AccountSessionCoordinator.self) private var session
    #if DEBUG
    @Environment(\.endDevelopmentReview) private var endDevelopmentReview
    #endif
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SGTheme.Space.large) {
                Label("Your StayGrubby account",systemImage:"person.crop.circle").font(.title2.bold())
                #if DEBUG
                if let endDevelopmentReview {
                    Text("Development library").font(.headline)
                    Text("Demo data only. No authenticated account or cloud upload.").foregroundStyle(.secondary)
                    Button("Exit development library",action:endDevelopmentReview).accessibilityIdentifier("development-exit")
                } else { connectedAccount }
                #else
                connectedAccount
                #endif
            }.padding(SGTheme.Space.large).frame(maxWidth:.infinity,alignment:.leading)
        }
        .background(SGTheme.ColorToken.background)
        .navigationTitle("Account").toolbar(.hidden,for:.navigationBar)
        .safeAreaInset(edge:.top) { StayGrubbyHeader(page:"Account",searchText:.constant(""),searching:.constant(false)) }
    }
    @ViewBuilder private var connectedAccount: some View {
        if case .resolved(let account) = session.state {
            Label("Account connected",systemImage:"checkmark.circle.fill").foregroundStyle(SGTheme.ColorToken.accent)
            Text("Account ID: \(account.accountID.uuidString.lowercased())").font(.footnote).textSelection(.enabled)
            Button("Sign out") { Task { await session.signOut() } }
                .buttonStyle(.bordered).accessibilityIdentifier("account-sign-out")
        }
    }
}
