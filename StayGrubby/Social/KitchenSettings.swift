import SwiftUI

struct KitchenSettings<AccountUtilities: View>: View {
    @Environment(\.socialRequest) private var request
    @ViewBuilder var account: () -> AccountUtilities
    var body: some View {
        List {
            Section("Account") {
                if request != nil {
                    NavigationLink { SocialIdentitySection() } label: { Label("Profile", systemImage: "person.crop.circle") }
                        .accessibilityIdentifier("settings-account")
                }
                NavigationLink { Form { account() }.navigationTitle("Account & Sync").navigationBarTitleDisplayMode(.inline) } label: {
                    Label("Account & Sync", systemImage: "arrow.triangle.2.circlepath")
                }.accessibilityIdentifier("settings-sync")
            }
            if request != nil {
                Section("Social") {
                    NavigationLink("Sharing Preferences") { SocialSettingsView() }.accessibilityIdentifier("social-settings-open")
                    NavigationLink("Sent Requests") { FriendsView(section: .outgoing) }
                }
                Section {
                    NavigationLink("Blocked Accounts") { FriendsView(section: .blocked) }
                } header: { Text("Privacy & Safety") } footer: {
                    Text("Sharing is for mutual Sous Chefs. Discovery is optional and can be changed in Profile; it does not make your cooking library public.")
                }
            }
            Section("Support & About") {
                Link("Privacy Policy", destination: URL(string: "https://staygrubby.com/privacy")!)
                Link("Support", destination: URL(string: "mailto:support@staygrubby.com")!)
                LabeledContent("StayGrubby", value: "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))")
            }
        }.listStyle(.insetGrouped).scrollContentBackground(.hidden).background(SGTheme.ColorToken.background)
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
    }
}
