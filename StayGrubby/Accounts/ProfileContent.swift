import SwiftUI

/// Feature-local composition; shared theme, photo loading and sharing stay authoritative.
struct ProfileCookingContent: View {
    let snapshot: ProfileSnapshot
    let ranking: RankingList?
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.large) {
            topFoods
            cookingSnapshot
        }
    }

    private var cookingSnapshot: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
            Text("In your Food Bible").font(SGTheme.TypeRole.headline).accessibilityAddTraits(.isHeader)
            let columns = textSize.isAccessibilitySize ? 1 : 2
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: columns),
                      alignment: .leading, spacing: SGTheme.Space.medium) {
                statistic(snapshot.rankedEntryCount, title: "Ranked entries", identifier: "profile-entry-count")
                statistic(snapshot.dishCount, title: "Dishes ranked", identifier: "profile-dish-count")
            }
            Text("Each independently ranked version counts as an entry.")
                .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
            if let date = snapshot.lastCookedAt {
                Divider()
                if textSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                        Text("Last cooked")
                        Text(date, format: .dateTime.month(.abbreviated).day().year()).foregroundStyle(.secondary)
                    }.font(SGTheme.TypeRole.body)
                } else {
                    LabeledContent("Last cooked") {
                        Text(date, format: .dateTime.month(.abbreviated).day().year())
                    }.font(SGTheme.TypeRole.body)
                }
            }
        }.padding(.vertical, SGTheme.Space.medium)
    }

    private func statistic(_ count: Int, title: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.hairline) {
            Text(count, format: .number).font(.system(.largeTitle, design: .rounded, weight: .bold)).monospacedDigit()
            Text(title).font(SGTheme.TypeRole.body).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) \(title.lowercased())")
        .accessibilityIdentifier(identifier)
    }

    private var topFoods: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
            VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                Text("Signature Dishes").font(SGTheme.TypeRole.title).accessibilityAddTraits(.isHeader)
                Text(snapshot.topFoods.isEmpty ? "Good food starts with your next cook." : "The dishes and versions leading your rankings.")
                    .font(SGTheme.TypeRole.body).foregroundStyle(.secondary)
            }

            if let first = snapshot.topFoods.first {
                NavigationLink(value: first.attempt.id) { ProfileTopFood(food: first, featured: true) }.buttonStyle(.plain)
                ForEach(snapshot.topFoods.dropFirst()) { food in
                    NavigationLink(value: food.attempt.id) { ProfileTopFood(food: food, featured: false) }.buttonStyle(.plain)
                }
                if snapshot.topFoods.count < 3 {
                    Text("Keep cooking to find your Signature Dishes.")
                        .font(SGTheme.TypeRole.body).foregroundStyle(.secondary)
                        .accessibilityIdentifier("profile-building-top-three")
                }
            } else {
                VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                    Image(systemName: "fork.knife.circle").font(.largeTitle)
                        .foregroundStyle(SGTheme.ColorToken.accent).accessibilityHidden(true)
                    Text("Make something worth remembering.").font(SGTheme.TypeRole.headline)
                    Text("Add your first dish in Grub Rank. As you cook and compare, your favorites will take their place here.")
                        .font(SGTheme.TypeRole.body).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).sgCard()
                    .accessibilityIdentifier("profile-empty")
            }

            VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                if snapshot.scores.isUnlocked {
                    Text("A little taste of your best.").font(SGTheme.TypeRole.headline)
                    Text("Share your current Top 3 as a single image.")
                        .font(SGTheme.TypeRole.body).foregroundStyle(.secondary)
                } else {
                    ScoreUnlockProgressBanner(state: snapshot.scores)
                }
                // Keep the permanent action and all export/native-sheet gating intact.
                TopThreeShareAction(list: ranking, title: "Share Signature Dishes")
            }
        }
    }
}

private struct ProfileTopFood: View {
    let food: ProfileSnapshot.Food
    let featured: Bool
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
            if featured {
                SGHeroMedia(media: food.attempt.primaryImage, name: food.title).accessibilityHidden(true)
            }
            HStack(alignment: .top, spacing: SGTheme.Space.small) {
                if !featured {
                    DishPhoto(media: food.attempt.primaryImage, thumbnail: true, name: food.title)
                        .frame(width: SGTheme.Size.versionThumbnail, height: SGTheme.Size.versionThumbnail)
                        .clipShape(RoundedRectangle(cornerRadius: SGTheme.Radius.chip))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                    Text(food.rank == 1 ? "#1 · Signature Dish" : "#\(food.rank)")
                        .font(SGTheme.TypeRole.secondary.weight(.semibold))
                        .foregroundStyle(featured ? SGTheme.ColorToken.accent : .secondary)
                    Text(food.title).font(featured ? SGTheme.TypeRole.title : SGTheme.TypeRole.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(food.attempt.versionLabel).font(SGTheme.TypeRole.body).foregroundStyle(.secondary)
                    Text(food.attempt.category.label).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                    if textSize.isAccessibilitySize { score }
                }.frame(maxWidth: .infinity, alignment: .leading)
                if !textSize.isAccessibilitySize { score }
            }
        }.padding(.vertical, SGTheme.Space.small)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(food.accessibilityLabel)
            .accessibilityIdentifier("profile-top-food-\(food.rank)")
    }

    @ViewBuilder private var score: some View {
        if let text = food.scoreText {
            Text(text).font(SGTheme.TypeRole.score)
                .foregroundStyle(SGTheme.ScoreColor.color(forDisplayedScore: text))
                .fixedSize().accessibilityIdentifier("profile-score-\(food.rank)")
        } else {
            LockedScoreIndicator()
        }
    }
}
