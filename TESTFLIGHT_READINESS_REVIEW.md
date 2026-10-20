# StayGrubby V1 — TestFlight readiness review

## Current release status — October 20, 2026

The user confirms **StayGrubby 1.0 (1)** archived, validated and uploaded successfully as **TestFlight Internal Only**. The approved release configuration was committed at `067c7b69b223ea60067297132a765a0ccd352238`. The newer Onboarding/Profile/Sharing integration passed physical-iPhone review on October 18 using the existing real account and data. That approval did not create or authorize another archive/upload; 1.0 (1) remains the uploaded baseline. See [V1_INTEGRATION_REVIEW.md](V1_INTEGRATION_REVIEW.md).

The next-release account-deletion/privacy foundation has continued from the preserved uncommitted tree. The owner configured the server-side Apple secret; its name was verified without reading its value. The ninth migration and `delete-account` version 2 are deployed with JWT verification enabled. All nine hashes match hosted history. Existing users/data/Storage counts are unchanged and no account deletion was invoked. The static website and final canonical policy are prepared for Cloudflare Pages, with `https://staygrubby.com/privacy`, effective **October 20, 2026**, privacy contact **privacy@staygrubby.com**, and support **support@staygrubby.com**. Public website publication and a disposable physical-iPhone Apple revocation/deletion test remain before external distribution. The public URL is **prepared, not verified live**. See [account deletion review](ACCOUNT_DELETION_PRIVACY_REVIEW.md) and [Cloudflare steps](Website/README.md).

The minimum iOS target remains **26.5**. It excludes every earlier iOS release and should be an explicit device-coverage decision before broader external/public release. Evaluate the SwiftUI/API availability and test any deliberately lower target on supported systems in a separate scope; do not lower it without that compatibility audit. This task does not change the target, version/build, archive, uploaded build or tester access.

## October 20 final verification

Debug: **279 functions / 383 executions**; **233 unit functions / 336 executions passed**. UI has **46 methods / 47 executions**; the initial full run had one unchanged Contains-test Save tap failure. Its captured editor/selection state and **two unchanged passing repetitions** resolve it as test-runner flakiness without weakening any assertion or changing product behavior. All unique test methods have passing coverage, zero skips/expected failures. The failed initial bundle remains recorded. Optimized Release build and **7/7 Release onboarding/isolation tests passed**. Six Deno tests, 184 backend assertions and five static-site checks passed. Release binary/resource inspection found zero privileged credentials and zero of 16 Debug markers. Normal Debug launch was restored and visually verified.

The complete demo manifest/SQLite metadata and all 190 media files match the baseline exactly; SHA-256 `bedd790ea8487f3b1baad442acd9092a6890b0a38cede4951aef0018469b9a51`. All nine hosted migration hashes match. Final hosted counts remain unchanged, with zero deletion jobs. The existing and additional focused credential scans find no secrets in 221 intended files; whitespace checks pass. [Detailed results, exact file inventory and remaining owner gates](ACCOUNT_DELETION_PRIVACY_REVIEW.md).

## Historical readiness audit — October 14

Audited October 14, 2026. Frozen starting checkpoint: `9968390465658c2a118d2668ee44a0958ea1ec1b` (`Finalize StayGrubby V1 for TestFlight`). Main and origin/main both matched, with zero ahead/behind and a clean working tree before changes. No upload, export, distribution, tester addition, submission, certificate creation, hosted write or real-account deletion occurred.

## Verdict and bounded changes

A valid locally signed Release archive can be created. **It is development-signed, not an App Store distribution-signed deliverable.** The existing local identity is Apple Development; an Apple Distribution identity was not available in the local signing-identity audit. App Store Connect record, agreement and distribution-provisioning status could not be established through authenticated local tooling. Local signature verification does not replace Organizer/App Store Connect distribution validation.

Two safe release-configuration fixes are uncommitted for review:

