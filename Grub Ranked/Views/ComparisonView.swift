import SwiftUI

struct ComparisonView: View {
    let newName: String
    let existingName: String
    let canUndo: Bool
    let onAnswer: (ComparisonAnswer) -> Void
    let onUndo: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Text("Which do you prefer?").font(.largeTitle.bold()).multilineTextAlignment(.center)
                HStack(alignment: .center, spacing: 10) {
                    card(newName, answer: .newItem)
                    Text("OR").font(.caption).foregroundStyle(.secondary)
                    card(existingName, answer: .existingItem)
                }
                Button { onAnswer(.tooTough) } label: {
                    Text("Too Tough").font(.headline).frame(maxWidth: .infinity, minHeight: 48)
                }.buttonStyle(.bordered)
                HStack {
                    Button("Undo", systemImage: "arrow.uturn.backward", action: onUndo).disabled(!canUndo)
                    Spacer()
                    Button("Skip") { onAnswer(.skip) }
                }.frame(minHeight: 44)
            }.padding(24)
        }
    }
    private func card(_ name: String, answer: ComparisonAnswer) -> some View {
        Button { onAnswer(answer) } label: {
            Text(name).font(.title3.weight(.semibold)).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 180).padding(8)
                .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
                .overlay { RoundedRectangle(cornerRadius: 20).stroke(.tint.opacity(0.3)) }
        }.buttonStyle(.plain).accessibilityLabel("Prefer \(name)")
    }
}
