import SwiftUI

enum FriendsSection: String, CaseIterable, Identifiable {
    case friends, incoming, outgoing, search, blocked
    var id: String { rawValue }
    var title: String {
        switch self { case .friends: "Sous Chefs"; case .incoming: "Requests"; case .outgoing: "Sent Requests"; case .search: "Find Sous Chefs"; case .blocked: "Blocked Accounts" }
    }
}

struct FriendsView: View {
    @Environment(\.socialRequest) private var request
    let administrative: FriendsSection?
    @State private var section: FriendsSection
    init(section: FriendsSection = .friends) {
        administrative = [.outgoing, .blocked].contains(section) ? section : nil
        _section = State(initialValue: section)
    }
    @State private var query = ""
    @State private var identity: SocialIdentity?
    @State private var page = SocialPeoplePage(people: [])
    @State private var loading = false
    @State private var error: String?
    @State private var editingIdentity = false
    @State private var selectedPerson: SocialPerson?
    @State private var revision = 0
    @State private var requestGeneration = UUID()
    private var taskKey: String { section.rawValue + ":" + query + ":\(revision)" }
    var body: some View {
        SGEditorialList {
            if administrative == nil {
                SGPageIntro(title: "Sous Chefs", subtitle: "Good food is better with good company.", showsTitle: false).listRowSeparator(.hidden)
                ShareMyKitchen()
            }
            if let identity, !identity.isConfigured {
                Section {
                    Text("Your cooking stays private. Set up your profile when you’re ready to connect.")
                    Button("Set up Profile") { editingIdentity = true }.accessibilityIdentifier("friends-setup")
                }
            } else {
                if administrative == nil {
                    Picker("Show", selection: $section) {
                        ForEach([FriendsSection.friends, .search, .incoming]) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented).accessibilityIdentifier("friends-section")
                }
                if section == .incoming && !loading {
                    Text(page.people.count == 1 ? "1 request shown" : "\(page.people.count) requests shown").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                }
                if section == .search {
                    SGSearchField(placeholder: "Search @username", text: $query, identifier: "friends-search").textInputAutocapitalization(.never).autocorrectionDisabled()
                    Text("Search by username. Only people who allow discovery appear here.").font(.footnote).foregroundStyle(.secondary)
                }
                if loading && page.people.isEmpty { ProgressView("Loading people") }
                if let error {
                    Text(error).foregroundStyle(.secondary).accessibilityIdentifier("friends-error")
                    Button("Retry") { revision += 1 }
                }
                if !loading && error == nil && page.people.isEmpty {
                    ContentUnavailableView(section == .search ? "Find your cooking friends" : "No \(section.title.lowercased()) yet", systemImage: "person.2",
                        description: Text(section == .search ? "Enter at least two username characters." : "Friendships are mutual. Your private cooking library stays yours."))
                    if section == .friends { Button("Find Sous Chefs") { section = .search }.accessibilityIdentifier("friends-find") }
                }
                ForEach(page.people) { person in
                    Button { selectedPerson = person } label: {
                        HStack(alignment: .top, spacing: 12) {
                        SocialAvatar(name: person.displayName, path: person.avatarPath, size: 54)
                        VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                            Text(person.displayName).font(SGTheme.TypeRole.dish)
                            Text(person.handle).foregroundStyle(.secondary)
                            Text(person.relationship.label).font(SGTheme.TypeRole.secondary)
                        } }.padding(.vertical, SGTheme.Space.xSmall).fixedSize(horizontal: false, vertical: true)
                    }.accessibilityIdentifier("friend-person-\(person.username)")
                }
                if page.nextCursor != nil { Button("Load more people") { Task { await load(more: true) } }.disabled(loading) }
            }
        }
        .navigationTitle(administrative?.title ?? "Sous Chefs").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
        .scrollDismissesKeyboard(.interactively).refreshable { await load() }
        .task(id: taskKey) {
            page = .init(people: []); error = nil
            if section == .search { do { try await Task.sleep(for: .milliseconds(300)) } catch { return } }
            await load()
        }
        .sheet(item: $selectedPerson, onDismiss: { revision += 1 }) { person in
            NavigationStack {
                FriendProfileView(person: person) { revision += 1 }
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { selectedPerson = nil } } }
            }
        }
        .sheet(isPresented: $editingIdentity) {
            if let identity { SocialIdentityEditor(identity: identity) { self.identity = $0; revision += 1 } }
        }
    }
    private func load(more: Bool = false) async {
        guard let request else { error = "Connect your account to use Friends."; return }
        let token = UUID(); requestGeneration = token; loading = true; error = nil
        defer { if requestGeneration == token { loading = false } }
        do {
            let own = try JSONDecoder().decode(SocialIdentity.self, from: await request("social_identity", "get", .init()))
            guard !Task.isCancelled, requestGeneration == token else { return }; identity = own
            guard own.isConfigured else { page = .init(people: []); return }
            let response = try await request("social_people", section.rawValue, .init(query: query, afterUsername: more ? page.nextCursor : nil))
            let next = try JSONDecoder().decode(SocialPeoplePage.self, from: response)
            guard !Task.isCancelled, requestGeneration == token else { return }
            if more {
                let ids = Set(page.people.map(\.id)); page.people += next.people.filter { !ids.contains($0.id) }; page.nextCursor = next.nextCursor
            } else { page = next }
        } catch is CancellationError { } catch {
            guard requestGeneration == token else { return }
            page = .init(people: []); self.error = "Couldn’t load Friends. Check your connection and retry."
        }
    }
}

