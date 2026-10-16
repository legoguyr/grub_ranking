# StayGrubby V1 presentation integration

October 15, 2026. One primary agent in the original checkout on main. This review supersedes the temporary independent-worker workflow, not the approved V1 behavior or its physical-test history.

## Starting point and integration

Main started clean at `97b1bc3b0f041cc2bbf38b19bde1b1354f7c9953`. All three worker checkouts were clean, and each completed commit had that exact parent:

| Area | Branch | Preserved commit |
| --- | --- | --- |
| Onboarding | feature/onboarding | `4d6b60d02bc24ef36efeb3a6687864e1ff0cba84` |
| Profile | feature/profile | `778615ab6a9f5f57f6e141e6b1b0ed57b5761cb0` |
| Sharing | feature/sharing | `79792a6e7fe9d50d6b196b7e507f5cbc998ba57e` |

The complete diffs were inspected before `git merge --no-ff --no-commit feature/onboarding feature/profile feature/sharing`. Their changed files do not overlap; the merge applied without textual conflicts. The merge was deliberately left uncommitted during combined tests, visual review and final audit. The integration checkpoint preserves worker history and adds only integration tests/documentation beyond their changes. No branch/worktree is deleted.

## Combined application and protected contracts

- AccountApplicationRoot is still the authority: native Apple → Supabase → permanent account → exact account store ready → Rankings/Profile. Presentation copy cannot grant access. Sign-out closes personal access. New accounts start empty.
- ProfileSnapshot reads actual eligible global entries and separately ranked versions, independent of Top Version / All Versions display. No invented food, date, score or account data. Locked scores stay absent from food accessibility and exported models.
- Profile's permanent Top 3 uses the same current model, local renderer and native sheet as the results/milestone flows. Its new placement does not change eligibility. Account/sync disclosure retains retry, safe restore and sign-out behavior.
- Saved creation/re-ranking results retain identities/evidence, automatic finalization and score-count rules. Private rank/movement remains separate from image-only exports.
- Shared sheet feedback distinguishes actual Save Image success, save/share error and quiet cancellation. Preview retry does not save or rank again.
- NEW #1 and Updated Top 3 retain conservative event/evidence checks. Normal Top 3 omits SCORES UNLOCKED; genuine first-unlock uses milestone mode. Fixed dimensions, fallback artwork and official-red export scores are unchanged.
- Ranking engine/domain/persistence, score unlock policy/receipts, auth services/root, structured/photo sync, schema/migrations, SDK pins, release identity, theme/assets and renderer/model are byte-identical to the base. The Top 3 model/export-view prefix is also unchanged; only its in-app milestone presentation changed.
- No future social/recipe/public-sharing implementation or visible Feed was added.

## Verification campaign

All Simulator activity uses **iPhone 17 / iOS 26.5**, `D839186C-3810-4C98-99FA-3C88230212DC`, serially. No extra Simulator or worker was created. Build concurrency is limited to two jobs; UI tests use `-parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1`. Dedicated DerivedData is `/private/tmp/staygrubby-integrated-debug` and `/private/tmp/staygrubby-integrated-release`. Existing pinned package checkouts are reused without SDK changes.

Debug normal build/run and the ordinary optimized Release build passed. Final Debug unit coverage is **224 functions / 327 executions passed**, including the additional gate-rendering XCTest. The complete Debug UI coverage is **45 methods / 46 executions**, all passing after the two test-only corrections below. The final run repeated the full unit suite and **8/8 affected UI methods**, **232 functions / 335 executions**, zero failures, expected failures or skips. The initial full run and final affected run are retained separately rather than concealing the initial failures.

Results: `/private/tmp/staygrubby-integrated-debug-full.xcresult` (initial complete campaign), `/private/tmp/staygrubby-integrated-debug-final.xcresult` (final unit/affected UI), `/private/tmp/staygrubby-integration-effective-debug.json` (final coverage reconciliation).

The ordinary Release app's actual executable/resource audit found **zero of 12 development/fixture markers**, with **all 12 present in Debug as positive controls**, and no privileged credential match. This includes the new Profile/account mock, sharing fault reviews, development-library and fresh-restore controls. Its Info.plist retains `com.guyrettig.StayGrubby`, version **1.0 / 1**, device family **[1]**, upright portrait, iOS **26.5** minimum and exempt-encryption Boolean false. Audit: `/private/tmp/staygrubby-integrated-release-isolation.json`. The ordinary production-configured Simulator app was preserved before testability was enabled for test compilation; it is not an archive/export or new distributed build. Optimized Release UI: **7 methods / 7 executions passed**, zero failures, expected failures or skips, covering all four onboarding cases and the authentication/Profile/Sharing isolation gates. Result: `/private/tmp/staygrubby-integrated-release-gates.xcresult`. Actual Release onboarding was reviewed in light appearance at normal and maximum text, including the fully visible native Apple label/button; no development entry is present. Original dark system appearance and normal `large` text were restored. The integrated Debug app was reinstalled without resetting its data and normal no-argument onboarding was inspected again at ordinary sizing.

