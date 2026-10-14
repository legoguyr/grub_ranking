# StayGrubby — final Core App V1 revisions

The complete combined working tree remains uncommitted on main at `a4b61eb177db055723ed07319e1c0655afbb8bca`. All 70 starting changed/new files remain present. No reset, revert, stash, commit, push, hosted write, real authorization, cloud upload or active/retired-data purge is part of this task.

## Physical approval history and this revision

The user passed photo upload → fresh restore → replacement → replacement restore → deletion → zero restore/no resurrection. Individual and Top 3 card rendering looked good physically, and numerical unlock/lock/general usage were exercised. Those facts remain passed. On October 14, 2026 the user also confirmed these final V1 revisions passed all six physical-iPhone checklist sections using existing data without resetting: Re-rank, score unlocking, version display, sharing, achievements, persistence and locked-score protection. The subsequent pre-alpha pass is restricted to semantic in-app score colors and the two Detail action icons; it does not redesign exports or rewrite photo sync.

## Re-rank cause and lifecycle

The prior `ReRankView` immediately initialized the separate `ReRankingSession`, which acquires refinement pairs from old plus draft evidence rather than starting with a reaction. It had no automatic completion task; its only persistence path was the toolbar **Save Answers** button (the physical report called this Save Score). Thus the missing reaction and manual save were architectural, not a hidden button or numerical-score defect.

The revised view owns `CookingReRankingWorkflow`: normal `InitialReactionView` (Liked it / It was fine / Didn’t like it) → unchanged `RankingEngine` using the existing item UUID and current order excluding self → same `ComparisonView`, Too Tough/Skip/Undo and stopping policy → automatic atomic `CookingStore.rerank` → existing `RankingStore.record` append/global fit/journal/save → ordinary result/Done. There is no ordinary Save Score/Save Answers step. Retry/Cancel remains only on a genuine save error. Remote reconciliation uses the existing navigation lease.

The initial reaction is the same acquisition prior as new ranking; it does not fabricate a Bradley–Terry observation or manually set a score. Only actual answered pairwise observations enter comparison history; skips do not. No Dish, CookingAttempt, RankedItem or version is created. Prior observations/IDs/timestamps survive, fresh observations are added, repeated/contradictory evidence remains legal, and re-ranking never increments the unlock count. Cancel before completion drops only the draft value-type session. Generic RankingEngine/BT/RankingStore/RankingList and persistence/sync code are unchanged; the old refinement helper remains available for future distinct refinement work.

## Entry-based score gate and discrepancy finding

`ScoreUnlockPolicy.requiredRankedEntryCount = 10` is the single threshold. Count distinct saved active eligible ranked-entry IDs in the accepted canonical global ranking, including independent versions. Continue excluding unsaved/draft, unranked/historical, pending-deleted/tombstoned/invalid bridges and unaccepted restoration state. The same current count gates badges, completion, individual/Top 3 factories/actions/rendering and accessibility. Current eligibility drives relock after deletion, independent of the local one-time receipt.

The physical discrepancy was verified from read-only hosted relationships: **12 active attempts + 12 active RankedItems across 10 active Dishes**, including two Dishes with a second active version. All twelve active attempts have active Dish/item/canonical-global-ranking bridges; **zero ineligible active attempts**. The previous unique-Dish counter therefore returned ten for those twelve ranked entries. The finding is supported by the actual saved graph, not a guess about drafts or missing versions. The correction counts twelve. No real data is modified to correct the presentation.

Copy uses **dishes & versions ranked** and **Rank N more dish(es) or version(s)**. The receipt key/semantics stay local per account/per installation: first locally completed below-ten → ten crossing only, no relaunch/hydration replay, no repeated celebration after relock. No backend schema/history marker is added. The existing own-UserDefaults privacy reason also covers the local display preference.

## Red and display modes

`SGTheme.ColorToken.accent` supplies readable red light/dark variants; filled buttons use a deeper red with white-text contrast. The AccentColor asset is red as well. Identity/export `Brand.red` and the supplied PNG are unchanged. The unlock ProgressView uses explicit red Capsule fill and neutral track, avoiding the system monochrome dark-mode style. Native Apple/share-sheet semantic appearances and blue test-photo pixels are not mechanically recolored.

