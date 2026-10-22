import SwiftUI

struct SocialIdentitySection: View {
    @Environment(\.socialRequest) private var request
    @Environment(\.socialMedia) private var media
    @State private var identity: SocialIdentity?
    @State private var error = false
    var body: some View {
        Group {
            if let identity {
                SocialIdentityEditor(identity: identity, modal: false) { self.identity = $0 }
            } else {
                Form {
                    if error { Text("Couldn’t load your profile. Your cooking library is still available."); Button("Retry profile") { Task { await load() } } }
                    else { ProgressView("Loading profile") }
                }.navigationTitle("Profile").task { await load() }
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
    @State private var saving = false
    @State private var error = false
    let onSave: (SocialIdentity) -> Void
    let modal: Bool
    init(identity: SocialIdentity, modal: Bool = true, onSave: @escaping (SocialIdentity) -> Void) {
        _currentPath = State(initialValue: identity.avatarPath)
        _name = State(initialValue: identity.displayName); _username = State(initialValue: identity.username ?? "")
        self.modal = modal
        _discoverable = State(initialValue: identity.discoverable); self.onSave = onSave
    }
    var body: some View {
        if modal { NavigationStack { editor } } else { editor }
    }
    private var editor: some View {
            Form {
                Section("Profile photo") {
                    SocialAvatarPicker(name: name, path: currentPath, photo: $photo, removePhoto: $removePhoto, loading: $preparingPhoto)
                }.disabled(saving)
                Section("Profile") {
                    TextField("Display name", text: $name).textContentType(.nickname).accessibilityIdentifier("social-display-name")
                    TextField("Username", text: $username).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("social-username")
                    Text("3–24 lowercase letters, numbers or single underscores. Display names can use nicknames.")
                        .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                }
                Section("Discoverability") {
                    Toggle("Appear in Find Sous Chefs", isOn: $discoverable).accessibilityIdentifier("social-discoverable")
                    Text("Off by default. Turning this off does not remove existing friends or change your cooking library.")
                    Text("When you change your username, previous share links continue to identify your account. Published usernames cannot be taken by another account.")
                }
                if error { Text(profileSaved ? "Your identity was saved. The profile photo change couldn’t finish. Retry Save, choose another photo, or remove the selection." : "Couldn’t save. Check your connection or try a different username.").foregroundStyle(.secondary).accessibilityIdentifier("social-identity-error") }
            }
            .disabled(saving)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Profile").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { if modal { Button("Cancel") { dismiss() }.disabled(saving) } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") { Task { await save() } }
                        .disabled(saving || preparingPhoto || !SocialIdentityRules.valid(name: name, username: username))
                        .accessibilityIdentifier("social-identity-save")
                }
            }.interactiveDismissDisabled(saving)
                .onChange(of: photo) { _, _ in assetID = UUID() }
    }
    private func save() async {
        guard let request else { return }; saving = true; error = false; profileSaved = false
        defer { saving = false }
        do {
            let result = try await request("social_identity", "save", .init(displayName: SocialIdentityRules.name(name), username: SocialIdentityRules.username(username), discoverable: discoverable))
            let saved = try JSONDecoder().decode(SocialIdentity.self, from: result)
            profileSaved = true; currentPath = saved.avatarPath; onSave(saved)
            try await SocialAvatarService.save(photo: photo, remove: removePhoto, currentPath: currentPath, assetID: assetID, request: request, media: media)
            let latest = try JSONDecoder().decode(SocialIdentity.self, from: await request("social_identity", "get", .init()))
            onSave(latest); dismiss()
        } catch is CancellationError { } catch { self.error = true }
    }
}
