import SwiftUI
import UIKit
import SwiftData

nonisolated struct TopThreeShareCardModel: Equatable, Sendable {
    struct Row: Equatable, Sendable {
        let position: Int
        let dish: ShareCardModel
    }
    let rows: [Row]
    var isUnlockMilestone = false

    @MainActor static func make(in list: RankingList, milestone: Bool = false) -> Self? {
        guard let context = list.modelContext, ScoreUnlockPolicy.state(in: context, list: list).isUnlocked else { return nil }
        let entries = Array(ScoreUnlockPolicy.entries(in: context, list: list).prefix(3))
        guard entries.count == 3 else { return nil }
        let rows = entries.enumerated().map { Row(position: $0.offset + 1, dish: .make(for: $0.element.attempt)) }
        guard rows.allSatisfy({ $0.dish.scoreText != nil }) else { return nil }
        return Self(rows: rows, isUnlockMilestone: milestone)
    }
}

struct TopThreeShareCardView: View {
    let model: TopThreeShareCardModel
    let photos: [UIImage?]
    var body: some View {
        ZStack {
            SGTheme.Brand.cream
            VStack(spacing: 24) {
                if let logo = OfficialBrandWordmark.image {
                    Image(uiImage: logo).resizable().scaledToFit().frame(width: 280, height: 170)
                }
                Text("My Top 3 Dishes So Far")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(SGTheme.Brand.charcoal).multilineTextAlignment(.center)
                VStack(spacing: 24) {
                    ForEach(Array(model.rows.enumerated()), id: \.offset) { index, row in
                        HStack(spacing: 24) {
                            Text("#\(row.position)").font(.system(size: 30, weight: .medium))
                                .foregroundStyle(SGTheme.Brand.charcoal.opacity(0.6)).frame(width: 48)
                            ZStack {
                                if let photo = photos[index] {
                                    Image(uiImage: photo).resizable().scaledToFill()
                                } else {
                                    SGTheme.Brand.red.opacity(0.045)
                                    UniversalFoodOutline().stroke(SGTheme.Brand.red,
                                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                                        .padding(22)
                                }
                            }.frame(width: 208, height: 208)
                                .clipShape(RoundedRectangle(cornerRadius: 22))
                            VStack(alignment: .leading, spacing: 12) {
                                Text(row.dish.title).font(.system(size: 38, weight: .bold, design: .rounded))
                                    .lineLimit(3).minimumScaleFactor(0.65)
                                if let version = row.dish.versionSubtitle {
                                    Text(version).font(.system(size: 27, weight: .medium))
                                        .foregroundStyle(SGTheme.Brand.charcoal.opacity(0.6))
                                        .lineLimit(2).minimumScaleFactor(0.7)
                                }
                            }.foregroundStyle(SGTheme.Brand.charcoal)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(row.dish.scoreText ?? "").font(.system(size: 44, weight: .bold, design: .rounded))
                                .monospacedDigit().foregroundStyle(SGTheme.Brand.red).frame(width: 112, alignment: .trailing)
                        }.padding(20).frame(height: 260)
                            .background(.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 24))
                    }
                }
                if model.isUnlockMilestone {
                Label("SCORES UNLOCKED", systemImage: "lock.open.fill")
                    .font(.system(size: 26, weight: .bold)).foregroundStyle(SGTheme.Brand.red)
                    .padding(.horizontal, 30).padding(.vertical, 14)
                    .background(SGTheme.Brand.red.opacity(0.075), in: Capsule())
                } else { Color.clear.frame(height: 58).accessibilityHidden(true) }
            }.padding(48)
        }
        .frame(width: 1_080, height: 1_350).clipped()
        .environment(\.colorScheme, .light).environment(\.dynamicTypeSize, .medium)
    }
}

struct ScoreUnlockMilestoneView: View {
    let list: RankingList
    let onClose: () -> Void
    @Environment(\.cookingMediaRoot) private var mediaRoot
    @Environment(\.sgReduceMotion) private var reduceMotion
    @State private var card: RenderedDishShareCard?
    @State private var sharing: RenderedDishShareCard?
    @State private var failed = false
    @State private var appeared = false
    @State private var fileRevision = 0
    private struct PreviewRequest: Equatable {
        let model: TopThreeShareCardModel?
        let fileRevision: Int
    }
    private var model: TopThreeShareCardModel? { .make(in: list, milestone: true) }
    var body: some View {
        ScrollView {
            VStack(spacing: SGTheme.Space.large) {
                Image(systemName: "lock.open.fill").font(.title2).foregroundStyle(SGTheme.Brand.red).accessibilityHidden(true)
                Text("Your scores are unlocked!").font(SGTheme.TypeRole.title)
                Text("You've ranked \(ScoreUnlockPolicy.requiredRankedEntryCount) dishes and versions. Your numerical scores are now available!")
                    .font(SGTheme.TypeRole.body).foregroundStyle(.secondary)
                if let card, model != nil {
                    Image(uiImage: card.image).resizable().scaledToFit()
                        .frame(maxHeight: SGTheme.Size.sharingPreviewMaximumHeight)
                        .accessibilityLabel(previewLabel)
                        .accessibilityIdentifier("top-three-preview")
                }
            }.multilineTextAlignment(.center).padding(SGTheme.Space.large)
                .frame(maxWidth: SGTheme.Size.sharingContentMaximum).frame(maxWidth: .infinity)
                .opacity(appeared ? 1 : 0)
        }
        .accessibilityIdentifier("score-unlock-milestone")
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: SGTheme.Space.small) {
                Button("Share My Top 3", systemImage: "square.and.arrow.up") {
                    guard let current = model else { return }
                    do { sharing = try ShareCardRenderer.render(topThree: current, mediaRoot: mediaRoot) }
                    catch { failed = true }
                }.buttonStyle(SGButtonStyle(prominent: true, prominentColor: SGTheme.ColorToken.buttonAccent))
                    .disabled(model == nil).accessibilityIdentifier("share-top-three")
                Button("Done", action: onClose).buttonStyle(SGButtonStyle()).accessibilityIdentifier("ranking-result-close")
            }.padding(SGTheme.Space.medium).frame(maxWidth: .infinity).background(SGTheme.ColorToken.background)
        }
        .background(SGTheme.ColorToken.background)
        .task(id: PreviewRequest(model: model, fileRevision: fileRevision)) {
            card = model.flatMap { try? ShareCardRenderer.render(topThree: $0, mediaRoot: mediaRoot) }
            if model == nil { sharing = nil }
            withAnimation(reduceMotion ? nil : SGTheme.Motion.standard) { appeared = true }
        }
        .sheet(item: $sharing) { NativeDishShareSheet(card: $0) }
        .onReceive(NotificationCenter.default.publisher(for: .cookingPhotoFilesRestored)) { notification in
            if notification.object as? URL == mediaRoot,
               model?.rows.contains(where: { $0.dish.photo?.id == notification.userInfo?["mediaID"] as? UUID }) == true {
                fileRevision += 1
            }
        }
        .alert("Couldn't prepare share card", isPresented: $failed) { Button("OK", role: .cancel) {} }
    }
    private var previewLabel: String {
        guard let model else { return "Scores locked" }
        return "My Top 3 Dishes So Far. " + model.rows.map {
            "\($0.position), \($0.dish.title), \($0.dish.versionSubtitle ?? ""), \($0.dish.scoreText ?? "") out of 10"
        }.joined(separator: ". ")
    }
}
