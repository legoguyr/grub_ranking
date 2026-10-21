import Foundation
import Testing
@testable import StayGrubby

struct SocialIdentityTests {
    @Test(arguments: [" @Home_Cook ", "HOME_COOK", "home_cook"])
    func normalization(_ input: String) { #expect(SocialIdentityRules.username(input) == "home_cook") }
    @Test func namesAndReservedSeparators() {
        #expect(SocialIdentityRules.name("  Home \n Cook  ") == "Home Cook")
        #expect(SocialIdentityRules.valid(name: "Nick Name", username: "cook_42"))
        for user in ["a", "_cook", "cook_", "a__bc", "a.bc", "a-bc", "école", "stay_grubby", "Admin", "support"] {
            #expect(!SocialIdentityRules.valid(name: "Nick", username: user))
        }
        #expect(!SocialIdentityRules.valid(name: String(repeating: "a", count: 51), username: "cook"))
    }
    @Test func legacyIdentityAndPayloadContainOnlySocialFields() throws {
        let value = try JSONDecoder().decode(SocialIdentity.self, from: Data(#"{"displayName":"","username":null,"discoverable":false}"#.utf8))
        #expect(!value.isConfigured && !value.discoverable)
        let data = try JSONEncoder().encode(SocialPayload(displayName: "Nick", username: "nick", discoverable: true))
        let fields = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(fields.keys) == ["displayName", "username", "discoverable"])
    }
}
