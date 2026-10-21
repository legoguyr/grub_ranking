import SwiftUI

nonisolated struct CookingSharingSelection: Equatable, Sendable {
    var accountDefault = false
    var override: Bool?
    var configured: Bool?
    var loading = true
    var loadFailed = false
    var selected: Bool { override ?? accountDefault }
    mutating func receive(_ identity: SocialIdentity) {
        accountDefault = identity.sharingDefault; configured = identity.isConfigured; loading = false; loadFailed = false
    }
    mutating func unavailable() { accountDefault = false; loading = false; loadFailed = true }
}

struct CookingSharingChoice: View {
    @Binding var selection: CookingSharingSelection
    var body: some View {
        SGFormSection(title: "Sharing") {
            Toggle("Share with Friends", isOn: Binding(get: { selection.selected }, set: { selection.override = $0 }))
                .foregroundStyle(SGTheme.ColorToken.primaryText)
                .disabled(selection.loading || selection.configured == false).accessibilityIdentifier("cook-share-with-friends")
            if selection.loading { ProgressView("Loading sharing default") }
            else if selection.configured == false {
                Text("Set up your social identity in Profile to share. This cook will stay private.")
            } else if selection.loadFailed {
                Text("Default unavailable, so this starts private. You can choose to share; publication will wait for your social profile and connection.")
            } else {
                Text("Shares this completed cook, its food photo and unlocked score. Private notes and ranking history stay yours. You can change this choice for each new cook.")
            }
        }.font(.footnote).foregroundStyle(.secondary)
    }
}
