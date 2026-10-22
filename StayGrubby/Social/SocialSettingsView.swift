import SwiftUI

nonisolated enum SocialSharingCopy {
    static let explanation = "Choose the default for future New Dishes and New Versions. You can change Share with Sous Chefs for each cook. Shared new cooks include their food photo when present, their score when unlocked, Course, Cuisine and public recipe/source attribution. Private annotations stay yours. Existing cooking and posts stay unchanged."
}

struct SocialSettingsView: View {
    @Environment(\.socialRequest) private var request
    @State private var identity: SocialIdentity?
    @State private var automaticallyShare = false
    @State private var busy = false
    @State private var failed = false
    @State private var saved = false
    var body: some View {
        Form {
            Section("Sharing defaults") {
                if identity != nil {
                    Toggle("Automatically Share New Dishes", isOn: $automaticallyShare).accessibilityIdentifier("social-settings-default")
                        .disabled(busy)
                    Text(SocialSharingCopy.explanation)
                    Button(busy ? "Saving…" : "Save default") { Task { await save() } }
                        .disabled(busy || automaticallyShare == identity?.sharingDefault).accessibilityIdentifier("social-settings-save")
                    if saved { Label("Sharing default saved", systemImage: "checkmark.circle").accessibilityIdentifier("social-settings-saved") }
                } else if !failed { ProgressView("Loading social settings") }
            }
            if failed {
                Text("Couldn’t update the sharing default. Existing cooking and posts are unchanged.")
                Button("Retry") { Task { if identity == nil { await load() } else { await save() } } }
            }
        }.navigationTitle("Sharing Preferences").navigationBarTitleDisplayMode(.inline)
            .onChange(of: automaticallyShare) { _, _ in saved = false }
            .task { await load() }
    }
    private func load() async {
        guard let request else { failed = true; return }
        do {
            let latest = try JSONDecoder().decode(SocialIdentity.self, from: await request("social_identity", "get", .init()))
            try Task.checkCancellation(); identity = latest; automaticallyShare = latest.sharingDefault; failed = false
        } catch is CancellationError { } catch { failed = true }
    }
    private func save() async {
        guard let request else { return }; busy = true; failed = false
        defer { busy = false }
        do {
            let latest = try JSONDecoder().decode(SocialIdentity.self, from: await request("social_identity", "sharing", .init(automaticallyShareNewDishes: automaticallyShare)))
            try Task.checkCancellation(); identity = latest; automaticallyShare = latest.sharingDefault; saved = true
        } catch is CancellationError { } catch { failed = true }
    }
}
