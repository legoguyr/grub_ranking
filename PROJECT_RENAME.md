# StayGrubby project identity and simulator library transfer

The canonical application identity is **StayGrubby**, bundle ID `com.guyrettig.StayGrubby`. The project is `StayGrubby.xcodeproj`, its shared scheme and app target/module/executable are `StayGrubby`, and the test targets/modules are `StayGrubbyTests` and `StayGrubbyUITests`. Debug and Release preserve automatic signing with team `5DSB36G7LZ` and the `Default` Sign in with Apple entitlement in `StayGrubby/StayGrubby.entitlements`. The app remains iPhone upright-portrait only.

The approved starting checkpoint was `4e391b9124379e4cf94c8c2792792704eb7e36f5` on main. Manual team/entitlement changes were retained. Although the requested bundle ID had been selected manually, the saved project still contained the old ID in both configurations; this pass corrects those saved settings. No native Apple login is implemented.

## Historical names and external boundaries

Previously the project/target/product/source directory were `Grub Ranked`, its Swift module/app type were `Grub_Ranked` / `Grub_RankedApp`, and its bundle ID was `com.guyrettig.Grub-Ranked`. Test identities had the corresponding Tests/UITests suffixes. These names in earlier validation reports and file inventories describe the original checkpoint, not current instructions.

`DevelopmentTools/OneTimeDevelopmentSeed.swift` and `OneTimeDevelopmentAllergenUpdate.swift` are historical utilities outside all targets. Their original module and bundle guards intentionally remain: they must not become reset mechanisms for the renamed app. Neither is part of the shared scheme. The transfer utility retains the old bundle ID solely to identify the source simulator container.

The outer checkout directory and GitHub remote `grub_ranking` remain unchanged. They are external workspace/repository locations, not app identity. Renaming the GitHub repository separately is recommended for consistency, with GitHub Desktop/checkout paths reconciled in a separate operation. This pass does not change remotes, Git history or the active workspace root. Old XcodeBuildMCP workspace/result-bundle directory names are historical tool cache paths and do not control the app's name or bundle ID.

## Data preservation

A different bundle ID has a separate iOS sandbox. Simply launching the new app would therefore expose a new empty default store. This pass first installed the new simulator app **without launching**, then explicitly transferred the old library into its fresh container. The old container remains intact for recovery.

`DevelopmentTools/transfer_simulator_library.py` is a manual Simulator-only tool, outside every Xcode target. It requires an explicit Simulator UUID and `--apply`, checks both containers' metadata against the historical and canonical bundle IDs, and refuses paths outside that selected CoreSimulator device. It refuses a nonempty different destination. Repetition can only verify identical data; it cannot overwrite subsequent user work. No launch flag or app startup reset calls it.

It creates a fresh ignored `.local-backups` checkpoint, snapshots each SQLite `.store` through the SQLite backup API (including committed WAL content), preserves relative media and account-directory paths, checks integrity and all entity fields/relationships, and installs the verified snapshot by a directory rename. It never changes domain UUIDs, timestamps, scores or comparison evidence. Database metadata and existing schema definitions are left untouched. The app's default guest store remains `Application Support/default.store`; guest media remains `StayGrubbyMedia`; account stores remain isolated under `StayGrubbyAccounts/<account UUID>/cooking.store`. There were no account stores or CookingMedia records in this development library; separate transfer tests cover those paths. The existing media directory nevertheless contained 190 unreferenced photo files from earlier fixture runs. All 190 were preserved byte-for-byte rather than discarded.

The first transfer attempt stopped before destination mutation because of a relative backup-path handling error. Its consistent source backup was retained; the path fix has its own regression test and the successful transfer uses a separate fresh backup directory.

The actual transfer was authorized for iPhone 17 / iOS 26.5 Simulator `D839186C-3810-4C98-99FA-3C88230212DC`. Backups/manifests are under ignored `.local-backups/project-rename/`. This is a development recovery operation, **not** a production cross-bundle migration or permission to copy physical-device data. Do not uninstall the old app until review is complete. Never repeat the historical reset utilities to recover this library.

## Backend and signing boundary

The client-safe Supabase configuration and pinned Swift SDK 2.55.3 are unchanged. The manually configured Apple primary App ID and Supabase Apple Client ID are `com.guyrettig.StayGrubby`. Account provisioning derives ownership from trusted Supabase Auth/session UUIDs, not app branding; no deployed migration or hosted account is changed for this rename.

Simulator signing verifies configuration and embedded entitlements, but does not prove physical-device provisioning or a real Apple authorization. Open `StayGrubby.xcodeproj`, select the shared `StayGrubby` scheme, and confirm the selected team and Sign in with Apple capability in Signing & Capabilities. Close any stale old-project Xcode window first. A physical-device signing/profile check is a separate manual check; real authentication remains deferred.

## Manual approval checks

1. Open the renamed project and run the shared StayGrubby scheme on the same iPhone 17 simulator. Confirm the app icon/title use StayGrubby and the saved 15-cook ranking appears.
2. Search for Harissa (two versions), clear search, and exercise Course, Dietary and Avoid filters. Clear filters afterward.
3. Open Harissa Chicken Kabobs, select its other version, begin re-ranking, test a choice/Undo/Skip, then cancel so saved evidence is unchanged.
4. Open and cancel New Dish and New Version. Creation/saving/relaunch are verified in isolated UI-test stores; saving personal review edits will intentionally change the baseline.
5. Terminate/relaunch offline and confirm the same library is available. Review Feed/Profile and upright portrait behavior.
6. In Xcode confirm Debug/Release canonical bundle ID, team and Apple capability. Do not start Apple login for this approval.

