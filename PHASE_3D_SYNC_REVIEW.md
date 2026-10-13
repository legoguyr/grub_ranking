# Phase 3D Part 1 — private structured sync review

Starting checkpoint: `914122027e99cc995db7a3b7a9eb1b7c099e997d`, clean `main`, with live `origin/main` containing that exact checkpoint. After successful automated and physical-iPhone review, the user authorized a local checkpoint named **Complete Phase 3D structured cooking sync**. No reset, history rewrite or push is authorized.

## Implemented scope

The existing durable outbox now has an authenticated Supabase apply adapter and an account/store-scoped foreground worker. Local transaction staging remains the only mutation path. Exact receipts, hash/owner/store validation, predecessor/revision checks, bounded retry persistence, accepted-base replay, complete snapshot hydration, tombstones and fail-closed conflicts preserve local data and domain identities. The authentication gate, one global cooking ranking, on-device mathematics, Source/tag semantics, portrait configuration, Apple entitlement, SDK/client configuration and hidden Feed remain intact.

One subtle authenticated Profile status/Retry is added. Debug Profile also has an explicit read-only scratch restore verifier; it is neither an authentication bypass nor an uploader and is absent from Release. Editing/detail lifecycle leases prevent incoming updates from invalidating retained models, including destinations hidden by a tab change. The development/demo bypass remains Debug-only and never connects the sync transport. No media bytes or Storage objects are transferred.

## Backend and hosted verification

- `20261013022348_structured_cooking_sync.sql`: private fixed-search-path definer apply, authenticated invoker API wrapper, shared account-row snapshot/apply lock, live-session recheck, immutable operation receipts, narrow upserts and soft-deletion enforcement. No client write grants are added.
- `20261013023939_snapshot_numeric_fidelity.sql`: function-local precise Double JSON serialization for snapshot reads. Hosted integration found caller float precision 0 rounded a domain timestamp; the follow-up fixes serialization without changing stored values or ranking math. Earlier applied SQL remains unchanged.
- All seven hosted migration MD5 hashes match their repository bytes, and Backend/schema.sql is the exact concatenation.
- Local schema/RLS tests: 69 assertions. Structured SQL tests: 60 assertions in PGlite and 60 in native PostgreSQL, using actual Swift-generated wire payloads and low-precision caller settings. Existing native transaction/concurrency tests: 18 assertions with 20 overlapping callers. The disposable Unix-socket cluster is stopped.
- Actual hosted SQL tested six Swift-generated operations (create, second cook, version, media metadata/nullable Source fields, Course/tags/title/notes edit, deletion), duplicate retries, every final graph field/ID/relationship/cache/date, tombstones, stale/reused operations, cross-account RLS/ownership, anonymous denial and revoked-session receipt replay.
- Hosted fixtures used two temporary Auth users/sessions and account graphs inside an explicit transaction ending in ROLLBACK. No Apple identities, real login, user JWT or persistent fixture records were created. This exercises real hosted functions/RLS with simulated SQL claims; it does not claim authenticated app HTTP end-to-end verification.
- A real anonymous REST apply request using only the approved publishable client configuration was rejected with HTTP 401 / SQLSTATE 42501. Apple remains the only enabled provider; Email remains disabled.
- Security catalog checks retain RLS on all 15 tables, anonymous denial, direct client-write denial and protected identity links. Advisors retain the intentional policy-free identity-link INFO and the existing password-protection WARN, inapplicable while password login is disabled. No security protection was weakened.
- Initial oversized SQL verification failed at the truncated request text before a transaction began. The subsequent rollback test exposed numeric serialization rounding; it passed after the precise snapshot follow-up. These failures were investigated rather than hidden.

## Data and media safety

Before manual review, isolated automated hosted tests left the real account empty with no operation receipts. After the user's successful real-account test, final read-only hosted verification confirms one Auth user/Apple identity/account/link/profile/library/global ranking, zero active cooking records, and account sync revision **4**. The raw Dish, CookingAttempt and RankedItem tables each retain **one soft-deleted row**. Three durable receipts remain: createCook (revision 2), editCook (revision 3), deleteCook (revision 4). Comparisons, Sources, tags, memberships, media and sync imports have zero rows; Storage has zero objects. Valid tombstones/receipts/history were not purged. The real account was never an automated fixture or deleted/recreated.

The development manifest remains exactly 1 ranking, 12 dishes, 15 attempts/items, 356 comparisons, 10 sources, 21 tags, 48 memberships and 190 media files. Full field/evidence/relationship/identity/media-hash comparison matches the preserved baseline. Fixture data remains in temporary isolated stores; the physical iPhone's empty development library is not populated.

Structured media records restore safely with missing local bytes and placeholders. Photos remain device-local. Remote upload/download, backup/CDN, thumbnails, remote object cleanup and local orphan cleanup are deferred to media sync.

## Physical-iPhone manual verification — PASSED

The user completed and approved the real-account test on the physical iPhone:

