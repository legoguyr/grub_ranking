import SwiftUI

struct KitchenSettings<AccountUtilities: View>: View {
    @Environment(\.socialRequest) private var request
    @ViewBuilder var account: () -> AccountUtilities
    var body: some View {
        List {
            NavigationLink("Account & Profile") {
                ScrollView { VStack(alignment: .leading, spacing: 20) { SocialIdentitySection(); account() }.padding() }
                    .navigationTitle("Account & Profile").navigationBarTitleDisplayMode(.inline)
            }.accessibilityIdentifier("settings-account")
            if request != nil {
                Section("Social") {
                    NavigationLink("Sharing defaults") { SocialSettingsView() }.accessibilityIdentifier("social-settings-open")
                    NavigationLink("Sent Requests") { FriendsView(section: .outgoing) }
                }
                Section("Privacy & Safety") {
                    NavigationLink("Blocked Accounts") { FriendsView(section: .blocked) }
                    NavigationLink("Discoverability & profile privacy") { SocialIdentitySection().padding().navigationTitle("Profile privacy") }
                }
            }
            Section("Support & About") {
                Link("Support", destination: URL(string: "mailto:support@staygrubby.com")!)
                Link("Privacy Policy", destination: URL(string: "https://staygrubby.com/privacy")!)
                Text("StayGrubby \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))")
            }
        }.navigationTitle("Settings").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
    }
}
