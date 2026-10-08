import Foundation
import Testing

@MainActor struct AppConfigurationTests {
    @Test func iPhoneSupportsOnlyUprightPortrait() {
        // Read the built application bundle, so generated Info.plist settings
        // are verified rather than duplicating the project configuration.
        let orientations = Bundle.main.infoDictionary?["UISupportedInterfaceOrientations~iphone"] as? [String]
        #expect(orientations == ["UIInterfaceOrientationPortrait"])
    }
}