Release tests use command-line `ENABLE_TESTABILITY=YES` solely to compile existing @testable tests, with no DEBUG definition or shipping-setting change.

One integration-only unit rendering test captures synthetic pending-session, retry, account-resolved/library-pending, library-error and signed-out presentation. It verifies rendering does not advance account/store access and uses no Apple request, live transport or account database. Existing UI tests exercise real cross-screen flows; no auth shortcut is added to shipping code.

The backend harness passed **171 assertions**: 69 schema/RLS, 60 structured sync, 42 photo manifest/Storage security, using disposable PGlite only. Fresh read-only hosted catalog inspection found eight exact migration MD5 matches, all 16 private tables with RLS, zero anonymous application-table grants and four Storage policies on the private JPEG-only 2 MiB bucket. No hosted data, Auth configuration or schema was changed. Advisors remain the intentional inaccessible Auth-link/no-policy INFO and disabled password-protection WARN for the unused password provider; see [mapping notice](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) and [password-security notice](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). No new advisory was introduced by this presentation integration.

## Combined failures and test-only reconciliation

The initial complete Debug run executed **223 unit functions / 326 executions** and **45 UI methods / 46 executions**. Unit tests all passed. Two UI methods failed, with no skips/expected failures:

- CookingDiscovery large-text test: the recording shows the Dietary sheet stayed open after a missed synthesized Done tap. The helper incorrectly accepted an existing ranking control behind the sheet as proof of dismissal. It now requires the sheet to disappear, with a bounded same-control retry; every actual filter/result assertion remains.
- ReviewEnvironment bare-flags test: the old assertion compared a scalable ranking header with the new fixed 100-point logo. It now measures scalable onboarding copy and compares the same ranking header at normal/accessibility sizes, retaining fresh-launch/bare-flag isolation checks.

No product change was needed for either failure. All affected classes and the strengthened re-rank/version-unlock → Profile transitions are rerun alongside the complete final unit suite. The transition assertions verify re-ranking does not increment Profile entries and a new independently ranked version unlocks Profile without adding a Dish. No test was skipped, marked expected-failure or stripped of a semantic/privacy check.

## Combined visual review

Inspected current-run screenshots for dark onboarding at normal/moderate/maximum text; Profile empty/one/two entries, unlocked real Top 3 with fixture photo, missing photos, locked accessibility rows, account/sync disclosure and restore/retry/sign-out controls in light/dark; locked and unlocked results, photo/fallback/long cards, achievements, milestone Top 3, genuine new leader/Updated Top 3, native sharing, preview failure/recovery and save-error feedback. Cards retain official red while native scores use semantic colors; private rank/movement stays outside the exported image. Large content scrolls while controls remain reachable. Controlled solid-color test photos are fixtures, not lost real photos.

Current integrated screenshots/index/contact sheets are under `/private/tmp/staygrubby-integrated-attachments`, `/private/tmp/staygrubby-integration-visual-index.json` and `/private/tmp/staygrubby-integrated-visual-1.png` through `-6.png`. These temporary review artifacts are not application assets or Git content. The five synthetic gate-state renderings and version-unlock → Profile screenshot were also inspected in `/private/tmp/staygrubby-integrated-visual-7.png`; light/dark pending/retry/library-failure/signed-out presentation is readable and stays gated. Release-light runtime screenshots were also inspected in `/private/tmp/staygrubby-integrated-release-attachments`; the native Apple control is readable and fully reachable even at maximum text. Normal Debug relaunch returned to ordinary sizing. No spoken VoiceOver or physical-device approval is claimed.

## Data and repository preservation

Before testing, the complete original Simulator demo semantic/media manifest exactly matched `.local-backups/auth-gate-part2b/before-manifest.json`: **1 ranking, 12 Dishes, 15 attempts/items, 356 comparisons, 10 Sources, 21 tags / 48 memberships, zero sync operations/bindings/tombstones and 190 retained media files**. Its SQLite graph has no CookingMedia rows; the retained files are preserved rather than adopted or deleted. Final comparison after all launches confirms original identities, fields, relationships, scores/evidence, SQLite metadata and media are exactly unchanged. SQLite integrity passes. No reset, seeding or real-account operation occurred.

Manifest SHA-256: `bedd790ea8487f3b1baad442acd9092a6890b0a38cede4951aef0018469b9a51`.

The local safety script is `/private/tmp/staygrubby-integration-audit.py`; aggregate results are `/private/tmp/staygrubby-integration-safety.json`. It checks protected sources, full demo manifest, privileged-secret patterns, approved public client fields, local-only exclusions, eight migration hashes, schema concatenation and both whitespace checks. No local backups, dependencies, generated products, secrets or fixture media are intended for Git.