- The project previously advertised iPad, Mac and visionOS support despite the approved iPhone-only product. App/test targets now support only iphoneos/iphonesimulator with device family 1; the app disables designed-for-iPhone availability on Mac/visionOS. Unused iPad orientation settings were removed. Existing upright-portrait behavior is retained. No iPad UI work was added.
- Generated Info.plist explicitly sets `ITSAppUsesNonExemptEncryption = NO` for Debug and Release. This follows the audited use of Apple URLSession/TLS, Keychain/Security and CryptoKit hashes/signature verification, including the pinned Swift Crypto Darwin implementation. No custom encryption or independent TLS implementation was found in the shipping path. This means **exempt encryption**, not no encryption. [Apple declaration guidance](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption).

AppConfigurationTests verifies the built bundle's iPhone-only device family, upright portrait, initial version/build and Boolean encryption declaration. No application Swift source, product UI, ranking, persistence, authentication, sharing, SDK pin, backend or migration was changed.

## Release identity and archive

| Property | Verified value |
| --- | --- |
| Project / target / shared scheme / product / executable / module | StayGrubby |
| Display name / bundle name | StayGrubby |
| Bundle ID | `com.guyrettig.StayGrubby` |
| Team / signing style | `5DSB36G7LZ` / Automatic |
| Signed application identifier | `5DSB36G7LZ.com.guyrettig.StayGrubby` |
| Capability | `com.apple.developer.applesignin = [Default]` in source, signed entitlement and Apple-signed provisioning profile |
| Marketing version / build | **1.0 / 1**, unchanged |
| Deployment target | **iOS 26.5**, unchanged; beta testers must have a compatible iPhone/iOS version |
| Supported devices / orientation | UIDeviceFamily `[1]`; upright portrait only |
| Assets | Official supplied wordmark; default/light, dark and tinted 1024-pixel opaque icons; compiled Assets.car |
| Archive action | Shared scheme, Release, generic iOS device |
| Archive | `/private/tmp/StayGrubby-V1-Readiness.xcarchive` |
| Signing identity | Apple Development: Guy Rettig (Y5SX4XB4FD) |
| Provisioning profile | iOS Team Provisioning Profile: com.guyrettig.StayGrubby; team 5DSB36G7LZ; expires October 12, 2027 |
| Archive code-signature check | `codesign --verify --deep --strict` passed |
| Debugger entitlement | **get-task-allow = true** because this is a development provisioning profile; distribution signing must replace it with an appropriate App Store profile and **false** |

Version/build are controlled in the application target's Debug/Release build settings in StayGrubby.xcodeproj/project.pbxproj. Generated Info.plist reads MARKETING_VERSION/CURRENT_PROJECT_VERSION; both configurations and test targets agree. There is no contradictory hand-written shipping Info.plist. No increment was made for local builds.

No active old Grub Ranked/Grub Ranking application identity was found. Old workspace paths and historical/migration documentation are internal history, not shipping display names. GitHub subsequently renamed the repository to `legoguyr/StayGrubby`; this does not change any application identity.

The archive was produced with normal `xcodebuild archive`, without `-allowProvisioningUpdates`, using existing local signing material. No private key was displayed/exported. No `-exportArchive`, remote validation or upload command was run. Archive signing metadata is recorded in `/private/tmp/staygrubby-readiness-archive-audit.json`. Obtain/confirm normal distribution signing through Xcode/Apple account management before a future approved upload; do not treat this development signature as final TestFlight signing.

## Debug isolation and authentication

Archive binary inspection found none of the development-library, isolated-store, score/share fixture, large-type review or fresh-restore entry-point strings/types. No backend test controls, seed/reset menu, mock account or personal-library bypass is available in Release. Debug tooling remains intact. The actual optimized Release authentication-gate UI test ignores malicious development launch switches and remains at onboarding without personal content.

Native Sign in with Apple remains the sole visible production entry. Nonce/identity credentials are ephemeral and redacted in descriptions; Supabase verifies them. SDK sessions and verified ready-account mappings use Keychain. Personal data mounts only after matching account resolution and account-store readiness. Sign-out immediately removes personal access even if its network request fails; ordinary sign-out deliberately preserves account-local files and is **not account deletion**.

