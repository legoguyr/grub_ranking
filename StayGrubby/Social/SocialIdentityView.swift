import SwiftUI

struct SocialIdentitySection: View {
    @Environment(\.socialRequest) private var request
    @Environment(\.socialMedia) private var media
    @State private var identity: SocialIdentity?
    @State private var error = false
    @State private var editing = false
    var body: some View {
        if request != nil {
            VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                Text("Your StayGrubby identity").font(SGTheme.TypeRole.headline)
                if let identity {
                    HStack { SocialAvatar(name: identity.displayName, path: identity.avatarPath, size: 64); Text(identity.isConfigured ? identity.displayName : "Cooking stays private. Social setup is optional.") }
                    if identity.isConfigured { Text(identity.handle).foregroundStyle(.secondary) }
                    if identity.isConfigured {
                        NavigationLink("Social settings") { SocialSettingsView() }.accessibilityIdentifier("social-settings-open")
                    }
                    Button(identity.isConfigured ? "Edit social identity" : "Set up social identity") { editing = true }
                        .buttonStyle(SGButtonStyle()).accessibilityIdentifier("social-identity-edit")
                } else if error {
                    Text("Couldn’t load your social identity. Your cooking library is still available.")
                    Button("Retry identity") { Task { await load() } }
                } else { ProgressView("Loading identity") }
            }.sgCard().task { await load() }
                .sheet(isPresented: $editing, onDismiss: { Task { await load() } }) {
                    if let identity { SocialIdentityEditor(identity: identity) { self.identity = $0 } }
                }
        }
    }
    private func load() async {
        guard let request else { return }; error = false
        do { identity = try JSONDecoder().decode(SocialIdentity.self, from: await request("social_identity", "get", .init())); await SocialAvatarService.cleanup(request: request, media: media) }
        catch is CancellationError { }
        catch { self.error = true }
    }
}

struct SocialIdentityEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.socialRequest) private var request
    @Environment(\.socialMedia) private var media
    @State private var photo: Data?
    @State private var preparingPhoto = false
    @State private var removePhoto = false
    @State private var assetID = UUID()
    @State private var currentPath: String?
    @State private var profileSaved = false
    @State private var name: String
    @State private var username: String
    @State private var discoverable: Bool
    @State private var automaticallyShare: Bool
    @State private var saving = false
    @State private var error = false
    let onSave: (SocialIdentity) -> Void
    init(identity: SocialIdentity, onSave: @escaping (SocialIdentity) -> Void) {
        _currentPath = State(initialValue: identity.avatarPath)
        _name = State(initialValue: identity.displayName); _username = State(initialValue: identity.username ?? "")
        _automaticallyShare = State(initialValue: identity.sharingDefault)
        _discoverable = State(initialValue: identity.discoverable); self.onSave = onSave
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Profile photo") {
                    SocialAvatarPicker(name: name, path: currentPath, photo: $photo, removePhoto: $removePhoto, loading: $preparingPhoto)
                }.disabled(saving)
                Section("Social identity") {
                    TextField("Display name", text: $name).textContentType(.nickname).accessibilityIdentifier("social-display-name")
                    TextField("Username", text: $username).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("social-username")
                    Text("3–24 lowercase letters, numbers or single underscores. Display names can use nicknames.")
                        .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                }
                Section {
                    Toggle("Appear in Find Friends", isOn: $discoverable).accessibilityIdentifier("social-discoverable")
                    Text("Off by default. Turning this off does not remove existing friends or change your cooking library.")
                    Text("When you change your username, previous share links continue to identify your account. Published usernames cannot be taken by another account.")
                }
                Section("Share your cooking?") {
                    Toggle("Automatically Share New Dishes", isOn: $automaticallyShare).accessibilityIdentifier("social-sharing-default")
                    Text(SocialSharingCopy.explanation)
                }
                if error { Text(profileSaved ? "Your identity was saved. The profile photo change couldn’t finish. Retry Save, choose another photo, or remove the selection." : "Couldn’t save. Check your connection or try a different username.").foregroundStyle(.secondary).accessibilityIdentifier("social-identity-error") }
            }
            .disabled(saving)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Social identity").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") { Task { await save() } }
                        .disabled(saving || preparingPhoto || !SocialIdentityRules.valid(name: name, username: username))
                        .accessibilityIdentifier("social-identity-save")
                }
            }.interactiveDismissDisabled(saving)
                .onChange(of: photo) { _, _ in assetID = UUID() }
        }
    }
    private func save() async {
        guard let request else { return }; saving = true; error = false; profileSaved = false
        defer { saving = false }
        do {
            let result = try await request("social_identity", "save", .init(displayName: SocialIdentityRules.name(name), username: SocialIdentityRules.username(username), discoverable: discoverable, automaticallyShareNewDishes: automaticallyShare))
            let saved = try JSONDecoder().decode(SocialIdentity.self, from: result)
            profileSaved = true; currentPath = saved.avatarPath; onSave(saved)
            try await SocialAvatarService.save(photo: photo, remove: removePhoto, currentPath: currentPath, assetID: assetID, request: request, media: media)
            let latest = try JSONDecoder().decode(SocialIdentity.self, from: await request("social_identity", "get", .init()))
            onSave(latest); dismiss()
        } catch is CancellationError { } catch { self.error = true }
    }
}