Top Version is default; All Versions shows all eligible entries. Search/filter matching comes first; grouping then picks the highest globally ranked matching version of each Dish. This allows a lower sibling to be found when its higher version does not match a search/filter. Global rank numbers retain gaps; no averaging, score merging, evidence/order changes or count reduction occurs. The local display preference survives relaunch; Debug fixtures have isolated preference suites.

Detail has one balanced same-height/same-radius Edit Cook / Re-rank / Share row at ordinary sizes, with a readable accessibility stack. Share remains locked before ten. Removing a container-level accessibility identifier preserves the child action identifiers and labels.

## Sharing distinctions

Normal current Top 3 is permanently available from Profile once unlocked. `TopThreeShareAction` uses the existing factory, renderer/local bounded JPEG read/fallback and UIImage-only native sheet. It refreshes content/eligibility at export. The top three remain independently ranked entries, including two versions of the same Dish if applicable.

`TopThreeShareCardModel.isUnlockMilestone` defaults false; normal Profile/Updated Top 3 exports omit SCORES UNLOCKED. Only the actual first-unlock view explicitly enables that pill. The approved logo/three rows/photos/titles/subtitles/red scores/cream composition and 1080 × 1350 dimensions are retained. Footer space is blank in normal mode; no new card theme is invented.

The existing conservative NEW #1 detection requires actual before/after leader movement and fresh supporting evidence, not score alone. It works after creation and fresh Re-rank. Individual result/card/share remains primary; a genuine new leader adds one optional Share Updated Top 3 action using the normal, non-milestone card. Current #1 staying #1 or moving downward does not qualify. First threshold-unlock precedence still produces a single milestone, without forced extra sheets or celebrations. Individual achievements otherwise remain unchanged.

## Verification

FINAL AUTOMATED VERIFICATION PASSED on 2026-10-14. Focused model tests passed 26 functions in four suites, including all three reactions at 1/2/9/10/30 entries, cancellation/Skip/tie/Undo, repeated promotion/demotion, stable IDs/counts, preserved evidence, exact existing global fitting, disk reload and isolated journal dispatch/acknowledgment. Floating-point comparisons use 1e-12 precision; restored test stores explicitly enable the same sync journal as the actual worker before asserting queued work. No production math/sync change was made for these test setup corrections.

The first focused UI run found a container identifier overriding its child action identifiers; the unnecessary identifier was removed, retaining all action assertions. Existing all-version discovery/workflow tests explicitly select All Versions, preserving their original assertions; dedicated coverage verifies the new default/grouping semantics. A normal one-opponent Too Tough now completes automatically, so Undo is exercised before terminal completion in the dedicated multi-opponent case instead of requiring an obsolete post-completion save screen.

The first complete run executed **229 functions / 315 executions**: all **199 unit functions / 284 executions** and **26 of 30 UI functions** passed, with four outdated legacy expectations failing. Two attempted lower versions hidden by the new default Top Version; another expected comparison-first Re-rank and its removed refinement footer. Those tests now explicitly confirm All Versions and the normal reaction/automatic result, retaining their underlying version/layout/Skip/Undo/Too Tough/locked-score assertions. The focused legacy recovery passed **5/5** UI tests. All five new V1 revision UI cases also passed, as did the revised score-lock lifecycle. The first individual-share tap miss retained the result button with no sheet or render alert; the test now permits one guarded retry and still requires the actual native Copy/Close UI. The new dietary-selection case confirms the actual Selected state before dismissing its sheet. Production code did not change for these final harness updates. The final full run then passed every case; no meaningful assertion was removed to obtain that result.

| Final verification | Result |
| --- | --- |
| Complete Debug suite, iPhone 17 / iOS 26.5 | **199 unit functions / 284 executions + 30 UI functions / 31 executions = 229 functions / 315 executions; zero failures, expected failures or skips** |
| Focused Re-rank adapter | 5 functions / 19 executions, passed within the complete suite |
| New display/export/accent tests | 4 functions / 4 executions, passed within the complete suite |
| New V1 revision UI suite | 5 / 5 passed within the complete suite |
| Release authentication gate | 1 / 1 passed; zero failures/skips |
| Debug ordinary build/run | Passed; final build/run 13.4 seconds |
| Release build and Release test build | BUILD SUCCEEDED and TEST BUILD SUCCEEDED |
| Backend regression rerun | **171 assertions passed**: 69 schema/RLS, 60 structured sync, 42 photo security; isolated local databases only |
| Source/asset freeze | All 155 application/test/asset hashes unchanged during and after the final complete run |
| Protected architecture | 51 protected files verified unchanged; account view adds only sharing presentation; authentication root, existing photo sync/backend/tests unchanged |
| Git whitespace | `git diff --check` and `git diff --cached --check` passed |
| Privileged secrets | Zero findings across 182 nonignored files (178 text files); approved public-only client configuration unchanged |

