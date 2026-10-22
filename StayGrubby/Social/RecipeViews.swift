import SwiftUI
import SwiftData

struct RecipeLibraryView: View {
    @Environment(\.socialRequest) private var request
    @State private var recipes: [Recipe] = []
    @State private var tickets: [RecipeTicket] = []
    @State private var showingTickets = true
    @State private var creating = false
    @State private var failed = false
    @State private var loading = false
    @State private var revision = 0
    @State private var generation = UUID()
    @Environment(\.scenePhase) private var phase
    var body: some View {
        SGEditorialList {
            SGPageIntro(title: showingTickets ? "Tickets" : "Recipes", subtitle: showingTickets ? "Good things on your cooking list." : "Things you can make. Not things you’ve ranked.", eyebrow: "The next great cook")
            Picker("Library", selection: $showingTickets) {
                Text("Tickets 🎟️").tag(true); Text("My Recipes").tag(false)
            }.pickerStyle(.segmented).accessibilityIdentifier("recipe-library-mode")
            Text("Save something to make. Only a completed cook enters your Grub Rank.").font(.footnote).foregroundStyle(.secondary)
            if loading { ProgressView("Loading recipes") }
            if failed { Text("Recipes unavailable. Check your connection."); Button("Retry") { revision += 1 } }
            if showingTickets {
                ForEach(tickets) { ticket in
                    if let recipe = ticket.recipe {
                        NavigationLink { RecipeDetailView(id: recipe.id) } label: { RecipeSummaryRow(recipe: recipe, ticket: true) }.accessibilityLabel(recipe.content.title).accessibilityHint("Ticket, saved recipe. Opens recipe details.")
                    } else { Text("Recipe unavailable").foregroundStyle(.secondary) }
                    Button("Remove Ticket", role: .destructive) { Task { await remove(ticket.id) } }.font(.footnote)
                }
                if tickets.isEmpty && !loading && !failed { Text("No Tickets yet. Save a recipe you want to cook.") }
            } else {
                ForEach(recipes) { recipe in NavigationLink { RecipeDetailView(id: recipe.id) } label: { RecipeSummaryRow(recipe: recipe, ticket: false) }.accessibilityLabel(recipe.content.title) }
                if recipes.isEmpty && !loading && !failed { Text("Create your first recipe. Your private cooking history stays separate.") }
            }
            Button("Create Recipe") { creating = true }.accessibilityIdentifier("recipe-create")
        }.navigationTitle("Recipes & Tickets").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
            .task(id: revision) { await load() }.refreshable { await load() }
            .sheet(isPresented: $creating, onDismiss: { revision += 1 }) { RecipeEditor { _ in revision += 1 } }
            .onChange(of: showingTickets) { _, _ in revision += 1 }
            .onChange(of: phase) { _, next in generation = UUID(); recipes = []; tickets = []; if next == .active { revision += 1 } }
            .onDisappear { generation = UUID() }
    }
    private func load() async {
        guard let request else { failed = true; return }; let token = UUID(); generation = token; loading = true; failed = false
        defer { if generation == token { loading = false } }
        do {
            let own = try JSONDecoder().decode(RecipesPage.self, from: await request("recipes", "list", .init()))
            let saved = try JSONDecoder().decode(TicketsPage.self, from: await request("recipes", "tickets", .init()))
            guard !Task.isCancelled, token == generation else { return }; recipes = own.recipes; tickets = saved.tickets
        } catch is CancellationError {} catch { if token == generation { recipes = []; tickets = []; failed = true } }
    }
    private func remove(_ id: UUID) async {
        guard let request else { return }
        do { _ = try await request("recipes", "unticket", .init(recipeID: id)); await load() } catch { failed = true }
    }
}

