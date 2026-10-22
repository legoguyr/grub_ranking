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
        #expect(Bundle.main.infoDictionary?["UIDeviceFamily"] as? [Int] == [1])
    }

    @Test func releaseVersionBuildAndExemptEncryptionAreExplicit() {
        #expect(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String == "1.0")
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        #expect(build.flatMap(Int.init).map { $0 > 0 } == true)
        #expect(Bundle.main.infoDictionary?["ITSAppUsesNonExemptEncryption"] as? Bool == false)
    }

    @Test func nativeShareImageSavingHasAnAddOnlyPrivacyPurpose() {
        // The native share sheet may save the exported UIImage to Photos. Its
        // system-managed add-only access requires a purpose in the built bundle.
        // Declaring it never requests authorization on app launch or reads Photos.
        let purpose = Bundle.main.infoDictionary?["NSPhotoLibraryAddUsageDescription"] as? String
        #expect(purpose == "Save your StayGrubby share card to Photos when you choose Save Image.")
        #expect(Bundle.main.infoDictionary?["NSPhotoLibraryUsageDescription"] == nil)
    }
}