The previous 124 native backend assertions remain historical evidence for the unchanged backend; they are not added to the fresh 171-assertion total. Existing Supabase SDK initial-session-ordering diagnostic is unchanged and is not a test failure.

Result bundles: `/private/tmp/staygrubby-v1-revisions-full-final.xcresult` and `/private/tmp/staygrubby-v1-revisions-release-gate.xcresult`. Exact full counts are recorded in `/private/tmp/staygrubby-v1-revisions-full-final-summary.json`; exported UI screenshots are in `/private/tmp/staygrubby-v1-revisions-full-final-attachments/`. Final safety evidence is in `/private/tmp/staygrubby-v1-revisions-final-safety.json`. These artifacts are local and are not added to Git.

Visual inspection covered the red dark-mode progress, ordinary same-height Detail row, accessibility action stack, normal reaction, automatic result, truthful NEW #1 individual card and optional Updated Top 3, native Profile sharing, light/dark and large text. Normal Top 3 exports retain 1080 × 1350 dimensions and omit the milestone pill; individual photo and compact fallback exports retain 1080 × 1350 and 1080 × 1080 dimensions. Automated tests cover Reduce Motion, accessibility labels/no locked-score exposure, contrast (white on filled red approximately 5.79:1), scrolling and control semantics. The final no-argument launch showed normal-size onboarding; the normal `--development-library` launch showed the original unlocked demo, Top Version by default and true global rank gaps, with no retrospective milestone or fixture flags.

### Development and hosted integrity

After all tests and both ordinary launches, the preservation checker confirms **1 ranking, 12 demo Dishes, 15 attempts/items, 356 comparisons, 10 Sources, 21 tags, 48 memberships, 190 media files**, exact original semantic/media manifest and model metadata, SQLite integrity, zero sync operations/bindings/tombstones in that guest store, and no fixture/transfer-journal leakage. Semantic/media manifest SHA-256: `bedd790ea8487f3b1baad442acd9092a6890b0a38cede4951aef0018469b9a51`. Tests use separate store/media/preference roots. No real demo cook was edited, re-ranked or deleted.

Fresh read-only hosted counts remained equal to the task-start counts:

| Hosted entity | Active | Retired/history | Raw |
| --- | ---: | ---: | ---: |
| Dishes | 10 | 5 | 15 |
| CookingAttempts | 12 | 5 | 17 |
| RankedItems | 12 | 5 | 17 |
| Comparisons | 35 | 1 | 36 |
| Cooking media | 12 | 6 | 18 |

One Auth user/account and one active global ranking remain. Storage has 24 optimized JPEG objects (two variants for each of 12 active media records). Eighteen backup manifests include six cleaned historical manifests; 29 sync receipts and revision 30 remain valid history. These are user-retained records from subsequent physical usage, not a failure of the earlier zero-active cleanup. Nothing was purged or recreated to force raw counts to zero. No hosted mutation, real Apple authorization or photo upload occurred during this revision.

