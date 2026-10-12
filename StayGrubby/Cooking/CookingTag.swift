import Foundation
import SwiftData

/// Separate rows, scalar queryable kind/value, and explicit many-to-many membership.
@Model
final class CookingTag {
    @Attribute(.unique) var key: String
    var kindCode: String
    var value: String
    var label: String
    @Relationship(deleteRule: .nullify, inverse: \CookingAttempt.tags) var attempts: [CookingAttempt] = []
    init(kind: CookingTagKind, value: String, label: String) {
        self.key = "\(kind.rawValue):\(value)"; kindCode = kind.rawValue
        self.value = value; self.label = label
    }
}
