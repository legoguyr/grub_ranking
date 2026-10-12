import Foundation
import Testing

@MainActor struct AppConfigurationTests {
    @Test func permanentApplicationIdentity() {
        #expect(Bundle.main.bundleIdentifier == "com.guyrettig.StayGrubby")
        #expect(Bundle.main.infoDictionary?["CFBundleExecutable"] as? String == "StayGrubby")
        #expect(Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String == "StayGrubby")
    }

    @Test func iPhoneSupportsOnlyUprightPortrait() {
        // Read the built application bundle, so generated Info.plist settings
        // are verified rather than duplicating the project configuration.
        let orientations = Bundle.main.infoDictionary?["UISupportedInterfaceOrientations~iphone"] as? [String]
        #expect(orientations == ["UIInterfaceOrientationPortrait"])
    }
}
