import SwiftUI

struct KitchenIdentityHeader: View {
    @Environment(\.socialRequest) private var request
    @State private var identity: SocialIdentity?
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: SGTheme.Space.medium)) : AnyLayout(HStackLayout(alignment: .center, spacing: SGTheme.Space.medium))
        layout {
            SocialAvatar(name: identity?.displayName ?? "", path: identity?.avatarPath, size: 64)
            VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                Text(identity?.displayName ?? "Your Kitchen").font(SGTheme.TypeRole.title).tracking(-0.6)
                if let username = identity?.username { Text("@" + username).font(SGTheme.TypeRole.body).foregroundStyle(.secondary) }
                Text("Good food. Your signature.").font(SGTheme.TypeRole.body).foregroundStyle(.secondary)
            }
        }.padding(.vertical, SGTheme.Space.small).accessibilityIdentifier("profile-identity")
            .task { await load() }
            .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
    }
    private func load() async {
        guard let request else { return }
        do { let next = try JSONDecoder().decode(SocialIdentity.self, from: await request("social_identity", "get", .init())); try Task.checkCancellation(); identity = next }
        catch { identity = nil }
    }
}
