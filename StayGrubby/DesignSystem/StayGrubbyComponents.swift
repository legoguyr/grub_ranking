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
        GeometryReader { geometry in
            Group {
                if let loadedImage {
                    Image(uiImage: loadedImage).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    ZStack {
                        LinearGradient(colors: [SGTheme.ColorToken.placeholderStart, SGTheme.ColorToken.placeholderEnd],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: thumbnail ? SGTheme.Size.thumbnailIcon : SGTheme.Size.placeholderIcon)).foregroundStyle(.secondary)
                    }
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
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
            .font(SGTheme.TypeRole.score)
            .foregroundStyle(SGTheme.ColorToken.accent)
            .padding(.horizontal, SGTheme.Space.small).padding(.vertical, SGTheme.Space.xSmall)
            .background(SGTheme.ColorToken.selected, in: RoundedRectangle(cornerRadius: SGTheme.Radius.chip))
            .fixedSize()
            .accessibilityLabel("Score \(score.formatted(.number.precision(.fractionLength(1))))")
    }
}

struct TagChip: View {
    let title: String
    var emphasis = false
    var body: some View {
        Text(title).font(SGTheme.TypeRole.secondary.weight(.medium))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, SGTheme.Space.small).padding(.vertical, SGTheme.Space.xSmall)
            .foregroundStyle(emphasis ? SGTheme.ColorToken.accent : SGTheme.ColorToken.primaryText)
            .background(emphasis ? SGTheme.ColorToken.selected : SGTheme.ColorToken.elevatedSurface, in: Capsule())
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
    @Environment(\.dynamicTypeSize) private var textSize

    private var identity: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.hairline) {
            Text(attempt.dish?.name ?? attempt.displayName)
                .font(SGTheme.TypeRole.headline).lineLimit(textSize.isAccessibilitySize ? nil : 2)
            Text(attempt.versionLabel).font(SGTheme.TypeRole.body)
                .foregroundStyle(.secondary).lineLimit(textSize.isAccessibilitySize ? nil : 2)
            Text(attempt.category.label).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var photo: some View {
        DishPhoto(media: attempt.primaryImage, thumbnail: true, name: attempt.dish?.name ?? attempt.displayName)
            .frame(width: SGTheme.Size.rowThumbnail, height: SGTheme.Size.rowThumbnail)
            .clipShape(RoundedRectangle(cornerRadius: SGTheme.Radius.field))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            HStack(alignment: .center, spacing: SGTheme.Space.small) {
                Text("\(rank)").font(SGTheme.TypeRole.secondary.monospacedDigit()).foregroundStyle(.secondary)
                    .frame(minWidth: SGTheme.Size.rankWidth)
                photo
                if !textSize.isAccessibilitySize { identity }
                if let item = attempt.rankedItem { ScoreBadge(score: item.score) }
            }
            if textSize.isAccessibilitySize { identity }
        }
        .padding(.vertical, SGTheme.Space.small)
        .contentShape(Rectangle())
    }
}

struct SGSectionHeader: View {
    let title: String
    var body: some View {
        Text(title).font(SGTheme.TypeRole.headline).frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Lightweight semantic fade connects hero media to its surrounding page.
struct SGHeroMedia: View {
    let media: CookingMedia?
    let name: String
    var body: some View {
        DishPhoto(media: media, name: name)
            .frame(maxWidth: .infinity)
            .frame(height: media == nil ? SGTheme.Size.placeholderHeight : SGTheme.Size.heroHeight)
            .clipShape(RoundedRectangle(cornerRadius: SGTheme.Radius.hero, style: .continuous))
            .overlay {
                if media != nil {
                    LinearGradient(stops: [
                        .init(color: SGTheme.ColorToken.background.opacity(0), location: 0),
                        .init(color: SGTheme.ColorToken.background.opacity(0), location: 0.55),
                        .init(color: SGTheme.ColorToken.background.opacity(0.35), location: 0.78),
                        .init(color: SGTheme.ColorToken.background, location: 1)
                    ], startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false).accessibilityHidden(true)
                }
            }.accessibilityIdentifier(media == nil ? "hero-placeholder" : "hero-photo")
    }
}

struct SGSearchField: View {
    let placeholder: String
    @Binding var text: String
    let identifier: String
    var body: some View {
        HStack(spacing: SGTheme.Space.small) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
            TextField(placeholder, text: $text).submitLabel(.search).accessibilityIdentifier(identifier)
            if !text.isEmpty {
                SGIconButton(title: "Clear search", symbol: "xmark.circle.fill") { text = "" }
                    .accessibilityIdentifier("\(identifier)-clear")
            }
        }.sgField()
    }
}
