# Onboarding verification — complete

Workstream / task: StayGrubby onboarding and authentication presentation.
Branch: `feature/onboarding`
Base commit: `97b1bc3b0f041cc2bbf38b19bde1b1354f7c9953`
Commit: implementation and this report are committed together as **Polish StayGrubby onboarding and authentication presentation**. The final chat integration report supplies the full hash (avoiding a self-referential hash in this file).

## Experience and ownership

One concise welcome screen uses the canonical wordmark, existing semantic theme, a food comparison example, and cooking/version/photo/history and optional dish/Top 3 sharing copy. Native Apple sign-in is the final action. Progress, account restoration/setup, library readiness, recoverable error/retry, and sign-out cleanup have distinct presentation. Normal text keeps sign-in near the bottom; accessibility sizes scroll the complete experience. No intro-completion preference, guest/skip route, remote visual dependency, or social/feed promise was introduced.

Files changed:
- `StayGrubby/Accounts/AuthenticationGateView.swift`
- `StayGrubby/Accounts/AuthenticationGatePresentation.swift` (new, presentation values only)
- `StayGrubbyTests/OnboardingPresentationTests.swift` (new, six focused unit tests)
- `StayGrubbyUITests/OnboardingUITests.swift` (new, four UI tests)
- `ONBOARDING_VERIFICATION.md` (new)

Shared files touched: **NONE**. Existing auth tests, shared UI helpers, app root/navigation, models, theme/assets, Xcode configuration, packages, backend and migrations remain unchanged.

## Test configuration and exact results

Xcode 26.6; iOS 26.5; only **iPhone 17e**, `CCD86BD9-0A42-4C00-A16C-B8D077E6B696`. Dedicated DerivedData: `/private/tmp/staygrubby-onboarding-derived`. The host restart cleared the previous resource blocker: 404 user processes/one defunct at start; 657/two at final audit against the 1,333 per-user limit. No extra simulator was booted and no simulator data was erased.

| Run | Configuration | Exact result |
| --- | --- | --- |
| Rebuild/run saved implementation | Debug | Build and launch passed, 119.5 s |
| Normal-size native-control accessibility probe | Debug | 1 passed, 0 failed, 0 skipped, 75.2 s |
| Focused auth/readiness/presentation plus initial UI suites | Debug | **46 unit tests in 6 suites + 5 UI tests passed; 0 failed, 0 skipped**, 98.8 s |
| Actual maximum system Dynamic Type, dark | Debug | 1 UI test passed, 0 failed, 0 skipped, 39.7 s; screenshot inspected |
| Additional light-mode reachability run | Debug | 1 UI test passed, 0 failed, 0 skipped, 40.4 s; superseded by distinct moderate/max cases below |
| Initial optimized production gate/UI suite | Release | 4 passed, 0 failed, 0 skipped, 159.4 s |
| Expanded Debug UI checks | Debug | 4 passed, 2 failed, 0 skipped, 73.1 s; test-only container-class query corrected |
| Corrected moderate and maximum text checks | Debug | **2 passed, 0 failed, 0 skipped**, 42.5 s; entire 50-point native button required inside visible gate bounds |
| Final optimized production gate/UI suite | Release | **5 passed, 0 failed, 0 skipped**, 88.9 s; all four final onboarding UI tests plus ReleaseAuthenticationGateUITests |

Final coverage is **46 passing unit tests, all 6 Debug UI methods verified (4 standard/development checks plus the 2 corrected text-size cases), and 5 passing Release UI tests**. These are counts by verification set, not a sum of unique tests across repeated configurations. No unresolved test failure or skip remains.

The six unit suites are OnboardingPresentationTests, AppleSignInTests, AccountSessionTests, AccountLibraryAccessTests, OfflineAccountGateTests, and DebugReviewIsolationTests. They verify nonce/token semantics, auth and provisioning retries, repeated-login account identity, stale callback/sign-out rejection, pending/wrong-owner readiness denial, local store readiness after retry, and Debug fixture isolation. The new readiness test uses a unique temporary store and verifies failure → retry → waiting with no access → exact-account ready → reset closes access. The preserved root condition mounts personal content only for that resolved account and ready store.