struct RecipeDetailView: View {
    let id: UUID
    @Environment(\.socialRequest) private var request
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var recipe: Recipe?
    @State private var claim: SocialCookingClaim?
    @State private var list: RankingList?
    @State private var editing = false
    @State private var deleting = false
    @State private var failed = false
    @State private var busy = false
    @State private var reservation = UUID()
    @State private var generation = UUID()
    var body: some View {
        SGEditorialList {
            if let recipe {
                Section {
                    SGEyebrow(text: "Recipe · something to make")
                    Text(recipe.content.title).font(SGTheme.TypeRole.hero).accessibilityIdentifier("recipe-title")
                    if let creator = recipe.creator { Text("Added by \(creator.displayName)").foregroundStyle(.secondary) }
                    if let description = recipe.content.description, !description.isEmpty { Text(description) }
                    if let source = recipe.content.source, !source.isEmpty { Text("Source · \(source)") }
                    if let url = recipe.content.externalURL.flatMap(URL.init(string:)) { Link("Original source", destination: url) }
                    if let course = recipe.content.course { Text("Course · \(DishCategory(rawValue: course)?.label ?? course)") }
                    if let cuisine = recipe.content.cuisine { Text("Cuisine · \(cuisine)") }
                }
                .listRowSeparator(.hidden)
                Section("Ingredients") { ForEach(Array(recipe.content.ingredients.enumerated()), id: \.offset) { _, text in Text(text).font(SGTheme.TypeRole.reading).lineSpacing(6) } }
                .listRowSeparator(.hidden)
                Section("Instructions") { ForEach(Array(recipe.content.steps.enumerated()), id: \.offset) { index, text in Text("\(index + 1). \(text)").font(SGTheme.TypeRole.reading).lineSpacing(8).padding(.vertical, SGTheme.Space.small) } }
                Section {
                    Button(recipe.saved ? "Remove Ticket" : "Save Ticket 🎟️") { Task { await ticket() } }.accessibilityIdentifier("recipe-ticket")
                    Button { Task { await begin() } } label: { Text("Make This").frame(maxWidth: .infinity) }.buttonStyle(SGButtonStyle(prominent: true)).accessibilityIdentifier("recipe-make")
                    Text("Review and edit your cook before ranking. Saving a Ticket or opening this form never adds cooking history.").font(.footnote)
                }.disabled(busy)
                if recipe.isOwner {
                    Section {
                        Text(recipe.visibility == "friends" ? "Shared with current Sous Chefs" : "Private recipe")
                        Button("Edit Recipe") { editing = true }.accessibilityIdentifier("recipe-edit")
                        Button("Delete Recipe", role: .destructive) { deleting = true }
                    }.disabled(busy)
                }
            } else if !failed { ProgressView("Loading recipe") }
            if failed { Text("Recipe unavailable, changed, or offline. Your cooking history is unchanged.").accessibilityIdentifier("recipe-error"); Button("Retry") { Task { await load() } } }
        }.navigationTitle("Recipe").navigationBarTitleDisplayMode(.inline)
            .task(id: id) { await load() }.refreshable { await load() }
            .onChange(of: phase) { _, next in generation = UUID(); recipe = nil; if next == .active { Task { await load() } } }
            .onDisappear { generation = UUID() }
            .sheet(isPresented: $editing, onDismiss: { Task { await load() } }) { if let recipe { RecipeEditor(recipe: recipe) { self.recipe = $0 } } }
            .sheet(item: $claim, onDismiss: { reservation = UUID() }) { claim in if let list { AddCookingView(list: list, origin: claim) } }
            .confirmationDialog("Delete this recipe?", isPresented: $deleting, titleVisibility: .visible) {
                Button("Delete Recipe", role: .destructive) { Task { await delete() } }
            } message: { Text("Tickets are removed. Existing private cooks retain their historical recipe snapshot.") }
    }
    private func load() async {
        guard let request else { failed = true; return }; let token = UUID(); generation = token; failed = false
        do { let next = try await RecipeService.recipe("get", id: id, request: request); guard !Task.isCancelled, generation == token else { return }; recipe = next }
        catch is CancellationError {} catch { if generation == token { recipe = nil; failed = true } }
    }
    private func ticket() async {
        guard let request, let recipe else { return }; busy = true; defer { busy = false }
        do { if recipe.saved { _ = try await request("recipes", "unticket", .init(recipeID: id)); await load() } else { self.recipe = try await RecipeService.recipe("ticket", id: id, request: request) } }
        catch { failed = true }
    }
    private func begin() async {
        guard let request else { return }; busy = true; defer { busy = false }
        do { let next = try await RecipeService.begin(id: id, reservation: reservation, request: request); try Task.checkCancellation(); list = try CookingStore.globalRanking(context: context); claim = next }
        catch is CancellationError {} catch { failed = true }
    }
    private func delete() async {
        guard let request else { return }
        do { _ = try await request("recipes", "delete", .init(recipeID: id)); try Task.checkCancellation(); dismiss() } catch { failed = true }
    }
}