## Documentation and release status

The canonical [Master Roadmap](STAYGRUBBY_MASTER_ROADMAP.md) now separates private cooking, recipe discovery/Want to Cook, and social publication. It records actual implemented accounts/cloud infrastructure and the future dependency order, attribution, independent ranking, backend privacy, moderation, notifications-before-push and no native display advertising. Future features are planning only.

[PARALLEL_DEVELOPMENT.md](PARALLEL_DEVELOPMENT.md) retires parallel work as the default and retains worker history/checkouts for later cleanup. Account/UI/sharing docs describe integrated presentation without changing their service contracts.

User confirms **1.0 (1) archived, validated and uploaded TestFlight Internal Only**. That uploaded build predates this integration. The readiness document now labels the earlier signing audit as historical rather than an outstanding upload task. Version/build are unchanged; no new archive, upload, tester change or submission is performed here. Coordinated account deletion/privacy policy remain separate external/public-release requirements.

## Physical-iPhone review — still required

Do not treat automated/Simulator verification as physical approval of this build. Use existing data without reset:

1. Check combined onboarding/restoration and native Apple entry; sign-out returns to onboarding.
2. Inspect Profile counts/Top 3, account/sync disclosure and reachable controls.
3. Complete a normal re-rank, inspect the result, share its image, and return to Profile.
4. Check native Save Image feedback/cancellation and reusable Top 3; confirm normal Top 3 has no unlock footer.
5. Briefly check light/dark and preferred larger text/touch behavior; report clipping or unreachable actions.

Do not deliberately delete/reinstall or erase the real account for this presentation review. After physical approval, decide separately whether a new TestFlight build is warranted.

## Exact file inventory

The combined checkpoint changes **34 paths** relative to starting main: all **23 worker paths** are preserved byte-for-byte from their corresponding commits, plus these **11 integration-only test/documentation paths**. No additional application implementation was modified during reconciliation.

- `ACCOUNT_ARCHITECTURE.md`
- `PARALLEL_DEVELOPMENT.md`
- `STAYGRUBBY_MASTER_ROADMAP.md`
- `StayGrubbyTests/IntegratedGatePresentationTests.swift`
- `StayGrubbyUITests/CookingDiscoveryUITests.swift`
- `StayGrubbyUITests/ReviewEnvironmentUITests.swift`
- `StayGrubbyUITests/V1RevisionUITests.swift`
- `TESTFLIGHT_READINESS_REVIEW.md`
- `UI_ARCHITECTURE.md`
- `V1_INTEGRATION_REVIEW.md`
- `V1_SHARING_ARCHITECTURE.md`

Worker paths preserved:

- `ONBOARDING_VERIFICATION.md`
- `SHARING_WORKER_HANDOFF.md`
- `StayGrubby/Accounts/AccountView.swift`
- `StayGrubby/Accounts/AuthenticationGatePresentation.swift`
- `StayGrubby/Accounts/AuthenticationGateView.swift`
- `StayGrubby/Accounts/ProfileAccountReview.swift`
- `StayGrubby/Accounts/ProfileContent.swift`
- `StayGrubby/Accounts/ProfileSnapshot.swift`
- `StayGrubby/Sharing/DishShareAction.swift`
- `StayGrubby/Sharing/NativeDishShareSheet.swift`
- `StayGrubby/Sharing/ShareCardFeedback.swift`
- `StayGrubby/Sharing/SharingPresentation.swift`
- `StayGrubby/Sharing/SharingReviewFixture.swift`
- `StayGrubby/Sharing/TopThreeShareAction.swift`
- `StayGrubby/Sharing/TopThreeShareCard.swift`
- `StayGrubby/Views/Cooking/CookingRankingResultView.swift`
- `StayGrubbyTests/OnboardingPresentationTests.swift`
- `StayGrubbyTests/ProfilePresentationTests.swift`
- `StayGrubbyTests/SharingPresentationTests.swift`
- `StayGrubbyUITests/OnboardingUITests.swift`
- `StayGrubbyUITests/ProfileUITests.swift`
- `StayGrubbyUITests/SharingPresentationUITests.swift`
- `StayGrubbyUITests/SharingReleaseIsolationUITests.swift`

## Final repository gate

All requested combined verification is complete. The final protected-source, demo graph/media/SQLite metadata, migration/schema and whitespace audit **passed**. Privileged-secret scanning found **zero findings in 202 nonignored files (198 text files)**; client configuration stays public-only and local-artifact exclusions passed. No generated products or local data are included. Worker branches/worktrees remain intact; ancestry and their clean statuses are checked after the merge commit before reporting them eligible for later cleanup. No new archive, upload or distribution is part of this checkpoint.