The bundled approved client-safe configuration points to the audited StayGrubby hosted project. Public provider settings confirm Apple enabled and email/password disabled; only Apple is enabled in the public provider list. There is no anonymous sign-in code path, provision/Storage guards reject anonymous users, and hosted anonymous-user count is zero. No new real Apple authorization occurred during this audit.

## Account deletion — deployed backend, physical verification pending

The next-release source now provides a distinct Profile **Delete account…** action with destructive confirmation and fresh native Apple verification. An authenticated Edge Function derives the current Auth user, validates that exact user's linked Apple identity, revokes Apple authorization, empties the private Storage prefix, cascades the permanent account graph and deletes the Supabase Auth user last. A durable server state makes stage retries idempotent; starting deletion changes the account to `deleting`, so sync/provisioning cannot resurrect it. Confirmed success unmounts the account, removes its exact local directory and returns to onboarding. Cancellation or failure does not report success or delete local data.

The owner-managed Apple signing credential exists only server-side in the protected `STAYGRUBBY_APPLE_CREDENTIALS` secret. No agent read, logged or retrieved its value. Migration `20261020141022_account_deletion_foundation.sql` and `delete-account` v2 are deployed; the earlier unapplied filename was aligned with Supabase's assigned version without SQL changes. Re-review corrected the linked-Apple-subject field from Supabase's row UUID to server-attested `identity_data.sub`. Every retry also validates/revokes its fresh Apple code before cleanup. Six isolated Deno contract tests pass. Anonymous requests fail; full Apple exchange/revocation is **not yet physically verified**. Validate using a disposable Apple account, including a photo-backed library and cancellation/retry, before distributing this as a functional deletion release. Never use the real owner account as a deletion fixture. See [account deletion review](ACCOUNT_DELETION_PRIVACY_REVIEW.md) and [Apple account-deletion guidance](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion).

## Privacy and actual V1 data