1. The existing Apple-authenticated account opened; cold launch automatically restored its saved account/session.
2. One **Phase 3D Sync Check** dish/cook was created without a photo. Structured data synchronized automatically and Profile reported **Cooking data up to date**.
3. Debug fresh restore verification passed with **1 dish / 1 cook / 0 comparisons**.
4. Version/notes/Course edits briefly showed **Sync pending**, then synchronized automatically without Retry. Fresh restore passed again with **1 dish / 1 cook / 0 comparisons**, preserving the edited fields.
5. Deleting the final cook synchronized automatically before Profile was opened. Fresh restore passed with **0 dishes / 0 cooks / 0 comparisons**, and the deleted dish did not resurrect. No manual Retry was needed throughout.

Final hosted verification independently confirms the active counts, retained tombstones/receipts/revision and empty Storage above. The deployed restore function excludes soft-deleted rows and emits their deletion references; apply rejects tombstoned identity revival. No additional real-account mutations or authorization were performed by the agent during this checkpoint.

A brief authentication/loading transition may appear during cold session restoration. This is a future startup-UX polish item, not a change to the verified authentication architecture. No startup redesign was performed. A second physical-device test and real photo transport are not claimed by this single-phone/scratch-store review.

## Reference physical-iPhone manual procedure

1. Use the uncommitted StayGrubby project, Debug, canonical bundle/team and the existing physical iPhone. Remove any review/demo launch arguments. Build/run normally. Sign into the existing real account only if necessary. Confirm the same Account ID, empty Rankings and no Feed. Do not choose Open development library.
2. Create one dish named **Phase 3D Sync Check** with one cook/version. Use no photo for this structured-only review. Complete the normal reaction/ranking flow and close the result. Confirm it is immediately present locally.
3. Open Profile and wait for **Cooking data up to date**. In Supabase SQL Editor use the read-only counts/identity query below. Expect one live dish, attempt and ranked item, one unchanged global ranking/library, and acknowledged operation receipt(s). Record domain IDs and strength/uncertainty/date values; never copy session/Apple tokens or nonces.
4. Edit that cook: change Version title, notes and Course. Optionally review Source/tags. Save locally; wait for sync. Confirm the same Dish/Attempt/RankedItem IDs and updated metadata in cloud. Existing comparison IDs/evidence must be unchanged by metadata edits.
5. Optional offline check: disconnect networking while the authenticated account is open, edit notes and save. Confirm it persists locally and Profile shows pending sync. Relaunch only while the verified SDK session is still valid. Reconnect/foreground and wait for current status; confirm cloud update. Do not sign out offline just to test sync.
6. Safe fresh-store check on the primary phone: with no pending work, use Profile → **Verify fresh restore (development)**. Expect the matching counts and successful verification. This uses/removes only a separate scratch directory, restores twice and compares all canonical fields/identities/evidence/cache/relationships. It never replaces, clears or remounts the primary local store. Never delete/reinstall the primary app or remove its cooking.store for this test.
7. If a second physical device is available, install the same build and sign in with the same Apple account. Confirm the same permanent Account ID and restored dish/cook IDs, metadata and ranking/cache state. Photos are intentionally unavailable unless already present locally. Keep the primary copy intact. With no pending edits on A, edit notes on B, sync, then foreground A on Rankings/Profile (close retained details/forms first) and confirm the update. Do not intentionally manufacture conflicting edits in this first real-data test.
8. Delete the **Phase 3D Sync Check** cook through the normal app UI. Because it is the dish's final version, existing domain rules remove the dish/source as applicable and incident evidence, while retaining unused shared tags. Wait for sync.
9. Confirm no active test dish/attempt/item remains. The cloud raw rows remain soft-deleted, with deletion markers and a durable operation receipt; do not manually purge them or delete the global ranking/library. Verify scratch restore again and, on B if used, foreground/reopen Rankings to confirm the deleted object does not return.
10. Report observed results for approval. Do not create more test dishes, reset/adopt the development dataset, delete the Auth account, or commit/push before review.

Read-only review queries (run after each manual step; the account currently contains no other cooking data):

```sql
select (select count(*) from auth.users) auth_users,
       (select count(*) from staygrubby.accounts) accounts,
       (select count(*) from staygrubby.auth_account_links) links,
       (select count(*) from staygrubby.profiles) profiles;
select a.id account_id,a.sync_revision,l.global_ranking_id,r.id ranking_id
from staygrubby.accounts a join staygrubby.account_libraries l on l.account_id=a.id
join staygrubby.rankings r on r.account_id=l.account_id and r.id=l.global_ranking_id;
select id,account_id,name,source_id,deleted_at from staygrubby.dishes;
select id,dish_id,ranked_item_id,version_title,notes,course_code,cooked_at_ref,deleted_at from staygrubby.cooking_attempts;
select id,ranking_id,strength,uncertainty,created_at_ref,deleted_at from staygrubby.ranked_items;
select id,first_item_id,second_item_id,preferred_item_id,is_tie,timestamp_ref,deleted_at from staygrubby.comparisons;
select operation_id,store_id,expected_revision,predecessor_id,accepted_revision from staygrubby.sync_operations order by server_created_at;
select count(*) active_dishes from staygrubby.dishes where deleted_at is null;
select count(*) active_attempts from staygrubby.cooking_attempts where deleted_at is null;
select count(*) active_items from staygrubby.ranked_items where deleted_at is null;
```