struct FriendProfileView: View {
    @Environment(\.socialRequest) private var request
    @Environment(\.dismiss) private var dismiss
    @State var person: SocialPerson
    var onChange: () -> Void
    @State private var busy = false
    @State private var error = false
    @State private var unavailable = false
    @State private var confirmation: String?
    @State private var socialRoute: SocialPostRoute?
    var body: some View {
        SGEditorialList {
            if unavailable { ContentUnavailableView("Person unavailable", systemImage: "person.crop.circle.badge.xmark", description: Text("Their privacy or relationship may have changed.")) }
            else {
                Section {
                    SocialAvatar(name: person.displayName, path: person.avatarPath, size: 88)
                    Text(person.displayName).font(SGTheme.TypeRole.title).fixedSize(horizontal: false, vertical: true)
                    Text(person.handle).foregroundStyle(.secondary)
                    Text(person.relationship.label)
                }
                Section {
                    switch person.relationship {
                    case .none: action("Add Sous Chef", "request")
                    case .incoming: action("Accept Request", "accept"); action("Decline Request", "decline")
                    case .outgoing: action("Cancel Request", "cancel")
                    case .friends: Button("Remove Sous Chef", role: .destructive) { confirmation = "remove" }
                    case .blocked: action("Unblock", "unblock")
                    }
                    if person.relationship != .blocked { Button("Block", role: .destructive) { confirmation = "block" } }
                }.disabled(busy)
                if person.relationship != .blocked {
                    Section { SocialProfilePosts(open: { socialRoute = .post($0) }, personID: person.id).id(person.id) }
                    Section { SocialReportButton(kind: "profile", targetID: person.id) }
                }
            }
            if error { Text("This action couldn’t complete. Refresh to check the latest relationship.").accessibilityIdentifier("friend-action-error"); Button("Refresh profile") { Task { await refresh() } } }
        }
        .navigationTitle("Kitchen").navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $socialRoute) { SocialPostDestination(route: $0) }
        .refreshable { await refresh() }.task { if person.relationship != .blocked { await refresh() } }
        .confirmationDialog(confirmation == "block" ? "Block this person?" : "Remove this friend?", isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }), titleVisibility: .visible) {
            Button(confirmation == "block" ? "Block Person" : "Remove Friendship", role: .destructive) {
                let action = confirmation ?? "remove"; confirmation = nil; Task { await mutate(action) }
            }
        } message: { Text("This changes your social relationship only. Private cooking and rankings are unchanged.") }
    }
    private func action(_ title: String, _ action: String) -> some View {
        Button(title) { Task { await mutate(action) } }.accessibilityIdentifier("friend-action-\(action)")
    }
    private func refresh() async {
        guard let request else { return }
        do {
            let page = try JSONDecoder().decode(SocialPeoplePage.self, from: await request("social_people", "profile", .init(peerID: person.id)))
            guard !Task.isCancelled, let latest = page.people.first else { return }; person = latest; error = false; unavailable = false
        } catch is CancellationError { } catch { unavailable = true; self.error = true; onChange() }
    }
    private func mutate(_ action: String) async {
        guard let request else { return }; busy = true; error = false
        defer { busy = false }
        do {
            _ = try await request("social_people", action, .init(peerID: person.id))
            NotificationCenter.default.post(name: .socialContentChanged, object: nil)
            onChange()
            if ["block", "unblock", "remove", "decline", "cancel"].contains(action) { dismiss() }
            else { await refresh() }
        } catch is CancellationError { } catch { self.error = true; await refresh() }
    }
}

struct SocialFriendsLink: View {
    @Environment(\.socialRequest) private var request
    var body: some View {
        if request != nil {
            NavigationLink { FriendsView() } label: {
                Label("Sous Chefs", systemImage: "person.2")
                    .frame(maxWidth: .infinity, minHeight: SGTheme.Size.minimumTap, alignment: .leading)
                    .contentShape(Rectangle())
            }.buttonStyle(SGButtonStyle()).accessibilityIdentifier("friends-open")
        }
    }
}
