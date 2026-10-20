import Foundation
import SwiftUI

nonisolated enum PrivacyPolicyDocument {
    static let publicURL = URL(string: "https://staygrubby.com/privacy")!
    static func text(bundle: Bundle = .main) -> String? {
        guard let url = bundle.url(forResource: "PrivacyPolicy", withExtension: "md") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                Link("Open public Privacy Policy", destination: PrivacyPolicyDocument.publicURL)
                    .accessibilityIdentifier("privacy-policy-public-link")
                    .padding(.top, SGTheme.Space.medium)
                Text(.init(PrivacyPolicyDocument.text() ?? "Privacy Policy is temporarily unavailable."))
                    .frame(maxWidth: SGTheme.Size.contentMaximum, alignment: .leading)
                    .padding(SGTheme.Space.medium)
            }
            .background(SGTheme.ColorToken.background)
            .navigationTitle("Privacy Policy")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