## Remaining limitations

Automatic concurrent-edit merging/rebasing and a backed-up manual conflict-resolution workflow are deferred. A stale operation remains queued; Retry cannot overwrite it using naive last-write-wins. Large-operation batching beyond the stated server limits, receipt/tombstone compaction, background execution, photo transport/orphan management and account erasure/revocation are not claimed complete. Offline use cannot verify server revocation. Real-device authenticated create/edit/delete and scratch restore are now manually verified; a second physical-device test remains additional coverage. Remote cooking-photo backup/restore is the recommended next phase, with account-scoped Storage security, durable byte transfers, integrity checks, missing-byte handling and deletion coordination.

## Final automated validation

- Complete final Debug suite: **150 test functions / 192 executions**, including 19 UI tests; zero failures, unexpected failures, expected failures or skips. Result: `/private/tmp/staygrubby-3d-complete-final.xcresult`.
- Release authentication gate: **1 test / 1 execution**, zero failures or skips. Result: `/private/tmp/staygrubby-3d-release-gate.xcresult`. Release test products used command-line `ENABLE_TESTABILITY=YES` for existing test imports, without enabling DEBUG.
- An earlier full run had one simulator accessibility-tap failure (`{-1,-1}` hit point) in the unchanged filter/creation-navigation UI test. That test passed unchanged on individual rerun; the complete final suite also passed. No UI assertions were weakened.
- Backend total: **207 passing assertions** (69 schema/RLS + 60 PGlite structured + 60 native structured + 18 native concurrency/transaction).
- Final Debug build/normal simulator launch and ordinary Release build succeeded. Onboarding was visually checked; no real Apple authorization was performed. Release binary checks exclude development-library/review/scratch-restore paths and retain the canonical bundle identity and upright-portrait configuration.
- Final saved-store manifest, SQLite integrity, store metadata and all 190 media hashes match the preserved baseline. No bindings, outbox operations or test fixtures leaked into the development store.
- Final post-manual hosted counts: one user/Apple identity/account/link/profile/library/ranking; zero active cooking records; one soft-deleted dish/attempt/item each; three operation receipts; sync revision 4; zero comparisons, Sources, tags, memberships, media, sync imports and Storage objects. Seven migration hashes remain aligned.
- Credential scan and whitespace checks pass. Client configuration is unchanged and contains only approved public configuration. Backups, local secrets/Supabase state and test dependencies are excluded; build/result artifacts remain outside the repository.
- Checkpoint verification reran all **207 backend assertions** successfully and rechecked hosted RLS/privileges/advisors, seven migration hashes, credentials, development manifest and whitespace. The complete Debug/Release test result bundles and builds remain valid: all application/test sources predate the completed final suite and no application code changed during checkpoint verification. Only this review document and the sync architecture's current verification paragraph were updated.
- The approved checkpoint includes **27 intended files** on `main` (17 modified tracked files plus 10 new files), excluding backups, local secrets/state, dependencies and build artifacts. It is local only; the user will push through GitHub Desktop after reviewing the report.

## Complete changed-file list

- `ACCOUNT_ARCHITECTURE.md`
- `Backend/README.md`
- `Backend/schema.sql`
- `Backend/tests/fixtures/swift-cooking-operations.json`
- `Backend/tests/package.json`
- `Backend/tests/schema.test.mjs`
- `Backend/tests/structured-sync.test.mjs`
- `PHASE_3D_SYNC_REVIEW.md`
- `SYNC_ARCHITECTURE.md`
- `StayGrubby/Accounts/AccountApplicationRoot.swift`
- `StayGrubby/Accounts/AccountLibraryAccess.swift`
- `StayGrubby/Accounts/AccountSessionCoordinator.swift`
- `StayGrubby/Accounts/AccountView.swift`
- `StayGrubby/Cooking/CookingStore.swift`
- `StayGrubby/Models/RankingStore.swift`
- `StayGrubby/Sync/CookingGraphValidation.swift`
- `StayGrubby/Sync/CookingSyncCoordinator.swift`
- `StayGrubby/Sync/FreshCookingRestoreCheck.swift`
- `StayGrubby/Sync/SupabaseCookingSyncTransport.swift`
- `StayGrubby/Sync/SyncChangesApplication.swift`
- `StayGrubby/Sync/SyncJournal.swift`
- `StayGrubby/Views/Cooking/AddCookingView.swift`
- `StayGrubby/Views/Cooking/AttemptDetailView.swift`
- `StayGrubbyTests/StructuredCookingSyncTests.swift`
- `UI_ARCHITECTURE.md`
- `supabase/migrations/20261013022348_structured_cooking_sync.sql`
- `supabase/migrations/20261013023939_snapshot_numeric_fidelity.sql`
