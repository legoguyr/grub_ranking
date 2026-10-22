import SwiftUI
import SwiftData

/// Read-only cooked history. Recipes and Tickets never enter this query.
struct FoodBibleView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.sgReduceMotion) private var reduceMotion
    @Query(sort: \CookingAttempt.createdAt, order: .reverse) private var attempts: [CookingAttempt]
    @State private var search = ""
    @State private var newCook = false
    private var ranking: RankingList? { try? CookingStore.globalRanking(context: context) }
    private var cooks: [CookingAttempt] {
        attempts.filter { $0.rankedItem != nil && (search.isEmpty || [$0.dish?.name, $0.versionTitle, $0.notes, $0.dish?.cuisine?.label].compactMap { $0 }.joined(separator: " ").localizedStandardContains(search)) }
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SGTheme.Space.large) {
                SGPageIntro(title: "Food Bible", subtitle: "Everything you’ve cooked. Every version worth remembering.", eyebrow: "Made by you", showsTitle: false)
                SGSearchField(placeholder: "Search your cooking", text: $search, identifier: "history-search")
                if cooks.isEmpty { SGEmptyState(title: search.isEmpty ? "Your story starts at the stove." : "No cooks found", message: search.isEmpty ? "Your completed cooks live here. Recipes and Tickets are things you can make next." : "Try another dish, version or note.", symbol: "book.closed") }
                ForEach(cooks) { cook in
                    NavigationLink(value: cook.id) {
                        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                            if cook.primaryImage != nil { SGHeroMedia(media: cook.primaryImage, name: cook.dish?.name ?? cook.displayName) }
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(cook.dish?.name ?? cook.displayName).font(SGTheme.TypeRole.dish)
                                    Text(cook.versionLabel).font(SGTheme.TypeRole.body).foregroundStyle(.secondary)
                                    Text(cook.cookedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Date unknown").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 8)
                                if let item = cook.rankedItem { ScoreBadge(score: item.score) }
                            }
                            Divider()
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("history-cook-\(cook.rankedItemID)")
                }
            }.padding(SGTheme.Space.medium).frame(maxWidth: SGTheme.Size.contentMaximum).frame(maxWidth: .infinity)
        }.background(SGTheme.ColorToken.background).navigationTitle("Food Bible").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("New Dish", systemImage: "plus") { newCook = true }.disabled(ranking == nil) } }
            .navigationDestination(for: UUID.self) { id in if let cook = attempts.first(where: { $0.id == id }) { AttemptDetailView(attempt: cook) } }
            .sheet(isPresented: $newCook) { if let ranking { AddCookingView(list: ranking) } }
            .environment(\.scoreUnlockState, ScoreUnlockPolicy.state(in: context, list: ranking))
            .scrollDismissesKeyboard(.interactively)
    }
}
