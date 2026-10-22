import SwiftUI
import SwiftData

@MainActor @Observable final class SharedCookingCoordinator {
    private(set) var intents: [CookingSocialIntent] = []
    private(set) var failed = false
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var root: URL?
    @ObservationIgnored private var owner: UUID?
    @ObservationIgnored private var request: SocialRequest?
    @ObservationIgnored private var sync: CookingSyncCoordinator?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var writable = true
    @ObservationIgnored private var again = false
    func connect(context: ModelContext, root: URL, owner: UUID, request: @escaping SocialRequest, sync: CookingSyncCoordinator?) {
        disconnect(); self.context = context; self.root = root; self.owner = owner; self.request = request; self.sync = sync
        do { intents = try CookingSocialJournal.load(root: root, accountID: owner).intents }
        catch { failed = true; writable = false }
        retry()
    }
    func disconnect() {
        generation = UUID(); task?.cancel(); task = nil; again = false
        context = nil; root = nil; owner = nil; request = nil; sync = nil; intents = []; failed = false; writable = true
    }
    func record(itemID: UUID, participants: [UUID], originID: UUID?, recipeOriginID: UUID? = nil) throws {
        guard !participants.isEmpty || originID != nil || recipeOriginID != nil else { return }
        guard participants.count <= 8, Set(participants).count == participants.count else { throw AccountFoundationError.invalidResolution }
        if let index = intents.firstIndex(where: { $0.id == itemID }) {
            if ((try? context?.fetch(FetchDescriptor<CookingAttempt>())) ?? []).contains(where: { $0.rankedItemID == itemID }) { return }
            intents[index] = .init(id: itemID, eventID: intents[index].eventID, participants: participants, originID: originID, recipeOriginID: recipeOriginID)
        } else { intents.append(.init(id: itemID, eventID: itemID, participants: participants, originID: originID, recipeOriginID: recipeOriginID)) }
        try persist()
    }
    var pendingSavedCooks: [CookingAttempt] {
        let ids = Set(intents.map(\.id))
        return ((try? context?.fetch(FetchDescriptor<CookingAttempt>())) ?? []).filter { ids.contains($0.rankedItemID) }
    }
    func retry() {
        guard task == nil else { again = true; return }
        let token = generation
        task = Task { [weak self] in
            guard let self else { return }
            defer { if self.generation == token { self.task = nil; if self.again { self.again = false; self.retry() } } }
            await self.process(token)
        }
    }
    func retryNow() async { retry(); await task?.value }
    func cancelInvitations(_ itemID: UUID) async {
        guard let index = intents.firstIndex(where: { $0.id == itemID }), !intents[index].participants.isEmpty else { return }
        let previous = intents[index]
        intents[index].cancelRequested = true
        do {
            try persist(); failed = false; retry()
        } catch { intents[index] = previous; failed = true }
    }
    private func process(_ token: UUID) async {
        guard let context, let request, SocialPostPublisher.ready(context: context, sync: sync) else { return }
        do { try persist(); failed = false } catch { failed = true; return }
        for snapshot in intents {
            guard token == generation, !Task.isCancelled else { return }
            guard let intent = intents.first(where: { $0.id == snapshot.id }) else { continue }
            guard let cook = ((try? context.fetch(FetchDescriptor<CookingAttempt>())) ?? []).first(where: { $0.rankedItemID == intent.id }), cook.dish != nil, cook.rankedItem != nil else { continue }
            do {
                if intent.cancelRequested == true {
                    _ = try await request("social_cooking", "cancel", .init(eventID: intent.eventID))
                    guard token == generation, !Task.isCancelled else { return }
                }
                if let recipe = intent.recipeOriginID {
                    _ = try await request("recipes", "complete", .init(originID: recipe))
                    guard token == generation, !Task.isCancelled else { return }
                }
                if let origin = intent.originID { _ = try await request("social_cooking", "complete", .init(originID: origin)) }
                guard token == generation, !Task.isCancelled else { return }
                if intent.cancelRequested != true && intents.first(where: { $0.id == intent.id })?.cancelRequested == true { continue }
                if !intent.participants.isEmpty && intent.cancelRequested != true {
                    var payload = SocialPayload(attemptID: cook.id, confirmed: true)
                    payload.eventID = intent.eventID; payload.participantIDs = intent.participants
                    _ = try await request("social_cooking", "create", payload)
                }
                guard token == generation, !Task.isCancelled else { return }
                if intent.cancelRequested != true && intents.first(where: { $0.id == intent.id })?.cancelRequested == true { continue }
                intents.removeAll { $0.id == intent.id }; try persist()
                NotificationCenter.default.post(name: .socialContentChanged, object: nil)
            } catch is CancellationError { return }
            catch { if token == generation { failed = true } }
        }
    }
    private func persist() throws {
        guard writable, let root, let owner else { throw SyncFoundationError.wrongAccount }
        try CookingSocialJournal(version: 1, accountID: owner, intents: intents).save(root: root)
    }
}
private struct SharedCookingKey: EnvironmentKey { static let defaultValue: SharedCookingCoordinator? = nil }
extension EnvironmentValues {
    var sharedCooking: SharedCookingCoordinator? { get { self[SharedCookingKey.self] } set { self[SharedCookingKey.self] = newValue } }
}

struct SharedCookingPending: View {
    var itemID: UUID? = nil
    @Environment(\.sharedCooking) private var coordinator
    var body: some View {
        if let coordinator, coordinator.pendingSavedCooks.contains(where: { itemID == nil || $0.rankedItemID == itemID }) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your cook and ranking are saved. Cooking attribution or invitations are pending.").font(.footnote)
                Button("Retry cooking details") { coordinator.retry() }.accessibilityIdentifier("shared-cooking-retry")
                ForEach(coordinator.intents.filter { intent in !intent.participants.isEmpty && (itemID == nil || intent.id == itemID) && coordinator.pendingSavedCooks.contains(where: { $0.rankedItemID == intent.id }) }) { intent in
                    Button("Cancel pending invitations", role: .destructive) { Task { await coordinator.cancelInvitations(intent.id) } }
                }
            }.padding()
        }
    }
}
