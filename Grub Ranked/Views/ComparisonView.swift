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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var selected: ComparisonAnswer?

    var body: some View {
        VStack(spacing: SGTheme.Space.large) {
            Text("Which do you prefer?").font(.title.bold()).multilineTextAlignment(.center)
            choices
            Spacer(minLength: 0)
            actionBar
        }
        .padding(.horizontal, SGTheme.Space.medium).padding(.top, SGTheme.Space.large)
        .background(SGTheme.ColorToken.background)
    }

    private var choices: some View {
        GeometryReader { proxy in
            let gap = SGTheme.Space.xSmall
            let separatorWidth: CGFloat = 30
            let available = max(0, proxy.size.width - separatorWidth - (gap * 2))
            let maximum: CGFloat = verticalSizeClass == .compact ? 140 : 220
            let side = min(maximum, available / 2)

            HStack(alignment: .top, spacing: gap) {
                card(newName, version: newVersion, media: newPhoto, prepared: newPreparedPhoto,
                     side: side, answer: .newItem, identifier: "new")
                    .frame(width: side)
                Text("OR")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: separatorWidth, height: side)
                    .accessibilityHidden(true)
                card(existingName, version: existingVersion, media: existingPhoto,
                     prepared: existingPreparedPhoto, side: side,
                     answer: .existingItem, identifier: "existing")
                    .frame(width: side)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: verticalSizeClass == .compact ? 220 : 300)
    }

    private func card(_ name: String, version: String?, media: CookingMedia?,
                      prepared: PreparedCookingPhoto? = nil, side: CGFloat,
                      answer: ComparisonAnswer,
                      identifier: String) -> some View {
        let spokenName = [name, version].compactMap { $0 }.joined(separator: " — ")
        return Button { choose(answer) } label: {
            VStack(spacing: SGTheme.Space.small) {
                DishPhoto(media: media, prepared: prepared, name: spokenName)
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: SGTheme.Radius.hero, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: SGTheme.Radius.hero, style: .continuous)
                            .stroke(selected == answer ? Color.accentColor : SGTheme.ColorToken.border,
                                    lineWidth: selected == answer ? 3 : 1)
                    }
                    .accessibilityHidden(true)
                Text(name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                if let version {
                    Text(version)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                }
            }
            .scaleEffect(selected == answer ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .frame(width: side, height: side + 96, alignment: .top)
        .accessibilityLabel("Prefer \(spokenName)")
        .accessibilityValue("Square photo area \(Int(side)) by \(Int(side)) points")
        .accessibilityIdentifier("comparison-choice-\(identifier)")
    }

    @ViewBuilder private var actionBar: some View {
        let controls = HStack(spacing: SGTheme.Space.small) {
            Button("Undo", systemImage: "arrow.uturn.backward", action: onUndo).disabled(!canUndo)
            Spacer()
            Button("Too Tough", systemImage: "equal") { onAnswer(.tooTough) }
            Spacer()
            Button("Skip", systemImage: "forward.end") { onAnswer(.skip) }
        }
        .font(.subheadline.weight(.semibold))
        .frame(maxWidth: .infinity, minHeight: 58)
        .padding(.horizontal, SGTheme.Space.medium)

        if #available(iOS 26, *) {
            controls.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 30))
        } else {
            controls.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30))
        }
    }

    private func choose(_ answer: ComparisonAnswer) {
        guard !reduceMotion else { onAnswer(answer); return }
        withAnimation(SGTheme.Motion.quick) { selected = answer }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            onAnswer(answer)
        }
    }
}
