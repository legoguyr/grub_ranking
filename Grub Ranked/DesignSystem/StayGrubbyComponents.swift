import SwiftUI
import UIKit

struct DishPhoto: View {
    var media: CookingMedia?
    var prepared: PreparedCookingPhoto?
    var thumbnail = false
    var name = "Dish"
    @State private var loadedImage: UIImage?

    private struct ImageRequest: Equatable {
        let mediaID: UUID?
        let filename: String?
        let thumbnail: Bool
        let preparedData: Data?
    }

    private var request: ImageRequest {
        ImageRequest(mediaID: media?.id, filename: thumbnail ? media?.thumbnailFilename : media?.displayFilename,
                     thumbnail: thumbnail, preparedData: prepared.map { thumbnail ? $0.thumbnailData : $0.displayData })
    }

    var body: some View {
        Group {
            if let loadedImage {
                Image(uiImage: loadedImage).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [Color.secondary.opacity(0.13), Color.secondary.opacity(0.05)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: thumbnail ? 24 : 48)).foregroundStyle(.secondary)
                }
            }
        }
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(loadedImage == nil ? "No photo for \(name)" : "Photo of \(name)")
        .task(id: request) {
            // Retain the decoded thumbnail through query/filter re-renders. Only a
            // changed photo source or size triggers disk access and decoding.
            let data = request.preparedData ?? media.flatMap { LocalPhotoStore.data(for: $0, thumbnail: thumbnail) }
            loadedImage = data.flatMap(UIImage.init(data:))
        }
    }
}

struct ScoreBadge: View {
    let score: Double
    var body: some View {
        Text(score, format: .number.precision(.fractionLength(1)))
            .font(.title3.weight(.bold).monospacedDigit())
            .foregroundStyle(.tint)
            .accessibilityLabel("Score \(score.formatted(.number.precision(.fractionLength(1))))")
    }
}

struct TagChip: View {
    let title: String
    var emphasis = false
    var body: some View {
        Text(title)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .foregroundStyle(emphasis ? Color.accentColor : Color.primary)
            .background(emphasis ? Color.accentColor.opacity(0.14) : SGTheme.ColorToken.elevatedSurface,
                        in: Capsule())
    }
}

struct SourceSummary: View {
    let source: DishSource
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            Label(source.summary, systemImage: "text.book.closed")
                .font(.headline)
            ForEach(source.detailRows, id: \.label) { row in
                LabeledContent(row.label, value: row.value)
                    .font(.subheadline)
            }
        }
    }
}

struct RankedDishRow: View {
    let attempt: CookingAttempt
    let rank: Int

    private var lightweightTags: [String] {
        var labels = [attempt.category.label]
        labels += attempt.dietaryTags.map(\.label).sorted()
        labels += attempt.customTags
        return Array(labels.prefix(3))
    }

    var body: some View {
        HStack(spacing: SGTheme.Space.medium) {
            Text("\(rank)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary).frame(width: 24)
            DishPhoto(media: attempt.primaryImage, thumbnail: true,
                      name: attempt.dish?.name ?? attempt.displayName)
                .frame(width: SGTheme.Size.rowThumbnail, height: SGTheme.Size.rowThumbnail)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(attempt.dish?.name ?? attempt.displayName).font(.headline).lineLimit(1)
                if attempt.dish?.attempts.count ?? 0 > 1 || attempt.versionTitle != nil {
                    Text(attempt.versionLabel).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                HStack(spacing: 5) {
                    ForEach(lightweightTags, id: \.self) { TagChip(title: $0) }
                }
            }
            Spacer(minLength: SGTheme.Space.xSmall)
            if let item = attempt.rankedItem { ScoreBadge(score: item.score) }
        }
        .padding(.vertical, SGTheme.Space.xSmall)
        .contentShape(Rectangle())
    }
}

struct SGSectionHeader: View {
    let title: String
    var body: some View {
        Text(title).font(.title3.bold()).frame(maxWidth: .infinity, alignment: .leading)
    }
}
