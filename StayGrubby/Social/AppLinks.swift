import SwiftUI

nonisolated enum AppRoute: Equatable, Identifiable, Sendable {
    case profile(String)
    case invalid
    var id: String { switch self { case .profile(let username): "profile:" + username; case .invalid: "invalid" } }
    init(url: URL) {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false), parts.scheme == "https", parts.host == "staygrubby.com",
              parts.user == nil, parts.password == nil, parts.port == nil, parts.query == nil, parts.fragment == nil,
              parts.percentEncodedPath == parts.path, parts.path.hasPrefix("/@") else { self = .invalid; return }
        let name = String(parts.path.dropFirst(2))
        guard SocialIdentityRules.valid(name: "Cook", username: name), name == SocialIdentityRules.username(name) else { self = .invalid; return }
        self = .profile(name)
    }
    static func profileURL(username: String) -> URL? {
        guard SocialIdentityRules.valid(name: "Cook", username: username), username == SocialIdentityRules.username(username) else { return nil }
        return URL(string: "https://staygrubby.com/@" + username)
    }
}
@MainActor @Observable final class AppLinkRouter {
    var pending: AppRoute?
    func receive(_ url: URL) { pending = AppRoute(url: url) }
}
struct AppLinkPresentation: ViewModifier {
    @Environment(AppLinkRouter.self) private var router
    func body(content: Content) -> some View {
        @Bindable var router = router
        content.sheet(item: $router.pending) { route in
            NavigationStack { ProfileLinkDestination(route: route).toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { router.pending = nil } }
            } }
        }
    }
}
struct ProfileLinkDestination: View {
    let route: AppRoute
    @Environment(\.socialRequest) private var request
    @Environment(\.scenePhase) private var phase
    @State private var isOwn = false
    @State private var person: SocialPerson?
    @State private var failed = false
    @State private var generation = UUID()
    var body: some View {
        Group {
            if let person {
                if isOwn {
                    List { Text(person.displayName).font(.title.bold()); Text(person.handle); Text("Your Kitchen"); ShareMyKitchen() }
                } else { FriendProfileView(person: person) {} }
            }
            else if failed { ContentUnavailableView("Kitchen unavailable", systemImage: "person.crop.circle.badge.xmark", description: Text("This link is invalid, private, blocked, removed or currently unavailable.")).accessibilityIdentifier("profile-link-unavailable") }
            else { ProgressView("Opening Kitchen") }
        }.navigationTitle("My Kitchen").task(id: route.id) { await resolve() }
            .onChange(of: phase) { _, next in generation = UUID(); person = nil; if next == .active { Task { await resolve() } } }
            .onDisappear { generation = UUID() }
    }
    private func resolve() async {
        guard case .profile(let username) = route, let request else { failed = true; return }
        let token = UUID(); generation = token; failed = false; person = nil
        do {
            let page = try JSONDecoder().decode(SocialPeoplePage.self, from: await request("profile_link", "resolve", .init(username: username)))
            guard !Task.isCancelled, token == generation else { return }
            person = page.people.first; isOwn = page.isOwn == true; failed = person == nil
        } catch is CancellationError {} catch { if token == generation { failed = true; person = nil } }
    }
}
struct ShareMyKitchen: View {
    @Environment(\.socialRequest) private var request
    @State private var identity: SocialIdentity?
    @State private var failed = false
    var body: some View {
        if request != nil {
            VStack(alignment: .leading, spacing: 8) {
                if let identity, identity.discoverable, let username = identity.username, let url = AppRoute.profileURL(username: username) {
                    ShareLink(item: url) { Label("Share My Kitchen", systemImage: "square.and.arrow.up") }
                        .buttonStyle(SGButtonStyle()).accessibilityIdentifier("share-my-kitchen")
                } else if identity != nil { Text("To share your Kitchen, enable discovery in Settings → Profile.").font(.footnote).foregroundStyle(.secondary) }
                if failed { Button("Retry Kitchen sharing") { Task { await load() } } }
            }.task { await load() }
                .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
        }
    }
    private func load() async {
        guard let request else { return }
        do { let next = try JSONDecoder().decode(SocialIdentity.self, from: await request("social_identity", "get", .init())); try Task.checkCancellation(); identity = next; failed = false }
        catch is CancellationError {} catch { identity = nil; failed = true }
    }
}
