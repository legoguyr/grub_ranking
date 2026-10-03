import SwiftUI

struct InitialReactionView: View {
    let name: String
    let choose: (InitialReaction) -> Void
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(name).font(.title3).foregroundStyle(.secondary)
                Text("How was it?").font(.largeTitle.bold())
                ForEach(InitialReaction.allCases) { reaction in
                    Button { choose(reaction) } label: {
                        Text(reaction.rawValue).font(.headline).frame(maxWidth: .infinity, minHeight: 64)
                    }.buttonStyle(.bordered)
                }
                Text("Just a starting point. Your comparisons decide the score.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.padding(24)
        }
    }
}
