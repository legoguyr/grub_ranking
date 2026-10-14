> Historical iteration: the score gate now counts eligible ranked entries, including versions. Physical card/gate testing passed; see V1_FINAL_REVISIONS_REVIEW.md for the final bounded revisions and current verification. Earlier test counts and unique-Dish rules below are historical.

# Core App V1 — score visibility and Top 3 milestone

The combined work remains uncommitted on main at `a4b61eb177db055723ed07319e1c0655afbb8bca`. The user passed Phase 3D Part 2 physical photo backup/restore/replacement/deletion/no-resurrection verification. This new score-unlock feature is not yet physically approved. No deleted test data was recreated and no cloud write or real Apple authorization is performed by this task.

## Counting and visibility

`ScoreUnlockPolicy.requiredDishCount = 10` is the only threshold configuration. It reads the accepted local `CookingLibrary` global ranking and existing `CookingDiscovery` order. Eligible entries must have a saved, active Dish → CookingAttempt → RankedItem bridge in that global ranking. Unsaved insertions, pending deletions, historical/unranked bridges, retired dish/attempt/item/ranking references and a store still requiring restoration are excluded. Unique Dish UUIDs count once, regardless of versions; names are not a substitute for domain identity. Scores, evidence and order continue to calculate/persist normally from the first cook, including its internal 5.5.

Current count controls visibility, not a permanent unlock flag. Deleting the last eligible version of a Dish reduces progress; deleting one of several eligible versions does not. At ten scores reveal; falling below ten relocks every normal numerical surface. The naturally scrolling cream/red Rankings banner returns and reports progress/remaining dishes with singular/plural copy. It does not sit in the pinned header. Search/filter selections never alter the eligibility count.

Audited surfaces: Rankings rows and combined navigation accessibility labels; common ScoreBadge; Dish Detail header and each version row; completion score, raster preview and VoiceOver label; individual ShareCardModel/ShareCardView/renderer; Detail and completion share actions; retained legacy RankingView; InitialReaction/comparison copy; Profile/account/navigation; isolated Debug visual fixtures. Before unlock, small lock indicators replace score badges, no numerical individual preview is produced, sharing is restrained explanatory text rather than a second scoreless card, and the renderer rejects a model without an eligible score. Export actions obtain a fresh model, preventing newly rendered stale numerical cards after relocking. Previously shared external images are not recalled.

## First local milestone

The existing before-save completion snapshot now copies the eligible unique Dish count. After a successfully persisted complete session, a first local below-threshold → at/above-threshold crossing presents **Your scores are unlocked!** instead of another popup. It offers the Top 3 preview, Share My Top 3 and Done. Ordinary comparisons and partial re-ranking saves never celebrate; pre-unlock completion still shows **Your dish is ranked!**, building-rankings copy, relative position and a lock.

The one-time receipt is a local UserDefaults Boolean under an account-ID namespace, separate from the cooking schema, sync graph, outbox, migrations and photo files. Account switching/sign-out retain independent markers. Debug namespaces use the explicit isolated store UUID (or the existing demo namespace), never a real account. No marker is written merely because an existing demo or restored library has ten dishes. Returning from nine to ten reveals scores without replay on an installation whose marker was already presented.

**Multi-device semantics:** this is the first local presentation per account on this installation, not a globally synchronized account-history flag. Passive cloud hydration/startup with an already-unlocked graph does not celebrate or consume a marker. A different installation with no marker can celebrate its own first locally completed crossing. An app backup may preserve preferences; a fresh installation without those preferences resets them. Exact account-wide once-only delivery across installations would require synchronized presentation history and is outside this local V1 implementation. Fresh-restore scratch checks do not mount milestone UI, write preferences or create sync work.