## Completed validation — October 11, 2026

- The complete shared StayGrubby scheme passed on iPhone 17 / iOS 26.5: **109 test functions / 137 executions**, comprising 95 unit functions / 122 executions and 14 UI functions / 15 executions. Zero failures, unexpected/expected failures or skips. Runtime was approximately 15 minutes 22 seconds. Result bundle: `/private/tmp/staygrubby-rename-full.xcresult`.
- Existing manual seeded-library review utilities were temporarily compiled into the renamed UI target: **2 tests / 2 executions passed**, zero failures/skips. Real-store discovery/filter/version/canceled re-ranking checks passed; actual New Dish/New Version/saved re-ranking and relaunch used an explicitly cloned temporary store. The temporary test file was removed. Result bundle: `/private/tmp/staygrubby-rename-library-review.xcresult`.
- Seven isolated Python transfer safety tests passed, including committed-WAL backup, media/account paths, idempotence, relative backup paths, destination refusal and container/symlink boundaries.
- AccountSessionTests: **14 functions / 16 executions passed**. SyncFoundationTests: **17 functions / 22 executions passed**. Backend regression: **59 PostgreSQL schema/RLS assertions** and **13 native PostgreSQL concurrency/transaction assertions** passed. The native test database was disposable; its Unix-socket-only cluster was stopped afterward. Hosted reads confirm the same four migration checksums and zero Auth users/accounts. No hosted write/migration occurred.
- Package resolution/build/linking succeeded with the unchanged exact Supabase Swift SDK 2.55.3 lockfile. A final normal simulator build/install/guest launch succeeded after temporary-test cleanup. The generated simulated entitlements contain the canonical team application identifier and `com.apple.developer.applesignin = [Default]`. Simulator code signing uses Xcode's simulated entitlement section, not a physical-device provisioning profile. Both Debug and Release source settings preserve the team, automatic signing and entitlement path.
- Supabase public Auth settings confirm Apple is enabled. Those public settings do not expose Apple Client IDs, so the user-supplied portal Client ID/Primary App ID configuration still requires manual confirmation. The approved client-safe configuration is byte-for-byte unchanged. No privileged credential value was found in the intended repository files.
- After all tests and a final normal launch, the old container, transferred snapshot and new container match on all original record fields/relationships and original files: **1 RankingList, 12 Dishes, 15 CookingAttempts/RankedItems, 356 Comparisons, 10 Sources, 21 tags / 48 memberships, 1 CookingLibrary, 0 CookingMedia records and 0 records in all three sync tables**. SQLite integrity is `ok`; original store UUID, schema hashes/checksum, timestamps, scores/uncertainty/diagnostics, comparison evidence, Contains/Avoid data and links are unchanged. Optimistic-lock counters are excluded from semantic comparisons; no schema/migration change was needed.
- Xcode test installation relocated the new app's data-container UUID while preserving its contents. Final checks re-resolved container metadata rather than relying on the first cached path. The manual transfer tool itself resolves current container paths on every invocation.
- `git diff --check` and the staged equivalent pass. All ranking, cooking, persistence, sync/account and UI implementation files are unchanged in content; only the app entry-point type and an autogenerated Item header changed in application sources. Test imports/class names and one application-identity assertion were updated. The original manual entitlement is preserved. No commit, push, remote change or GitHub repository rename occurred.

## Existing fixture-media isolation issue discovered during verification

**Resolved in the subsequent October 12 investigation:** see `UI_ENVIRONMENT_DIAGNOSIS.md`. The following paragraphs record the rename-only checkpoint and its original cleanup boundary.

The debug discovery fixture writes its generated photo into the default guest media directory even though its database is an isolated UI-test store. This behavior predates the rename. The complete suite added 22 JPEG files (11 display/thumbnail pairs); every filename was verified against CookingMedia rows in the isolated temporary test databases, and none was referenced by the real development store (which still has zero media records). These 22 new artifacts were backed up under `.local-backups/project-rename/verification-fixture-photos/`, then removed. All 190 pre-existing files remain unchanged. No new test artifact remains in the development Application Support tree.

The final real store matches its original snapshot exactly. The existing fixture media-root behavior has deliberately not been refactored as part of this identity-only task; fully isolating future fixture photos is a separate follow-up. There is no rename-specific build/data blocker, but this pre-existing test hygiene issue remains documented.

## Remaining legacy-reference classification

The final intended-file search has 18 matching lines across nine files. ACCOUNT_ARCHITECTURE's six Part 1 file-inventory entries, COOKING_MODEL's Phase 1 app filename, SYNC_ARCHITECTURE's October 8 scheme report, RANKING_MODEL's original result-bundle path and DevelopmentTools/README's October 5 reset ID are explicitly historical. The two original Swift reset utilities retain their old import/bundle guards outside all targets. The transfer tool's one old ID is source-container compatibility only. This document's two naming/remote paragraphs explain the historical and external identities. No legacy name remains in active project, scheme, app or test-target configuration.

Git history/index rename sources, ignored personal backups, the unchanged external checkout/remote, and historical XcodeBuildMCP caches retain their original names intentionally. They were not global-replaced or rewritten. Full Git status and reference inventory are saved under ignored `.local-backups/project-rename/` for review.
