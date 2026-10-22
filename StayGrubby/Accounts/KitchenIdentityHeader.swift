import SwiftUI

struct KitchenIdentityHeader: View {
    @Environment(\.socialRequest) private var request
    @State private var identity: SocialIdentity?
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            SocialAvatar(name: identity?.displayName ?? "", path: identity?.avatarPath, size: 88)
            Text(identity?.displayName ?? "Your Kitchen").font(SGTheme.TypeRole.hero).tracking(-0.6)
                .fixedSize(horizontal: false, vertical: true)
            if let username = identity?.username { Text("@" + username).font(SGTheme.TypeRole.body).foregroundStyle(.secondary) }
            Text("Good food. Your signature.").font(SGTheme.TypeRole.body).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, SGTheme.Space.small).accessibilityIdentifier("profile-identity")
            .task { await load() }
            .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
    }
    private func load() async {
        guard let request else { return }
        do { let next = try JSONDecoder().decode(SocialIdentity.self, from: await request("social_identity", "get", .init())); try Task.checkCancellation(); identity = next }
        catch { identity = nil }
    }
}
