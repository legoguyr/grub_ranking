# Optional primary Cuisine — architecture and focused verification

October 20, 2026. Started clean on `main` at `15323eb49ded512ac1df6452ab3ffe291bd4381e`, equal to `origin/main` (0 ahead / 0 behind), remote `https://github.com/legoguyr/StayGrubby.git`. Inspection found no existing Cuisine model, column, tag kind, payload, picker, filter or fixture classification. A share-card comment mentioning cuisine-specific illustrations was unrelated. Existing tags belong to attempts, and Sources have a separate purpose.

## Domain and catalog

A Dish owns **zero or one primary Cuisine**. The value contains a stable machine `id` and a display `label`; SwiftData stores two new optional strings on Dish. CookingAttempt/RankedItem identities, score mathematics, comparisons and evidence are unchanged. All versions share the Dish's current Cuisine. New Version displays inherited Cuisine and cannot independently replace it; Edit Cook changes shared Dish metadata.

The bundled starter catalog contains **26** entries, with explicit stable IDs independent of labels: American, Italian, French, Spanish, Greek, Mediterranean, Israeli, Middle Eastern, Lebanese, Turkish, Moroccan, Mexican, Caribbean, Indian, Chinese, Japanese, Korean, Thai, Vietnamese, Filipino, Indonesian, Malaysian, Ethiopian, West African, Southern / Soul Food, Cajun / Creole. No taxonomy network request is required.

Custom Cuisine is embedded in its owning account's Dish graph, not published in a shared table. The picker reuses custom selections from Dishes in the **currently mounted account store only**. The existing guest/Debug store is separately isolated. Custom entries are suggestions while at least one Dish uses them; there is no independent unused-custom-value directory to synchronize or clean up. Deleting the last using Dish removes that active custom suggestion. Existing account/Dish deletion and tombstones therefore cover Cuisine automatically, without new ownership tables or deletion services. Stable custom IDs are `custom:` plus the normalized label, account-scoped by the owning Dish.

## Normalization and interaction

Display labels trim outer whitespace and collapse internal whitespace. Matching folds case, diacritics and width, treats punctuation separators as spaces and removes straight/curly apostrophes. The catalog is checked before custom creation. A small explicit alias map covers a few safe obvious variants (`Italain`, `Mediterranian`, `Mediteranean`, `Philipino`, `Viet Namese`, `Southern Soulfood`, `Cajun and Creole`). There is no approximate/fuzzy autocorrect; distinct values such as Sicilian and Italian or Tex Mex and Mexican remain distinct. Empty/punctuation-only values and labels over 80 Unicode scalars are not creatable. Existing equivalent custom values reuse their saved ID/label; otherwise a deterministic new ID is produced. Custom spelling is retained for display.

New Dish and Edit Cook have an optional Cuisine row in the existing Dish section. A native searchable list immediately shows the bounded catalog, marks the selected value, filters live and supports one-tap selection. A nonmatching valid query offers **Add “typed cuisine”** below results. No cuisine removes the selection; Cancel leaves the draft untouched. Draft changes persist only through the existing successful cooking save. Standard keyboard dismissal, Dynamic Type, system semantics and appearance-aware design tokens are retained. Source/Course/Contains/Dietary behavior is unchanged.

Rankings adds one Cuisine chip alongside the existing horizontally scrolling filters. It opens the same picker with creation disabled and **All cuisines** to clear. A selection combines with existing search/Course/Dietary/Avoid constraints and both Top Version / All Versions modes. The filter compares Dish Cuisine IDs and retains the authoritative `globalRank`; it never renumbers the filtered subset or recalculates a score. Nil-Cuisine Dishes remain valid and visible whenever no Cuisine filter is selected. No Cuisine-specific ranking or Unspecified mode is added. General text-search semantics are unchanged.

## Persistence, sync and backwards compatibility

The local change is additive nullable Dish metadata: no backfill, automatic assignment, data reset or forced selection. `DishTransfer` carries optional `cuisine: {id, label}`. Old snapshots without that key decode as nil. New records explicitly encode null for removal. Hydration preserves the value, validates bounded strings and account identity, and emits no outgoing echo. At the same accepted revision, decoded canonical equality handles old missing-field snapshots versus new null-field snapshots; real changed Cuisine or other graph values still reject revision collisions.

The tenth additive migration adds nullable `staygrubby.dishes.cuisine` JSONB with a bounded two-string object constraint. Only the Dish upsert branch and Dish snapshot projection change in the existing private functions; all authentication/live-session checks, account locks, owner derivation, revision/receipt/tombstone behavior and comparison validation remain intact. Snapshot `extra_float_digits=3` is explicitly preserved. Older client writes **without** the key preserve the existing server Cuisine; new explicit JSON null removes it. No new table, schema, API endpoint, policy, anonymous access or direct authenticated write grant is introduced. `Backend/schema.sql` remains the exact ordered migration concatenation.

## Verification

Focused verification passed: **32 test functions / 44 executions** (30 unit functions / 42 executions plus 2 UI methods / 2 executions), zero failures, unexpected failures or skips. Result bundle: `/private/tmp/staygrubby-cuisine-focused.xcresult`. Suites actually executed: CuisineTests (7 functions / 11 executions), CookingDiscoveryTests (12 / 16), StructuredCookingSyncTests (11 / 15), and CuisineUITests (2 / 2). The selected existing RankingsPresentation method selector matched no additional test; its top/all-version contract is explicitly covered by CuisineTests. An earlier development-only Cuisine run passed 6 functions / 10 executions before the inheritance test was added.

