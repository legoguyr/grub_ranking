import SwiftUI

struct ComparisonView: View {
    let newName: String
    let existingName: String
    var newVersion: String?
    var existingVersion: String?
    var newPhoto: CookingMedia?
    var newPreparedPhoto: PreparedCookingPhoto?
    var existingPhoto: CookingMedia?
    var existingPreparedPhoto: PreparedCookingPhoto?
    let canUndo: Bool
    let onAnswer: (ComparisonAnswer) -> Void
    let onUndo: () -> Void
    @Environment(\.sgReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var selected: ComparisonAnswer?
    @State private var answering = false
    @State private var feedback = 0
    @ScaledMetric(relativeTo: .headline) private var titleHeight = SGTheme.Size.comparisonLabelHeight
    @ScaledMetric(relativeTo: .subheadline) private var versionHeight = SGTheme.Size.comparisonLabelHeight

    var body: some View {
        GeometryReader { proxy in
            let side = min(verticalSizeClass == .compact ? SGTheme.Size.comparisonLandscape : SGTheme.Size.comparisonMaximum,
                           max(0, (proxy.size.width - SGTheme.Space.medium * 2 - SGTheme.Size.comparisonSeparator - SGTheme.Space.xSmall * 2) / 2))
            ScrollView {
                VStack(spacing: SGTheme.Space.large) {
                    Text("Which do you prefer?")
                        .font(SGTheme.TypeRole.title).multilineTextAlignment(.center)
                    choices(side: side)
                    actionBar
                }
                .padding(SGTheme.Space.medium)
                .frame(maxWidth: SGTheme.Size.contentMaximum)
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height, alignment: .center)
            }
            .accessibilityIdentifier("comparison-content")
            .background(SGTheme.ColorToken.focusBackground)
        }
        .sensoryFeedback(.selection, trigger: feedback)
        .onChange(of: existingName) { resetSelection() }
        .onChange(of: existingVersion) { resetSelection() }
    }

    @ViewBuilder private func choices(side: CGFloat) -> some View {
        if textSize.isAccessibilitySize {
            // Full labels may grow without forcing two very narrow text columns.
            VStack(spacing: SGTheme.Space.small) {
                card(newName, version: newVersion, media: newPhoto, prepared: newPreparedPhoto,
                     side: side, answer: .newItem, identifier: "new")
                separator
                card(existingName, version: existingVersion, media: existingPhoto, prepared: existingPreparedPhoto,
                     side: side, answer: .existingItem, identifier: "existing")
            }
        } else {
            HStack(alignment: .top, spacing: SGTheme.Space.xSmall) {
                card(newName, version: newVersion, media: newPhoto, prepared: newPreparedPhoto,
                     side: side, answer: .newItem, identifier: "new")
                separator.frame(width: SGTheme.Size.comparisonSeparator, height: side)
                card(existingName, version: existingVersion, media: existingPhoto, prepared: existingPreparedPhoto,
                     side: side, answer: .existingItem, identifier: "existing")
            }
        }
    }
    private var separator: some View {
        Text("OR").font(SGTheme.TypeRole.secondary.weight(.bold)).foregroundStyle(.secondary)
            .accessibilityIdentifier("comparison-or")
    }
    private func card(_ name: String, version: String?, media: CookingMedia?,
                      prepared: PreparedCookingPhoto?, side: CGFloat,
                      answer: ComparisonAnswer, identifier: String) -> some View {
        let versionLabel = version ?? "Version 1"
        let spokenName = "\(name) — \(versionLabel)"
        return Button { choose(answer) } label: {
            VStack(spacing: SGTheme.Space.small) {
                DishPhoto(media: media, prepared: prepared, name: spokenName)
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: SGTheme.Radius.card))
                    .overlay {
                        RoundedRectangle(cornerRadius: SGTheme.Radius.card)
                            .stroke(selected == answer ? SGTheme.ColorToken.accent : SGTheme.ColorToken.border,
                                    lineWidth: selected == answer ? SGTheme.Size.selectedBorder : SGTheme.Size.border)
                    }.accessibilityHidden(true)
                VStack(spacing: SGTheme.Space.xSmall) {
                    Text(name).font(SGTheme.TypeRole.headline)
                        .frame(minHeight: textSize.isAccessibilitySize ? 0 : titleHeight, alignment: .top)
                    Text(versionLabel).font(SGTheme.TypeRole.body).foregroundStyle(.secondary)
                        .frame(minHeight: textSize.isAccessibilitySize ? 0 : versionHeight, alignment: .top)
                }
                .multilineTextAlignment(.center)
                .lineLimit(textSize.isAccessibilitySize ? nil : 3)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .frame(width: side).contentShape(Rectangle())
            .scaleEffect(selected == answer && !reduceMotion ? SGTheme.Motion.pressedScale : 1)
        }
        .buttonStyle(.plain).disabled(answering)
        .accessibilityLabel("Prefer \(spokenName)")
        .accessibilityValue("Square photo area \(Int(side)) by \(Int(side)) points")
        .accessibilityIdentifier("comparison-choice-\(identifier)")
    }
    private var actionBar: some View {
        HStack(spacing: SGTheme.Space.xSmall) {
            action("Undo", symbol: "arrow.uturn.backward") { feedback += 1; onUndo() }.disabled(!canUndo)
            action("Too Tough", symbol: "equal") { submit(.tooTough) }
            action("Skip", symbol: "forward.end") { submit(.skip) }
        }
        .padding(SGTheme.Space.xSmall)
        .background(SGTheme.ColorToken.surface, in: RoundedRectangle(cornerRadius: SGTheme.Radius.card))
        .disabled(answering)
    }
    private func action(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: SGTheme.Space.xSmall) {
                Image(systemName: symbol)
                Text(title).font(SGTheme.TypeRole.secondary.weight(.medium))
            }.frame(maxWidth: .infinity, minHeight: SGTheme.Size.minimumTap)
                .padding(.vertical, SGTheme.Space.xSmall).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(SGTheme.ColorToken.primaryText)
    }
    private func choose(_ answer: ComparisonAnswer) {
        guard !answering else { return }
        answering = true; feedback += 1
        guard !reduceMotion else { onAnswer(answer); resetSelection(); return }
        withAnimation(SGTheme.Motion.quick) { selected = answer }
        Task { @MainActor in
            try? await Task.sleep(for: SGTheme.Motion.selectionDelay)
            onAnswer(answer); resetSelection()
        }
    }
    private func submit(_ answer: ComparisonAnswer) { feedback += 1; onAnswer(answer) }
    private func resetSelection() { selected = nil; answering = false }
}