struct RecipeEditor: View {
    @Environment(\.socialRequest) private var request
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe?
    let onSave: (Recipe) -> Void
    @State private var content: RecipeContent
    @State private var ingredients: String
    @State private var steps: String
    @State private var shared: Bool
    @State private var recipeID: UUID
    @State private var saving = false
    @State private var failed = false
    init(recipe: Recipe? = nil, onSave: @escaping (Recipe) -> Void) {
        self.recipe = recipe; self.onSave = onSave
        let value = recipe?.content ?? RecipeContent()
        _content = State(initialValue: value); _ingredients = State(initialValue: value.ingredients.joined(separator: "\n")); _steps = State(initialValue: value.steps.joined(separator: "\n"))
        _shared = State(initialValue: recipe?.visibility == "friends"); _recipeID = State(initialValue: recipe?.id ?? UUID())
    }
    var body: some View {
        NavigationStack {
            ScrollView {
              VStack(alignment: .leading, spacing: SGTheme.Space.large) {
                SGPageIntro(title: recipe == nil ? "A recipe worth keeping." : "Make it your recipe.", subtitle: "Ingredients, a little know-how, and somewhere to start.")
                SGFormSection(title: "Recipe") {
                    TextField("Recipe title", text: $content.title).accessibilityIdentifier("recipe-edit-title")
                    TextField("Description · optional", text: optional(\.description), axis: .vertical)
                }
                SGFormSection(title: "Ingredients · one per line") { TextEditor(text: $ingredients).scrollContentBackground(.hidden).frame(minHeight: 100).sgField().accessibilityLabel("Ingredients, one per line").accessibilityIdentifier("recipe-ingredients") }
                SGFormSection(title: "Instructions · one step per line") { TextEditor(text: $steps).scrollContentBackground(.hidden).frame(minHeight: 100).sgField().accessibilityLabel("Instructions, one step per line").accessibilityIdentifier("recipe-steps") }
                SGFormSection(title: "Classification & source") {
                    Picker("Course", selection: optional(\.course)) { Text("None").tag(""); ForEach(DishCategory.allCases, id: \.rawValue) { Text($0.label).tag($0.rawValue) } }
                    TextField("Cuisine · optional", text: optional(\.cuisine))
                    TextField("Source / attribution · optional", text: optional(\.source))
                    TextField("HTTPS source URL · optional", text: optional(\.externalURL)).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    Text("Describe the original source here. The recipe creator and the person whose cooking inspired you are tracked separately.").font(.footnote)
                }
                SGFormSection(title: "Privacy") {
                    Toggle("Share recipe with Sous Chefs", isOn: $shared).accessibilityIdentifier("recipe-sharing")
                    Text("Off keeps this recipe private. On allows current friends to read these recipe fields. Private cooking notes, scores, tags and photos are never copied.").font(.footnote)
                }
                if failed { Text("Couldn’t save. Check the title, source URL and connection. If edited elsewhere, cancel and reload before editing again.").accessibilityIdentifier("recipe-save-error") }
              }.padding(SGTheme.Space.medium).frame(maxWidth: SGTheme.Size.contentMaximum).frame(maxWidth: .infinity)
            }.background(SGTheme.ColorToken.background).scrollDismissesKeyboard(.interactively).navigationTitle(recipe == nil ? "Create Recipe" : "Edit Recipe").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(saving) }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(saving || content.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("recipe-save") }
                }
        }.interactiveDismissDisabled(saving)
    }
    private func optional(_ path: WritableKeyPath<RecipeContent, String?>) -> Binding<String> {
        Binding(get: { content[keyPath: path] ?? "" }, set: { content[keyPath: path] = $0.isEmpty ? nil : $0 })
    }
    private func save() async {
        guard let request else { failed = true; return }; saving = true; failed = false; defer { saving = false }
        content.ingredients = ingredients.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        content.steps = steps.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        do {
            let next = try JSONDecoder().decode(Recipe.self, from: await request("recipes", "save", .init(expectedRevision: recipe?.revision, recipeID: recipeID, recipe: content, visibility: shared ? "friends" : "private")))
            try Task.checkCancellation(); onSave(next); dismiss()
        } catch is CancellationError {} catch { failed = true }
    }
}