Debug app build/launch passed. The targeted UI flow covered dark New Dish selection, custom edit, saved custom filtering, relaunch persistence, duplicate prevention and removal, plus light accessibility-size selection/clear/cancel. A retained screenshot was visually reviewed. Both global ranks and score/evidence preservation have dedicated unit assertions.

The existing structured-sync PostgreSQL harness passed **75 assertions**, including an additive migration on already-populated legacy data, predefined/custom/null round trips, older-client preservation, malformed-value rejection, exact unchanged item/evidence/attempt graphs and existing isolation/retry/conflict/tombstone security contracts. No hosted fixture records were created. The apply-function diff was programmatically checked to change only its Dish branch.

Automatic SwiftData migration was verified by copying the original simulator store to a unique isolated UI-test filename and launching the new app against that clone. All **13 domain/relationship/sync tables** preserved every original field/row; the 12 Dishes gained nil Cuisine and SQLite integrity passed. The migrated clone launched directly into Rankings with its original scores and global order. The original development store was opened read-only for comparison and still matches the complete pre-task semantic/media baseline SHA-256 `bedd790ea8487f3b1baad442acd9092a6890b0a38cede4951aef0018469b9a51`: **1 ranking, 12 Dishes, 15 attempts/items, 356 comparisons, 10 Sources, 21 tags, 48 memberships, 190 media files**, zero sync bindings/operations/tombstones. Fixtures and migration copies remain outside tracked source and do not affect account/demo data.

Hosted Cuisine deployment is pending explicit owner approval: automatic approval review rejected the initial migration call because persistent shared-database deployment requires explicit authorization. No migration was applied by that call. Existing nine-migration hosted foundation remains deployed; the tenth local migration has been tested and is ready. The predeployment aggregate state is 20 active Dishes, 24 attempts/items, 79 comparisons and 44 Storage objects, with data fingerprints retained for comparison. Existing security-advisor notices remain the two intentionally inaccessible RLS/no-policy tables (INFO) and unused-password leaked-protection warning; no settings were changed. [Advisor explanation](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy), [password advisory](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

The existing privileged-secret patterns were rerun over all 227 intended repository files (223 text files), with zero findings. Client configuration, account/authentication code, ranking engine/models, sharing, official assets and Xcode configuration are unchanged. Local backup/dependency/build/Supabase-state/credential artifacts are excluded. `git diff --check` passes. Verification deliberately excludes the full historical UI/regression matrix, expensive ranking simulations, unrelated photo/share/deletion suites and another optimized Release build. No Release-only settings, authentication, entitlements or signing configuration changed. No real Apple authorization/deletion, TestFlight upload, archive or App Store Connect operation is part of this task.

## Release-foundation closeout and non-goals

Owner-confirmed public staygrubby.com HTTPS/routing, canonical `/privacy`, privacy/support contacts and completed App Store Connect App Privacy questionnaire are recorded in the existing release/account/website documentation. The ninth deletion migration and delete-account v2 are deployed. **Implemented and automated/security verified; real Apple credential revocation remains physically unverified** and intentionally deferred by the owner. This task does not reopen that implementation or claim a real destructive test passed.

The Master Roadmap now records Cuisine as the approved near-term enhancement and **Personalized Taste Intelligence & Discovery** as the final long-term phase. Cuisine is clean structured data that future history/recipe/discovery/social systems may consume; none is integrated now. No inference from tags/photos, multi-cuisine classification, taste scores, recommendation weights, AI calls/embeddings/infrastructure/cost, subscription or social feature was introduced. Personal Bradley–Terry ranking remains independent, unchanged and free.

## Checkpoint file inventory

- `ACCOUNT_DELETION_PRIVACY_REVIEW.md`
- `Backend/schema.sql`
- `Backend/tests/structured-sync.test.mjs`
- `COOKING_MODEL.md`
- `CUISINE_REVIEW.md`
- `STAYGRUBBY_MASTER_ROADMAP.md`
- `SYNC_ARCHITECTURE.md`
- `StayGrubby/Cooking/CookingDiscovery.swift`
- `StayGrubby/Cooking/CookingDraft.swift`
- `StayGrubby/Cooking/CookingStore.swift`
- `StayGrubby/Cooking/Cuisine.swift`
- `StayGrubby/Cooking/Dish.swift`
- `StayGrubby/Sync/CookingGraph.swift`
- `StayGrubby/Sync/CookingGraphHydration.swift`
- `StayGrubby/Sync/CookingGraphValidation.swift`
- `StayGrubby/Views/Cooking/CookingFilterView.swift`
- `StayGrubby/Views/Cooking/CookingMetadataForm.swift`
- `StayGrubby/Views/Cooking/CookingRankingView.swift`
- `StayGrubby/Views/Cooking/CuisinePicker.swift`
- `StayGrubbyTests/CuisineTests.swift`
- `StayGrubbyUITests/CuisineUITests.swift`
- `TESTFLIGHT_READINESS_REVIEW.md`
- `Website/README.md`
- `supabase/migrations/20261020214451_dish_primary_cuisine.sql`