This is an inventory/draft disclosure mapping, not submitted App Privacy answers. Collection is private account-linked app functionality, not advertising or cross-app tracking. [Apple disclosure definitions](https://developer.apple.com/app-store/app-privacy-details/).

| Data | On-device / hosted behavior | Candidate App Privacy mapping |
| --- | --- | --- |
| Apple subject, Supabase user/session ID, permanent account ID | Keychain/local identity and private Supabase Auth/account mapping; Apple email or relay email is stored by Auth | User ID; Email Address; linked, App Functionality |
| Account/profile records | Minimal private profile exists; no public profile, following or profile-edit feature; full Apple name is not requested | Account identifiers; do not infer future public-profile fields |
| Dishes, cooks/versions, dates, notes, tags, Courses, Contains, Sources and recipe URLs | Local SwiftData plus private structured cloud sync | Other User Content; linked, App Functionality |
| Optional Person/source name | User may enter a person name as a private Friend/Family Source credit | Include Names where personal names are supplied; no address-book/Contacts access |
| Ranking evidence, choices, reaction/session diagnostics, order, scores | Local calculation and private structured backup | User content and relevant Product Interaction data; App Functionality, not an analytics SDK |
| Selected photos | Optimized display/thumbnail JPEGs on-device and private Storage; original photo-library files are not uploaded | Photos or Videos; linked, App Functionality |
| Revisions, receipts, tombstones, media IDs/checksums/manifests | Local and private hosted sync history used for retries/integrity/deletion | Other Data as applicable; linked, App Functionality |
| Display-mode preference and milestone receipt | Local own-app preferences only; not cloud-synchronized | Not off-device collection |
| Auth/network provider diagnostics | Supabase may retain request/security information such as IP and service errors; confirm provider retention/settings for policy/disclosure | Relevant diagnostic/other data if retained; do not claim no provider logs |

No advertising, analytics or tracking SDK is configured; the optional Supabase logger is nil and its OpenTelemetry trait is not enabled. No ATT request is needed for audited V1 behavior. No location, microphone, camera, address-book, calendar, reminder, Bluetooth or local-network capability is used. Dish dietary/Contains/Avoid metadata is food information, not HealthKit or a collected medical profile. The image pipeline creates new JPEGs from decoded pixels and does not copy source EXIF/GPS dictionaries. Nothing is automatically public: the user deliberately shares only rendered local images through Apple's native sheet. Sources/notes/account identifiers are excluded from those card models.

The next-release source includes one canonical policy with the supplied effective date/contacts and native access from onboarding and authenticated Profile. The sheet includes a system link to `https://staygrubby.com/privacy` and retains offline bundled reading. The website build renders the same Markdown source with no duplicated policy text. Publish the prepared website, verify public HTTPS access, then enter that real URL and `https://staygrubby.com/support` in App Store Connect. No App Store Connect answers or distribution settings were changed. [Apple privacy-policy requirement, 5.1.1(i)](https://developer.apple.com/app-store/review/guidelines/#privacy).

### Recommended App Privacy entries for owner review

Answer **Yes, data is collected**. For these current off-device categories select **App Functionality**, **linked to the user's identity: Yes**, **used for tracking: No**:

| App Store Connect category | Current reason |
| --- | --- |
| Identifiers → User ID | Apple/Supabase/permanent account identifiers and session/account association |
| Contact Info → Email Address | Apple-supplied email/private relay stored by Auth |
| Contact Info → Name | Optional person/author/source names retained in the private cooking library; no Contacts permission |
| User Content → Photos or Videos | User-selected photos, optimized display/thumbnail JPEGs privately backed up |
| User Content → Other User Content | Dish/version titles, notes, dates, Courses, Contains/Dietary/custom tags, Sources and recipe links |
| Usage Data → Product Interaction | Retained comparison choices, timing/session evidence and ranking interactions used by the app |
| Other Data → Other Data Types | Sync revisions/receipts/tombstones, integrity metadata and retained network/security metadata where not covered above |
| Diagnostics → Other Diagnostic Data | Provider-retained request/error/security information; conservatively disclose as linked where requests can be associated with an account |

Do not select advertising, developer marketing, analytics or tracking purposes for the audited implementation. No ATT prompt is used. Do not declare device IDs, location, contacts/address-book access, purchases/payment/financial data, browsing/search history, health/fitness or audio as currently collected app categories. Food tags are cooking metadata, not a medical profile. No crash/performance telemetry SDK was added; if provider settings introduce retained crash/performance telemetry, update those specific categories before release. The public site has no analytics, tracker or Supabase client; provider hosting/security logs are described in the policy. Support email is external user-initiated correspondence, with no in-app support collection SDK/form. Confirm actual provider diagnostics retention against the hosted configuration when submitting; do not claim provider logs are absent. [Apple category/purpose definitions](https://developer.apple.com/app-store/app-privacy-details/).

These are recommended owner answers, **not submitted answers or a claim of legal compliance**. The disclosure must be revisited if implementation/provider practices change.

## Permissions, manifests and dependencies

- PhotosPicker grants access only to selected items; no broad photo-library read-purpose string was added. Native Share Sheet Save Image retains the existing add-only NSPhotoLibraryAddUsageDescription. Other purpose strings are unnecessary for the audited shipping APIs and were not added.
- The archive includes the app manifest with UserDefaults reason **CA92.1**, matching own-app preferences. It also includes swift-crypto_Crypto.bundle's manifest (no tracking/collection/required-reason APIs declared by that SDK resource).
- Source and actual executable imports did not reveal additional app-used file timestamp, boot-time, disk-space or keyboard required-reason APIs. File-size/symlink checks alone do not justify inventing a timestamp reason. No additional declarations were added. [Apple current API categories](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype).
- SDK pin/checkout revisions match: Supabase Swift **2.55.3**, swift-crypto **4.5.2**, swift-asn1 **1.7.3**, swift-http-types **1.8.0**, swift-clocks **1.1.1**, swift-concurrency-extras **1.4.1**, xctest-dynamic-overlay **1.13.1**. No dependency was added/upgraded. Non-shipping SDK test dependencies are not treated as shipped analytics/crypto.

## Historical October 18 hosted audit — read only

StayGrubby project is active/healthy; eight hosted migration MD5 hashes match the first eight unchanged local files. The ninth local deletion migration remains intentionally undeployed. All **16/16** existing private tables have RLS, anonymous application-table grants are zero, direct authenticated write grants are zero, and the four existing authenticated API functions retain their prior access controls. Storage remains a private 2 MiB bucket. Provision, operation and media helpers validate current live sessions/ownership; clients cannot supply another owner to bypass the boundary.

Current aggregate retained state is **3 active Auth users/accounts/rankings, 20 active Dishes, 24 active attempts/items, 79 active comparisons, 22 active media records and 44 Storage objects**. Zero accounts are in `deleting` state and zero active Dish names match the fixture/test-name audit. These counts reflect later physical testing and additional accounts after the historical October 14 review. This task did not create, delete or mutate any hosted record, Auth identity, Storage object, migration or function.

Advisors retain the intentional mapping RLS/no-policy INFO and disabled leaked-password protection WARN; the unused email/password provider is disabled. No new security error was found. Reviewed relevant current changelog items: CBC TLS cipher deprecation does not require a change for the modern OS TLS client; PostgreSQL 17.11 changes do not imply a new schema migration for this app. No ltree/btree_gist or custom legacy crypto use was found. [TLS notice](https://supabase.com/changelog/cbc-tls-ciphers-deprecated), [PostgreSQL notice](https://supabase.com/changelog/postgres-15-19-17-11-breaking-changes).

## Network, logging and data integrity

Bounded regression covers absent session/signed-out relaunch, authenticated restoration, fail-closed wrong identity/partial setup, offline previously-ready account access, network sign-out failure, retryable provisioning/setup, local pending edits, structured-sync/photo errors, corrupt/missing transfers, cancellation, automatic retry and no resurrection. These fault cases use isolated mocks/disposable stores; no live outage or destructive real-account test was induced. Previous physical offline/authenticated/photo lifecycle results remain valid. Brief startup/session-restoration and sync-status transitions are existing future polish, not a new architecture project.

No app print/debug logger containing tokens or private payloads was found. SDK request logging remains unconfigured; safe generic errors/credential redaction remain. The shipped archive was inspected for developer-control and privileged-secret leakage. The public client key is client-safe; it is not treated as the authorization boundary. RLS/live-session guards remain that boundary.

Original Simulator demo preservation and final privileged-secret/whitespace checks are recorded in the final audit artifact after all test launches. All tests use isolated stores/media, and no real authorization/provisioning/upload occurs.

## App Store Connect and beta preparation — drafts only

No authenticated read-only app-record lookup was available without additional account credentials. The local archive/profile proves a registered App ID, **not** an App Store Connect app record. The altool help confirms app/provider listing needs authenticated provider context; it was not invoked against the service with guessed credentials. No record was created and no keychain/account configuration was changed.

If the record is absent, manually choose **iOS; Name StayGrubby; primary language English (U.S.); bundle ID com.guyrettig.StayGrubby; SKU staygrubby-ios-v1**. Choose Full Access for the existing team or Limited Access for the intended team members; either is team access, not public distribution. Check agreements, app-name availability, user roles and whether build 1 is unused. [Apple app-record setup](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/).

Internal team-only TestFlight is the first recommended path after release fixes/signing/record review. It requires a processed eligible build, encryption answers, authorized App Store Connect testers/groups and an appropriate role/app access. It does not need public-launch keywords, subtitle, promotional text, marketing URL or a complete screenshot campaign. External testing adds Beta App Review and its app description, feedback/contact information and testing instructions. A friend with no App Store Connect role is an **external** tester. No tester/group was added. [Apple TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/), [beta information](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/).

Recommended drafts:

**Beta description:** StayGrubby is a private cooking journal that helps you remember what you cook and discover your favorites through quick comparisons. Keep photos, notes and versions, back up your library, and share branded cooking cards.

**What to Test:** Sign in with Apple; add dishes and versions; rank and re-rank using Skip, Undo and Too Tough; check search, filters and Top Version/All Versions; unlock scores after ten ranked entries; verify edits, photos, sync/retry, relaunch persistence and individual/Top 3 sharing. Report unexpected data changes, missing photos, crashes, confusing errors or locked-score exposure. Confirm sync before deliberately reinstalling. No development-library controls exist in this build.

**Feedback/review contact:** User must supply a monitored feedback email and actual review contact name/email/phone. No personal contact details were invented or automatically published from Git/signing metadata.

**Sign-in/review notes:** Native Sign in with Apple is required; no shared password account or production guest bypass exists. A new reviewer/tester account starts empty and is private. Create ten independently ranked dishes/versions to see numerical scores and numerical share exports. Do not provide the developer's personal Apple credentials. Resolve deletion/policy requirements before external review; do not claim those features exist today.

Public App Store description, subtitle, keywords, promotional text, screenshots, marketing URL, final category and other public-listing assets can wait until that submission. Recommended category is Food & Drink. A genuine support/contact destination and privacy policy need to be prepared for the corresponding review/disclosure steps; privacy/deletion cannot be dismissed as marketing. No external metadata or App Privacy answers were submitted.

Age-rating recommendation: answer for a private cooking tool with no public UGC feed, messaging, unrestricted in-app web browser, ads, gambling or developer-supplied objectionable content. User-entered private photos/notes are not a public social network. Do not declare future social features. A low age rating, likely 4+ subject to the actual regional questionnaire, is appropriate; final ratings come from App Store Connect. [Apple current age-rating guidance](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/).

## Verification and next step

- Complete unit suite: **206 functions / 301 executions passed**.
- Bounded Debug UI smoke/regression: **6/6 passed**; combined result **212 functions / 307 executions**, zero failures, expected failures or skips, in `/private/tmp/staygrubby-readiness-regression.xcresult`.
- Backend: **171 local assertions passed** (69 schema/RLS, 60 structured sync, 42 photo-security); no hosted mutation.
- Debug normal build/run passed (66 seconds). Signed device Release archive passed; local signature/entitlement/identity/dev-isolation inspection passed.
- Release test build initially rejected @testable imports from a non-testable optimized module. The test-only invocation adds ENABLE_TESTABILITY=YES without DEBUG; no shipping setting was changed. The optimized Release auth gate passed **1/1**, with zero failures, expected failures or skips. Across Debug and Release checks, **213 functions / 308 executions** passed; the 171 backend assertions are separate. Its result bundle is `/private/tmp/staygrubby-readiness-release-gate.xcresult`.

Final read-only audit passed. The original Simulator demo's complete semantic/media manifest and SQLite metadata match the preserved baseline exactly; SQLite integrity is `ok`: **1 ranking, 12 Dishes, 15 CookingAttempts/RankedItems, 356 Comparisons, 10 Sources, 21 tags, 48 memberships and 190 media files**. No sync operations/bindings/tombstones or photo-transfer journal leaked into this guest library. Manifest SHA-256: `bedd790ea8487f3b1baad442acd9092a6890b0a38cede4951aef0018469b9a51`.

The existing privileged-secret patterns scanned 184 nonignored repository files (180 text files) and the actual archive with zero findings. Client configuration remains unchanged and contains only the approved public fields. Local backups, node dependencies, Supabase local state and local credential/config paths remain ignored. Official wordmark bytes match the supplied original; the three icons remain opaque 1024 × 1024 PNGs. All eight migration hashes and the schema concatenation still match. Audit artifact: `/private/tmp/staygrubby-readiness-final-safety.json`.

`git diff --check` and `git diff --cached --check` passed. Nothing is staged. Main and origin/main still point to the approved checkpoint. Exactly three paths are uncommitted: modified `StayGrubby.xcodeproj/project.pbxproj`, modified `StayGrubbyTests/AppConfigurationTests.swift`, and new `TESTFLIGHT_READINESS_REVIEW.md`. Every other tracked file, including application code, ranking/domain/auth/sync/sharing, backend, migrations, dependencies and official assets, remains identical to HEAD. No commit or push was made.

Next: review the uncommitted release-configuration changes; resolve distribution signing/App Store Connect record access and explicitly address the deletion/privacy-policy release gaps. Then create a new reviewed checkpoint/archive for an approved upload. This development-signed archive is evidence of build readiness only. No public marketing expansion is needed for the initial internal beta, and no upload or external validation has been attempted.