`PrivacyInfo.xcprivacy` declares own-app UserDefaults reason `CA92.1` for the new local receipt, per [Apple's required-reason API documentation](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype). This does not add tracking, cross-app preferences, cloud configuration or an upfront permission flow.

## Top 3 card

`TopThreeShareCardModel` uses the actual first three eligible ranked entries; it does not deduplicate by Dish. Two versions can occupy two rows and carry the existing optional subtitle. The fixed **1080 × 1350** composition uses the official PNG, cream/red/charcoal, the requested heading, modest #1/#2/#3 labels, square local photos, prominent titles/subtitles, one-decimal scores and one SCORES UNLOCKED pill. All rows without safely usable local bytes use the same established plate/fork outline.

Both card types use ShareCardRenderer's bounded JPEG lookup and shared exact-size ImageRenderer routine, the same rendered-image container and UIImage-only native share sheet. No screenshot, private account metadata, Source/tags/notes, deep link, network fetch, new cloud endpoint or historical gallery is added. Restored local files naturally use the same path; file-restoration notifications refresh previews. Individual cards and existing achievements resume unchanged after unlock and suppress numerical output again if current eligibility falls below ten.

## Verification

Final complete Debug run **PASSED** on iPhone 17 / iOS 26.5:

| Verification | Test functions | Executions | Failures / expected failures / skips |
| --- | ---: | ---: | --- |
| Unit/integration | 190 | 261 | 0 / 0 / 0 |
| UI | 25 | 26 | 0 / 0 / 0 |
| Complete Debug | **215** | **287** | **0 / 0 / 0** |
| Actual Release authentication/isolation gate | 1 | 1 | 0 / 0 / 0 |

Final result: `/private/tmp/staygrubby-score-unlock-full-final.xcresult`; aggregate `/private/tmp/staygrubby-score-unlock-full-final-summary.json`. The full suite ran to completion after the diagnosed test-navigation fix; no tests were removed or skipped. Debug build/run succeeded again after the full suite (16.3 seconds); normal onboarding was visibly intact. A subsequent unseeded development-library launch showed the original naturally unlocked rankings with normal sizing, no progress banner and no retrospective milestone. Release build and Release build-for-testing succeeded; the actual binary excludes the development-library, review fixture, score-fixture arguments/types and fresh-restore Debug entry point. `com.guyrettig.StayGrubby`, automatic team signing, Apple entitlement, iPhone upright-portrait-only configuration and approved client configuration remain intact. The own-preferences privacy manifest is present in Release.

Visual/accessibility checks passed at 0, 1, 9, 10 and 12 unique Dishes, with extra ranked versions in isolated fixtures. Light/dark, large text, Reduce Motion, scrolling banner, locked Detail/version rows/completion and no numerical accessibility/preview/share leakage passed. First crossing, native image-only Top 3 sheet, relaunch, deletion to nine, relaunch and return to ten without replay all passed in the complete run. Large-type milestone Share/Done stay reachable while the content scrolls. Actual raster exports were inspected: Top 3 mixed local-photo and all-fallback cards both **1080 × 1350**; existing individual photo cards **1080 × 1350** and fallback cards **1080 × 1080**. Long titles/subtitles fit; the official supplied PNG is sharp, score typography remains modest and the universal plate/fork fallback is consistent. Review exports: `/private/tmp/staygrubby-score-unlock-export-review/` (test artifacts only).

Preservation checks after the complete run and normal development launch passed: **1 ranking / 12 Dishes / 15 attempts and items / 356 comparisons / 10 Sources / 21 tags / 48 memberships / 190 media files**. The complete semantic/media SHA-256 manifest and SQLite model metadata match the original backup; SQLite integrity is `ok`, scores/evidence/UUIDs/relationships are preserved, and the development store has no sync operations, account bindings, tombstones or photo-transfer journal. No fixture media leaked into the normal library. All **149** frozen source/assets stayed byte-identical through the final suite and launches; **50** protected ranking/domain/auth/sync/config/identity files match the starting working tree or HEAD. The authentication root differs from its starting version only by two presentation-scope environment lines; existing backend/photo-sync source and tests are unchanged.

Credential scan covered **175 nonignored files / 171 text files**, with **zero privileged-secret findings**. The intended client plist still contains only the approved project reference/URL/publishable key. Local backups, dependencies, local Supabase state and local secrets remain ignored. `git diff --check` and `git diff --cached --check` both pass. Main HEAD remains `a4b61eb177db055723ed07319e1c0655afbb8bca`; **34 tracked modifications + 36 new files = 70**, nothing staged, nothing committed/pushed. The complete inventory follows below.

Verification history: initial focused model/render recovery passed 36 functions / 57 executions; final policy/render plus milestone lifecycle recovery passed 18 functions / 32 executions (including the complete native Top 3, relaunch, deletion/relock and return-without-repeat UI flow); the initial new-test fixture incorrectly released its ModelContainer, causing test-model invalidation. The test fixture now explicitly retains it; production ownership/persistence was unchanged. The eligibility and privacy-manifest cases passed. One initial milestone UI assertion failed because its Delete confirmation remained open after a synthesized tap; the recorded hierarchy proved the missed action. The helper now confirms dismissal with a bounded retry. The first complete Debug run passed 214 of 215 functions (286 of 287 executions); the sole failure was another synthesized tap miss while opening New Dish. Its hierarchy retained the creation menu and New Dish button, with no form or app crash. The new helper now requires the form destination and permits one retry only while the original creation control remains available, matching the existing cooking-workflow approach. A complete rerun is required below; no assertions or production code were changed for either UI tap issue. All behavioral/layout/persistence assertions remain required.

The local backend regression rerun passed 171 assertions (69 schema/RLS, 60 structured, 42 photo). The preceding 124 native PostgreSQL/locking/concurrency assertions remain valid because backend/migrations/transports are unchanged. No expensive hosted write fixtures were repeated. Fresh hosted counts before verification confirmed zero active cooking records/media and zero Storage objects, with valid retired history retained. Fresh hosted migration checks match **8/8** local MD5 hashes; `Backend/schema.sql` is still the exact ordered migration concatenation. All **16/16** private tables retain RLS, with **zero anon application-table grants**. Latest final read-only hosted state: **1 Auth user / 1 account / 1 active global ranking; 0 active Dishes, attempts, items, comparisons and media; 0 Storage objects**. Required history remains **5 retired Dishes/attempts/items/media records, 5 cleaned backup manifests, 14 sync receipts and revision 15**; no uncleaned manifests. Active snapshot selection excludes every retired record, so the previously deleted photo-test data cannot reappear through a valid restore. No hosted fixtures, users, authorization, uploads or manual purges were performed by this task.

The existing security advisor notices remain: deliberate RLS-with-no-client-policy on `auth_account_links` ([advisor explanation](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)); leaked-password protection disabled for the already Apple-only/disabled-password-provider product ([advisor explanation](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)). There is no new security regression. The unchanged Supabase Swift SDK also emits its existing initial-session-ordering notice; account/authentication behavior was not altered for this presentation feature.

Remaining gates/limitations: the new score-unlock and Top 3 experience still needs physical-iPhone/product approval; the receipt is local per account/per installation, not synchronized account-wide history. Existing cold-launch/loading and in-flow replacement-sync feedback remain future polish. No new automatic conflict behavior, historical card gallery, advanced statistics, social functionality or photo-sync redesign was introduced.

## Short physical approval checklist

1. Build normally on the iPhone; use the existing real account, initially at zero. Create a dish and confirm the scrolling progress banner, locked rows/Detail/versions/completion, relative ranks and unavailable individual numerical sharing. Check VoiceOver and large text for score leakage.
2. Build toward nine unique Dishes, adding extra versions to prove they count once. Add the tenth unique Dish: all scores reveal, banner disappears, and the one-time milestone offers the correctly ordered Top 3. Inspect mixed photo/fallback rows, subtitles, sharp official branding and native image-only sharing; re-share an individual dish from Detail.
3. Relaunch; delete the only eligible cook of one Dish to return to nine. Confirm scores/sharing hide and the banner returns. Add a new tenth Dish: scores reveal without repeating the milestone. Deleting one of several versions should keep that Dish counted.
4. Confirm normal sync/fresh restore retains the cooking graph and current visibility. Finish final visual/product approval before requesting any commit. The already-passed photo lifecycle need not be recreated just for this score feature; any newly created real test data should be deleted through the normal UI when finished.

## Working-tree inventory

The complete combined checkpoint currently contains **70 files: 34 tracked modifications and 36 new files**, with nothing staged. The starting 59-file uncommitted photo/branding/share work remains present. Score-gate work also modifies existing share/navigation/test/documentation files; the inventory below is the complete combined working tree, not only this feature.

- `ACCOUNT_ARCHITECTURE.md`
- `Backend/README.md`
- `Backend/schema.sql`
- `Backend/tests/package.json`
- `Backend/tests/photo-security.test.mjs`
- `Backend/tests/provisioning.concurrent.mjs`
- `Backend/tests/schema.test.mjs`
- `Backend/tests/storage-stub.mjs`
- `Backend/tests/structured-sync.test.mjs`
- `DevelopmentTools/Branding/generate_brand_icons.py`
- `MEDIA_SYNC_ARCHITECTURE.md`
- `PHASE_3D_PHOTO_SYNC_REVIEW.md`
- `SCORE_UNLOCK_REVIEW.md`
- `STAYGRUBBY_MASTER_ROADMAP.md`
- `SYNC_ARCHITECTURE.md`
- `StayGrubby.xcodeproj/project.pbxproj`
- `StayGrubby/Accounts/AccountApplicationRoot.swift`
- `StayGrubby/Accounts/AccountSessionCoordinator.swift`
- `StayGrubby/Accounts/AccountView.swift`
- `StayGrubby/Accounts/DevelopmentLibraryAccess.swift`
- `StayGrubby/Assets.xcassets/AppIcon.appiconset/AppIcon-Dark.png`
- `StayGrubby/Assets.xcassets/AppIcon.appiconset/AppIcon-Light.png`
- `StayGrubby/Assets.xcassets/AppIcon.appiconset/AppIcon-Tinted.png`
- `StayGrubby/Assets.xcassets/AppIcon.appiconset/Contents.json`
- `StayGrubby/Assets.xcassets/StayGrubbyWordmark.imageset/Contents.json`
- `StayGrubby/Assets.xcassets/StayGrubbyWordmark.imageset/StayGrubbyWordmark.png`
- `StayGrubby/DebugReviewConfiguration.swift`
- `StayGrubby/DesignSystem/StayGrubbyComponents.swift`
- `StayGrubby/DesignSystem/StayGrubbyTheme.swift`
- `StayGrubby/PrivacyInfo.xcprivacy`
- `StayGrubby/Sharing/DishShareAction.swift`
- `StayGrubby/Sharing/NativeDishShareSheet.swift`
- `StayGrubby/Sharing/ScoreUnlockPolicy.swift`
- `StayGrubby/Sharing/ScoreUnlockReviewFixture.swift`
- `StayGrubby/Sharing/ShareCardModel.swift`
- `StayGrubby/Sharing/ShareCardRenderer.swift`
- `StayGrubby/Sharing/ShareCardView.swift`
- `StayGrubby/Sharing/SharingReviewFixture.swift`
- `StayGrubby/Sharing/TopThreeShareCard.swift`
- `StayGrubby/Sync/CookingPhotoJournal.swift`
- `StayGrubby/Sync/CookingPhotoManifest.swift`
- `StayGrubby/Sync/CookingPhotoSync.swift`
- `StayGrubby/Sync/CookingSyncCoordinator.swift`
- `StayGrubby/Sync/FreshCookingRestoreCheck.swift`
- `StayGrubby/Sync/SupabaseCookingPhotoTransport.swift`
- `StayGrubby/Views/Cooking/AddCookingView.swift`
- `StayGrubby/Views/Cooking/AttemptDetailView.swift`
- `StayGrubby/Views/Cooking/CookingRankingResultView.swift`
- `StayGrubby/Views/Cooking/CookingRankingView.swift`
- `StayGrubby/Views/Cooking/ReRankView.swift`
- `StayGrubby/Views/HomeView.swift`
- `StayGrubby/Views/RankingView.swift`
- `StayGrubbyTests/AppConfigurationTests.swift`
- `StayGrubbyTests/CookingPhotoSyncTests.swift`
- `StayGrubbyTests/DebugReviewIsolationTests.swift`
- `StayGrubbyTests/ScoreUnlockPolicyTests.swift`
- `StayGrubbyTests/ShareCardModelTests.swift`
- `StayGrubbyTests/ShareCardRendererTests.swift`
- `StayGrubbyTests/TopThreeShareCardTests.swift`
- `StayGrubbyUITests/CookingUITests.swift`
- `StayGrubbyUITests/DishSourceUITests.swift`
- `StayGrubbyUITests/PolishUITests.swift`
- `StayGrubbyUITests/ReleaseAuthenticationGateUITests.swift`
- `StayGrubbyUITests/ScoreUnlockUITests.swift`
- `StayGrubbyUITests/SharingUITests.swift`
- `StayGrubbyUITests/StayGrubbyUITests.swift`
- `UI_ARCHITECTURE.md`
- `V1_BRANDING_SHARING_REVIEW.md`
- `V1_SHARING_ARCHITECTURE.md`
- `supabase/migrations/20261013043630_private_cooking_photo_backup.sql`