The initial post-restart probe confirmed the saved accessibility containment fix resolves pre-restart native-button/brand lookup failures. The later two Debug failures were a UI-test query that assumed an Other container; accessibility sizes expose the gate as a ScrollView. Querying its identifier across element types fixed both checks. Production authentication code was not changed to address either issue.

## Reproducible tool invocations

All builds/tests used XcodeBuildMCP with defaults:

```json
{
  "projectPath": "/Users/guyrettig/Documents/StayGrubby-Worktrees/onboarding/StayGrubby.xcodeproj",
  "scheme": "StayGrubby",
  "simulatorId": "CCD86BD9-0A42-4C00-A16C-B8D077E6B696",
  "derivedDataPath": "/private/tmp/staygrubby-onboarding-derived",
  "bundleId": "com.guyrettig.StayGrubby",
  "preferXcodebuild": true
}
```

`build_run_sim({})` used configuration Debug. Every `test_sim` call used `progress: false` and these serial extra arguments:

```text
-parallel-testing-enabled NO
-maximum-concurrent-test-simulator-destinations 1
-resultBundlePath <result path below>
```

Focused Debug selectors (each prefixed with `-only-testing:`):

```text
StayGrubbyTests/OnboardingPresentationTests
StayGrubbyTests/AppleSignInTests
StayGrubbyTests/AccountSessionTests
StayGrubbyTests/AccountLibraryAccessTests
StayGrubbyTests/OfflineAccountGateTests
StayGrubbyTests/DebugReviewIsolationTests
StayGrubbyUITests/OnboardingUITests
StayGrubbyUITests/AccountEntryUITests
```

Expanded Debug UI selectors were the two UI suites above. Corrected text-size selectors were `StayGrubbyUITests/OnboardingUITests/testAccessibilityLargeTextCanScrollToNativeAuthentication` and `StayGrubbyUITests/OnboardingUITests/testLargestTextCanScrollToNativeAuthentication`. Final Release used `ENABLE_TESTABILITY=YES` plus selectors `StayGrubbyUITests/ReleaseAuthenticationGateUITests` and `StayGrubbyUITests/OnboardingUITests`. Testability permits the existing @testable unit target to compile; **Release remains optimized and DEBUG is absent**. No project settings were edited.

Result paths:
- Focused Debug: `/private/tmp/staygrubby-onboarding-restart-debug.xcresult`
- Expanded Debug UI (contains the resolved query failures): `/private/tmp/staygrubby-onboarding-final-debug-ui.xcresult`
- Corrected text checks: `/private/tmp/staygrubby-onboarding-final-debug-large-fixed.xcresult`
- Final Release: `/private/tmp/staygrubby-onboarding-final-release.xcresult`

Full literal xcodebuild build-for-testing and test-without-building commands and raw output are in:
- `/Users/guyrettig/Library/Developer/XcodeBuildMCP/workspaces/Grub-Ranked-c2d28c43fd9c/logs/test_sim_2026-10-15T02-08-58-024Z_pid1857_451b61eb.log`
- `/Users/guyrettig/Library/Developer/XcodeBuildMCP/workspaces/Grub-Ranked-c2d28c43fd9c/logs/test_sim_2026-10-15T02-18-36-063Z_pid1857_3f7db6f2.log`
- `/Users/guyrettig/Library/Developer/XcodeBuildMCP/workspaces/Grub-Ranked-c2d28c43fd9c/logs/test_sim_2026-10-15T02-20-36-469Z_pid1857_ab43d8c3.log`
- `/Users/guyrettig/Library/Developer/XcodeBuildMCP/workspaces/Grub-Ranked-c2d28c43fd9c/logs/test_sim_2026-10-15T02-21-25-211Z_pid1857_45b6b00e.log`