struct RecipeCookingProvenance: View {
    let itemID: UUID
    @Environment(\.socialRequest) private var request
    @Environment(\.scenePhase) private var phase
    @State private var cooks: [RecipeCookSnapshot] = []
    @State private var failed = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(cooks) { cook in
                Text("Recipe · \(cook.snapshot.title)").font(.headline)
                if let source = cook.snapshot.source { Text("Source · \(source)").font(.subheadline) }
                Text("Recipe revision \(cook.revision) when this cook began").font(.caption).foregroundStyle(.secondary)
                NavigationLink("View recipe used for this cook") { RecipeSnapshotView(cook: cook) }
            }
            if failed { Button("Retry recipe provenance") { Task { await load() } } }
        }.task(id: itemID) { await load() }
            .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
            .onChange(of: phase) { _, next in cooks = []; if next == .active { Task { await load() } } }
    }
    private func load() async {
        guard let request else { return }
        do { let page = try JSONDecoder().decode(RecipeCooksPage.self, from: await request("recipes", "provenance", .init(targetID: itemID))); try Task.checkCancellation(); cooks = page.cooks; failed = false }
        catch is CancellationError {} catch { cooks = []; failed = true }
    }
}
struct RecipeSnapshotView: View {
    let cook: RecipeCookSnapshot
    var body: some View {
        List {
            Text(cook.snapshot.title).font(.title2.bold())
            if let source = cook.snapshot.source { Text("Source · \(source)") }
            Section("Ingredients") { ForEach(Array(cook.snapshot.ingredients.enumerated()), id: \.offset) { _, text in Text(text).font(SGTheme.TypeRole.reading).lineSpacing(6) } }
            Section("Instructions") { ForEach(Array(cook.snapshot.steps.enumerated()), id: \.offset) { _, text in Text(text).font(SGTheme.TypeRole.reading).lineSpacing(6) } }
            if let id = cook.recipeID { NavigationLink("Current recipe") { RecipeDetailView(id: id) } }
            else { Text("Original recipe is no longer available. This is your historical snapshot.") }
        }.navigationTitle("Recipe used").navigationBarTitleDisplayMode(.inline)
    }
}

private struct RecipeSummaryRow: View {
    let recipe: Recipe
    var ticket: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            SGEyebrow(text: ticket ? "Ticket · Want to cook" : "Recipe")
            Text(recipe.content.title).font(SGTheme.TypeRole.title).foregroundStyle(SGTheme.ColorToken.primaryText).fixedSize(horizontal: false, vertical: true)
            if let source = recipe.content.source { Text(source).font(SGTheme.TypeRole.body).foregroundStyle(.secondary) }
            Text("\(recipe.content.ingredients.count) ingredient\(recipe.content.ingredients.count == 1 ? "" : "s") · \(recipe.content.steps.count) step\(recipe.content.steps.count == 1 ? "" : "s")").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
        }.padding(.vertical, SGTheme.Space.medium).contentShape(Rectangle())
    }
}
