import SwiftUI
import SwiftData

struct CookedWithSelection: View {
    @Binding var selected: Set<UUID>
    @Environment(\.sgReduceMotion) private var reduceMotion
    @Environment(\.socialRequest) private var request
    @State private var people: [SocialPerson] = []
    @State private var loading = false
    @State private var failed = false
    @State private var cursor: String?
    @State private var revision = 0
    var body: some View {
        SGFormSection(title: "Tag a Sous Chef · optional") {
            Text("Invite up to eight friends after saving and ranking. They choose whether to add their own cook. This does not share a Grub List post.")
                .font(.footnote).foregroundStyle(.secondary)
            Text("Invitations include the dish title, Course, Cuisine and public cookbook/restaurant/online attribution. Notes, allergens, private annotations and photos stay private.").font(.footnote).foregroundStyle(.secondary)
            if loading { ProgressView("Loading friends") }
            ForEach(people) { person in
                Button {
                    if selected.contains(person.id) { selected.remove(person.id) }
                    else if selected.count < 8 { selected.insert(person.id) }
                } label: {
                    HStack {
                        SocialAvatar(name: person.displayName, path: person.avatarPath, size: 32)
                        VStack(alignment: .leading) { Text(person.displayName).font(.headline); Text(person.handle).font(.caption).foregroundStyle(.secondary) }.foregroundStyle(SGTheme.ColorToken.primaryText)
                        Spacer()
                        Image(systemName: selected.contains(person.id) ? "checkmark.circle.fill" : "circle")
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.borderless).accessibilityLabel("Cooked with \(person.displayName)")
                    .accessibilityValue(selected.contains(person.id) ? "Selected" : "Not selected")
                    .accessibilityIdentifier("cooked-with-\(person.id)")
            }
            Text("\(selected.count) of 8 selected").font(.caption).foregroundStyle(.secondary)
            if let cursor { Button("More friends") { Task { await load(after: cursor) } }.disabled(loading) }
            if failed { Text("Friends unavailable. Your selection is not sent until your cook is saved.").font(.footnote); Button("Retry friends") { revision += 1 } }
            else if !loading && people.isEmpty { Text("Current friends will appear here.").font(.footnote).foregroundStyle(.secondary) }
        }.animation(reduceMotion ? nil : SGTheme.Motion.quick, value: selected)
            .sensoryFeedback(.selection, trigger: selected)
            .task(id: revision) { await load() }
    }
    private func load(after: String? = nil) async {
        guard let request else { return }; loading = true; failed = false
        defer { loading = false }
        do {
            let page = try JSONDecoder().decode(SocialPeoplePage.self, from: await request("social_people", "friends", .init(afterUsername: after)))
            try Task.checkCancellation()
            if after == nil { people = [] }
            let ids = Set(people.map(\.id)); people += page.people.filter { !ids.contains($0.id) }; cursor = page.nextCursor
        } catch is CancellationError { } catch { failed = true; if after == nil { people = [] } }
    }
}

struct SharedCookingEntryView: View {
    var eventID: UUID? = nil
    var postID: UUID? = nil
    @Environment(\.socialRequest) private var request
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var phase
    @Environment(\.sharedCooking) private var sharedCooking
    @State private var event: SharedCookingEvent?
    @State private var post: SocialPost?
    @State private var claim: SocialCookingClaim?
    @State private var list: RankingList?
    @State private var existing: CookingAttempt?
    @State private var busy = false
    @State private var failed = false
    @State private var declined = false
    @State private var completed = false
    @State private var generation = UUID()
    var body: some View {
        SGEditorialList {
            if failed {
                ContentUnavailableView("Cooking activity unavailable", systemImage: "wifi.exclamationmark", description: Text("Your access may have changed or the connection was interrupted."))
                Button("Retry") { Task { await load() } }
            } else if declined { Text("Invitation declined. Nothing was added to your cooking history.") }
            else {
                if busy { ProgressView("Loading cooking activity") }
                if let event {
                    Text(event.metadata.title ?? "Cooked Together").font(.title2.bold())
                    Label(event.owner.displayName, systemImage: "person.2")
                    ForEach(event.participants) { participant in
                        HStack {
                            SocialAvatar(name: participant.person.displayName, path: participant.person.avatarPath, size: 32)
                            Text(participant.person.displayName); Spacer(); Text(stateLabel(participant.state)).foregroundStyle(.secondary)
                        }
                        if event.isOwner && ["pending", "joining"].contains(participant.state) {
                            Button("Remove invitation for \(participant.person.displayName)", role: .destructive) { Task { await remove(participant.person.id) } }
                        }
                    }
                }
                if let post {
                    Text(post.title).font(.title2.bold()); Text("Run It Back from \(post.author.displayName)’s cooking")
                    if let recipeID = post.recipeID { NavigationLink("View recipe") { RecipeDetailView(id: recipeID) } }
                }
                if let existing {
                    NavigationLink("View my saved cook") { AttemptDetailView(attempt: existing) }
                } else if completed { Text("Already added to your cooking. Let your account finish restoring to see it here.") }
                else if event?.isOwner != true && (event != nil || post != nil) {
                    Text("Review the details and rank this cook in your own library. Scores, comparisons, private notes and photos are never copied.")
                    if event != nil { Text("Joining confirms you cooked together. Participation may appear to mutual friends when either cook is shared.").font(.footnote).foregroundStyle(.secondary) }
                    Button(event != nil ? "Add to My Cooking" : "Run It Back") { Task { await begin() } }
                        .accessibilityIdentifier("shared-begin").disabled(busy)
                    if event != nil { Button("Decline invitation", role: .destructive) { Task { await decline() } }.accessibilityIdentifier("shared-decline").disabled(busy) }
                }
            }
        }.navigationTitle(eventID == nil ? "Run It Back" : "Cooked Together").navigationBarTitleDisplayMode(.inline)
            .task { await load() }.refreshable { await load() }
            .onChange(of: phase) { _, next in generation = UUID(); event = nil; post = nil; if next == .active { Task { await load() } } }
            .onDisappear { generation = UUID() }
            .sheet(item: $claim, onDismiss: { Task { await load() } }) { claim in
                if let list { AddCookingView(list: list, origin: claim) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
    }
    private func stateLabel(_ state: String) -> String {
        switch state { case "pending": "Invited"; case "joining": "Reviewing"; case "joined": "Joined"; case "declined": "Declined"; default: "Removed" }
    }
    private func load() async {
        guard !declined else { return }
        guard let request else { return }; let token = UUID(); generation = token; busy = true; failed = false; event = nil; post = nil
        defer { if generation == token { busy = false } }
        do {
            list = try CookingStore.globalRanking(context: context)
            if let eventID {
                let next = try JSONDecoder().decode(SharedCookingEvent.self, from: await request("social_cooking", "event", .init(eventID: eventID)))
                guard !Task.isCancelled, generation == token else { return }; event = next
            } else if let postID {
                let next = try JSONDecoder().decode(SocialPostsPage.self, from: await request("social_feed", "post", .init(postID: postID))).posts.first
                guard !Task.isCancelled, generation == token else { return }; post = next
            }
        } catch is CancellationError { } catch { if generation == token { event = nil; post = nil; failed = true } }
    }
    private func begin() async {
        guard let request else { return }; busy = true
        defer { busy = false }
        do {
            let next = try JSONDecoder().decode(SocialCookingClaim.self, from: await request("social_cooking", eventID == nil ? "recreate" : "claim", .init(postID: postID, eventID: eventID)))
            try Task.checkCancellation()
            existing = try context.fetch(FetchDescriptor<CookingAttempt>()).first { $0.rankedItemID == next.itemID }
            if existing != nil || next.completed {
                completed = true
                if existing != nil && !next.completed {
                    try sharedCooking?.record(itemID: next.itemID, participants: [], originID: next.id, recipeOriginID: next.recipeOriginID)
                    sharedCooking?.retry()
                }
            }
            else { claim = next }
        } catch is CancellationError { } catch { failed = true }
    }
    private func decline() async {
        guard let request, let eventID else { return }
        do { _ = try await request("social_cooking", "decline", .init(eventID: eventID)); try Task.checkCancellation(); declined = true; NotificationCenter.default.post(name: .socialContentChanged, object: nil) }
        catch is CancellationError { } catch { failed = true }
    }
    private func remove(_ peer: UUID) async {
        guard let request, let eventID else { return }
        do { _ = try await request("social_cooking", "remove", .init(peerID: peer, eventID: eventID)); await load() }
        catch is CancellationError { } catch { failed = true }
    }
}

struct CookingProvenanceView: View {
    let itemID: UUID
    @Environment(\.socialRequest) private var request
    @Environment(\.scenePhase) private var phase
    @State private var page: CookingProvenancePage?
    @State private var failed = false
    @State private var generation = UUID()
    var body: some View {
        if request != nil {
            VStack(alignment: .leading, spacing: 8) {
                if let page {
                    ForEach(page.origins) { origin in
                        Text(origin.kind == "recreated" ? origin.creator.map { "Ran It Back from \($0.displayName)" } ?? "Run It Back · original activity unavailable" : origin.creator.map { "Cooked with \($0.displayName)" } ?? "Cooked Together · original activity unavailable")
                            .font(.subheadline)
                    }
                    ForEach(page.events) { event in NavigationLink("Cooked Together · participants") { SharedCookingEntryView(eventID: event.id) } }
                }
                if failed { Button("Retry cooking provenance") { Task { await load() } }.font(.footnote) }
                RecipeCookingProvenance(itemID: itemID)
                SharedCookingPending(itemID: itemID)
            }.task(id: itemID) { await load() }
                .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
                .onChange(of: phase) { _, next in generation = UUID(); page = nil; if next == .active { Task { await load() } } }
                .onDisappear { generation = UUID() }
        }
    }
    private func load() async {
        guard let request else { return }; let token = UUID(); generation = token; page = nil; failed = false
        do { let next = try JSONDecoder().decode(CookingProvenancePage.self, from: await request("social_cooking", "own", .init(targetID: itemID))); guard !Task.isCancelled, generation == token else { return }; page = next }
        catch is CancellationError { } catch { if generation == token { failed = true } }
    }
}
