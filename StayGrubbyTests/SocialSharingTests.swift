import Foundation
import Testing
@testable import StayGrubby

@MainActor struct SocialSharingTests {
    @Test func legacyUnsetAndUnconfiguredIdentityStayPrivate() throws {
        let legacy = try JSONDecoder().decode(SocialIdentity.self, from: Data(#"{"displayName":"Legacy","username":"legacy","discoverable":false}"#.utf8))
        #expect(!legacy.sharingDefault)
        #expect(!SocialIdentity(displayName: "Guest", username: nil, discoverable: false, automaticallyShareNewDishes: true).sharingDefault)
        #expect(SocialIdentity(displayName: "Cook", username: "cook", discoverable: false, automaticallyShareNewDishes: true).sharingDefault)
    }
}