## Release gating and Debug isolation

**PASS.** The actual optimized Release UI stays at native Apple onboarding on ordinary launch, relaunch, and development/fixture launch arguments. Rankings, Profile, dish creation, guest/skip access, and development controls are absent. Intro presentation does not grant application access. The shared root's resolved-account AND exact-store-readiness condition remains unchanged.

**PASS.** Debug's isolated development library still opens and exits back to onboarding; no real-account/demo data is mixed. An executable/symbol/string audit found development types/actions/flags in Debug as a positive control and none in Release. It checked DevelopmentLibraryAccess, DebugReviewConfiguration, beginDevelopmentReview, ComparisonReviewFixture, development/UI-store/comparison/sharing/discovery/score-fixture flags, development open/exit controls, and guest control literals. Release compiler commands confirm optimization, testability, and no DEBUG definition.

Audit: `/private/tmp/staygrubby-onboarding-evidence/release-isolation-audit.json`
Final Release executable SHA-256: `afcf57be7b8fa9537ece595b91d9cb9bb8b47ce096713b7028bb4afe49fb4b0c`.

## Visual and accessibility verification

Portrait iPhone 17e inspected in normal light and dark appearance. The complete concise story and native Apple action fit at standard size. Actual system text settings were applied with `xcrun simctl ui <UDID> content_size accessibility-large` and `accessibility-extra-extra-extra-large`; relaunch was needed for SwiftUI to adopt the changed setting. Separate final UI cases launch with `UICTContentSizeCategoryAccessibilityL` and `UICTContentSizeCategoryAccessibilityXXXL`, scroll the actual scroll view, and require the full native button to be visible with at least 44-point height. Both passed in Debug and Release. Combined semantic labels, wordmark identity, native-control identifier, and safe error-announcement wiring are present; a spoken VoiceOver session was not performed.

Inspected evidence (local artifacts, not new application assets):
- `/private/tmp/staygrubby-onboarding-evidence/light-normal.jpg`
- `/private/tmp/staygrubby-onboarding-evidence/dark-normal.jpg`
- `/private/tmp/staygrubby-onboarding-evidence/light-accessibility-large-top.jpg`
- `/private/tmp/staygrubby-onboarding-evidence/light-accessibility-large-bottom.png`
- `/private/tmp/staygrubby-onboarding-evidence/light-maximum-type-bottom.png`
- `/private/tmp/staygrubby-onboarding-evidence/dark-maximum-type-bottom.png`

## Contracts, limitations, and integration

**Explicit confirmation:** underlying Supabase authentication, native Apple request/callback/nonce/token handling, permanent account provisioning, repeated-login identity, session lifecycle, and account-store readiness contracts were not changed. NativeAppleAuthenticationButton is text-identical to the base. An exhaustive tracked-file audit found only AuthenticationGateView changed; all additional source files are onboarding-only presentation/tests. No existing shared test/helper or protected architecture/configuration file changed. `git diff --check` passed.

Contract evidence: `/private/tmp/staygrubby-onboarding-evidence/final-contract-audit.json`.

Coordinator dependencies: **NONE**. Migrations/backend/schema/package changes: **NONE**. Known outstanding implementation failures: **NONE**. A fresh physical-device/hosted Apple authorization was not repeated; existing local mocked auth and readiness tests passed and the previously device-tested implementation remains unchanged. Existing SDK initial-session diagnostic and an unrelated redundant-#require test warning were observed; neither was changed or surfaced in user-facing copy.

Integration: review/cherry-pick the single onboarding commit identified in the final chat report and run the Coordinator's integrated regressions. No merge, push, or main modification was performed. Only the selected simulator was used; standard system text/light appearance is restored, and final chat report confirms shutdown after commit. Simulator data is retained.