All **8/8 hosted migration hashes** match local migration bytes, and `Backend/schema.sql` equals their ordered concatenation. Backend/schema/migration files are byte-identical to the starting working tree. **16/16 private application tables have RLS, with zero anonymous application grants**. The cooking-photos bucket remains private, JPEG-only and limited to 2 MiB. Existing advisor notices are unchanged: the intentional private auth-account mapping has no client RLS policy (INFO), and leaked-password protection is disabled (WARN; unused email/password provider is already disabled for the Apple-only product). No new backend/security issue was introduced. See the advisor explanations: [RLS enabled with no policy](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) and [password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

Release product inspection confirms canonical bundle ID `com.guyrettig.StayGrubby`, upright iPhone portrait only, bundled own-preferences privacy manifest, and absence of development-library/score-unlock/sharing fixture switches and Debug fixture/fresh-restore types. Signing, Sign in with Apple entitlement, SDK/client configuration and account architecture remain intact. Local backups, dependency artifacts, local Supabase state and secret files remain ignored.

### Uncommitted checkpoint state and limitations

At completion of the final V1 revision run, main and HEAD remained unchanged with **82 changed/new files = 39 tracked modifications + 43 untracked files**, including every one of the 70 starting files; nothing was staged, committed or pushed. Twelve additional paths beyond the starting inventory comprised two presentation helpers, a Top 3 action, three new test files, two brand accent files, three existing UI harness files and this review document. The subsequent confirmed score-color pass adds one focused test file; its current inventory is recorded below and in the final safety JSON. Master Roadmap/UI/sharing review documentation preserves the previous physical approval history.

Physical approval of the final V1 revisions is now passed. The requested three pre-alpha UI corrections must be verified before the final checkpoint/distribution step. The local milestone receipt is intentionally per account/per installation; display grouping is a local preference. Initial reaction remains acquisition guidance rather than a persisted synthetic comparison. Startup/session restoration and transient sync-status feedback remain future polish. No social, public-profile, Discover, recipe expansion, statistics, challenge, commerce or recommendation work was started.

Automatic approval review rejected an optional full-row hosted integrity digest as overly broad private-data serialization. It was not bypassed; aggregate counts and authorized migration/schema/RLS/grant checks are used instead. No hosted record was written or purged.

## Pre-alpha UI correction pass — October 14, 2026

The Edit Cook pencil and New Version plus now use a shared, explicit center-aligned LabelStyle with a Dynamic Type-scaled symbol frame. Only these two labels adopt it; actions, button styles, minimum touch size, navigation, accessible names and cancellation behavior remain unchanged. Passing light/dark screenshots were inspected in `/private/tmp/staygrubby-alpha-icons-final-attachments/`.

Focused UI verification passed **3/3, zero failures/skips**, in `/private/tmp/staygrubby-alpha-icons-final.xcresult`: light/dark Edit/New Version routes and cancellation, normal fresh Re-rank/result/Profile Top 3, and accessibility locked-share/cancellation/version-threshold crossing. An initial test-only 43.99997-point frame rounding failure was corrected with a 0.01-point tolerance; the app still specifies the original 44-point minimum. Debug build/run and Release build passed (`/private/tmp/staygrubby-alpha-ui-release-build.log`). After the tests, the normal development-library launch and original semantic/media manifest verification passed again. Protected ranking/domain/auth/sync/backend files remain unchanged; no hosted action occurred. Final whitespace checks and privileged-secret scan passed; main/HEAD, 82-file inventory and empty staging area remain unchanged.

The user confirmed the final V1 score palette. `SGTheme.ScoreColor` centralizes its bands and light/dark colors:

| Displayed score | In-app meaning | Light ink | Dark ink |
| --- | --- | --- | --- |
| 1.0–4.9 | Muted coral | `#AA4243` | `#F19D96` |
| 5.0–7.5 | Orange | `#A74910` | `#F2A669` |
| 7.6–10.0 | Gold | `#80600F` | `#EAC86B` |

ScoreBadge applies the corresponding ink and 10% matching tint on Rankings, legacy ranking, Detail and version rows. Native numerical result text uses the same color policy. Classification takes the already-formatted visible decimal, so a displayed 7.5 is orange and 7.6 is gold even though the stored score is continuous. No score calculation, transform, value, comparison, unlock rule, re-ranking, achievement, persistence or sync code is changed. Numbers/accessibility labels remain present so color is not the sole source of information. Locked indicators remain unchanged.

All individual/photo/fallback/new-leader and normal/updated/milestone Top 3 cards keep official `SGTheme.Brand.red` for their scores, regardless of band. Their source files, models, rendering, dimensions, typography, photos, backgrounds, badges and native sharing infrastructure are byte-identical to the beginning of this color pass. The result preview remains a raster of that red-branded card; only the separate native result score adopts semantic ink. General buttons, progress and brand accents are unchanged.

Initial palette testing caught light badge contrast below 4.5:1 on the tinted page background. The light shades were deepened rather than weakening the test; final minimum contrast across tested light/dark pages, cards and tinted badges is approximately **4.64:1**. Dark colors are warm readable tones; low scores use muted coral rather than bright warning red. Focused tests confirm 4.9/5.0/7.5/7.6 and all three full ranges, existing visible rounding, lock behavior, actual rendered badge/native-text ink in both appearances, and official-red pixels in photo/fallback/new-leader and both Top 3 modes. Local review exports live in the test runner's temporary `StayGrubbyScoreColorReview` directory, never the real media root, and are copied to `/private/tmp/staygrubby-score-colors-export-review/` for inspection.

Final score-color verification **PASSED**:

| Check | Result |
| --- | --- |
| Complete unit suite | **205 functions / 300 executions passed** |
| New score-color tests within that suite | **6 functions / 16 executions passed** |
| Selected relevant UI regression | **7 / 7 passed**: unlock/relock/no-repeat/native Top 3, all three sharing cases, light/dark Detail actions, fresh Re-rank/native result/Profile sharing, and accessibility locked-score/version crossing |
| Current combined regression | **212 functions / 307 executions; zero failures, expected failures or skips** |
| Final Debug ordinary build/run | Passed, 17.4 seconds; normal onboarding launches |
| Final Release build | BUILD SUCCEEDED; `/private/tmp/staygrubby-score-colors-release-final.log` |
| Release exclusions/identity | No development-library/score/sharing fixture entry points or fixture/fresh-restore types; canonical bundle ID and upright portrait verified |
| Original demo integrity | Same original semantic/media manifest, metadata and SQLite integrity; 1 ranking, 12 Dishes, 15 attempts/items, 356 comparisons, 10 Sources, 21 tags, 48 memberships and 190 media files; no fixture/journal leakage |
| Architecture/sharing preservation | 51 protected files unchanged; all sharing/unlock sources byte-identical to the start of this palette pass |
| Secrets/whitespace | Zero privileged-secret findings; both Git whitespace checks passed |

The MCP response timed out at 300 seconds while Xcode continued its existing run. That run was allowed to finish; its completed bundle `/private/tmp/staygrubby-score-colors-regression.xcresult` confirms the passing totals above. No second run, skipped test or weakened assertion was used to bypass the response timeout. Exact counts are in `/private/tmp/staygrubby-score-colors-summary.json`. Current UI screenshots are in `/private/tmp/staygrubby-score-colors-ui-review/`; inspection confirms gold Detail badges and an orange native 7.5 result alongside its unchanged red 7.5 card preview. The previous complete 30-function UI run remains documented separately; this pass re-ran seven relevant UI functions rather than claiming another complete UI suite.

Current combined Git state is **main**, HEAD `a4b61eb177db055723ed07319e1c0655afbb8bca`, **83 changed/new files (39 tracked modifications + 44 untracked)**, nothing staged, committed or pushed. The palette pass changes only the theme, shared badge, native result score, three relevant documentation files and one new `ScoreColorTests.swift`; every existing file/data record is retained. There are no remaining implementation blockers from this pass. Signing/archive/App Store Connect readiness remains an operational verification step, and upload/distribution still requires user approval.

After verification, the next workflow is a checkpoint of the complete combined change set, confirmation of the StayGrubby App Store Connect record/version/unused build number and distribution signing, then a signed iPhone Release archive and Organizer validation. With explicit upload approval, upload the archive, complete beta information/export-compliance answers, wait for processing and assign the build to an approved tester group. Internal testers must be App Store Connect users; inviting outside testers uses external testing and its review process. See Apple's [upload guide](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/) and [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/).

This pass does not stage, commit, push, increment build/version settings, archive, upload or invite testers. Existing `com.guyrettig.StayGrubby` identity, automatic signing/team, Apple entitlement, upright-portrait configuration and version 1.0/build 1 remain intact. Installed Xcode is 26.6 (17F113). Distribution signing/App Store Connect status and an actual iPhone distribution archive remain operational checks for the next approved step; passing Simulator Release compilation is not reported as completed archive/upload validation.

## Short physical checklist — revisions only (passed before the pre-alpha corrections)

1. Re-rank an existing locked and unlocked entry: normal reaction choices, Skip/Undo/Too Tough, automatic result without Save Score, same version/history after relaunch/sync. Try upward new #1 and current #1 downward; individual share stays primary, Updated Top 3 appears only for a genuine new leader.
2. At nine eligible entries, add another independently ranked version: ten unlocks. Re-rank must not increase the count. Delete back below ten to relock, then return to ten without replaying the original milestone. Check red progress in dark mode and VoiceOver.
3. Switch Top Version / All Versions; check highest matching version, true rank gaps, search/filters and relaunch persistence. Inspect red controls and the Detail action row at normal/large text.
4. Share current Top 3 from Profile and Updated Top 3 from a new-#1 result: current images/versions/order, no SCORES UNLOCKED pill, image-only native sheet. The actual first-unlock card alone retains that pill. Do not recreate the already-approved photo lifecycle solely for this check.
