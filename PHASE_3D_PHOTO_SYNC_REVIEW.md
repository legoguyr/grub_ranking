> The successful physical photo lifecycle and its zero-cleanup snapshot below remain verified history. Subsequent user V1 testing retained 12 active attempts/photos across 10 Dishes; this task preserves those records. Current hosted counts are in V1_FINAL_REVISIONS_REVIEW.md. No history or active user data is purged.

# Phase 3D Part 2 — private photo sync review

Starting checkpoint: `a4b61eb177db055723ed07319e1c0655afbb8bca` on clean main; live origin/main matched before work. No commit/push/reset/history rewrite. The physical-iPhone data-path verification has now passed; the combined uncommitted checkpoint still awaits the new Core App V1 score-unlock/milestone review.

## Physical-iPhone verification — passed October 13, 2026

The user verified the existing real Apple account with **Phase 3D Photo Sync Check**: one real photo → automatic backup without laptop connection → fresh restore **1 dish / 1 cook / 0 comparisons / 1 photo** → visibly different replacement → the local share card immediately used that replacement → automatic sync → fresh restore **1 dish / 1 cook / 0 comparisons / 1 photo** → deletion of the final cook → automatic sync → fresh restore **0 dishes / 0 cooks / 0 photos**, with no resurrection. This physical data-path gate is PASSED. No second-device or offline-replacement coverage is inferred.

Observed polish item: replacement briefly remained pending while the user stayed in the dish flow, then completed immediately after returning to Rankings. The existing navigation restore leases defer incoming reconciliation and full-current confirmation while an editor/detail is retained; inspection found no data-loss or correctness defect. Record clearer in-flow sync feedback as future polish; the worker and conflict behavior were not redesigned.

Fresh read-only hosted verification after the user test confirms zero ACTIVE dishes/attempts/items/comparisons/media and zero Storage objects. The latest read-only snapshot at October 13, 2026, 20:50 EDT contains five retired dishes/attempts/items and media records, five cleaned backup manifests, fourteen receipts and sync revision 15. All active cooking/media and Storage counts remain zero. This supersedes the earlier snapshot of three retired records, ten receipts and revision 11; the two additional retired records were already deleted before this final check. No hosted write fixtures or real authorization were performed by this task. Valid tombstones/receipts/manifests were not purged. The deleted test data was not recreated.

## Implemented scope

Private cooking-photos bucket, two optimized JPEG variants, account/media/content-hash object paths, immutable server manifests, live account-derived Storage RLS, durable account-local byte-transfer checkpoints, verified upload/read-back, authenticated local reconstruction, replacement/deletion cleanup, accurate existing Profile status and a photo-aware isolated Debug verifier. No SwiftData schema/domain/ranking changes, privileged client credentials, social/public media, signed URLs, new photo UI or authentication redesign. See MEDIA_SYNC_ARCHITECTURE.md for lifecycle, security, integrity and limits.

## Automated validation before the physical test (historical totals)

- Initial focused tests passed 12 functions (17 parameterized executions); expanded focused tests passed 16 functions before the final pending-replacement parameter was added. The complete final suite runs the final 16 functions/22 executions plus existing regressions. Complete Debug suite passed **166 test functions / 214 executions**, including all 19 UI tests: zero failures, unexpected failures, expected failures or skips. Result: /private/tmp/staygrubby-photo-full.xcresult. No test assertions were weakened; all application/test source hashes remain unchanged through the full run.
- Backend: 69 schema/RLS + 60 PGlite structured + 42 PGlite photo-policy assertions. Native PostgreSQL: 60 structured + 46 photo-policy/locking + 18 provisioning/concurrency assertions. **295 assertions passed**, with native object authorization proven to block concurrent structured retirement and deny late uploads. Disposable databases were dropped; the temporary cluster is stopped.
- Hosted migration `20261013043630_private_cooking_photo_backup` deployed successfully. All eight migration hashes/reference concatenation are checked; the new MD5 is `e368fc84cd607a88ad17e7fb3a1d9c5b`. Earlier seven applied files remain unchanged.
- Actual hosted SQL/RLS fixture transaction passed A-owned registered pair, registration/completion retry, forged account/hash/path denial, B read/list/upload/overwrite/delete denial, anonymous denial, revoked-session denial, immediate tombstone read/upload denial, deletion-only cleanup visibility and incomplete-cleanup refusal. Fixtures used two temporary Auth users/sessions/accounts, actual Swift structured wire operations and synthetic Storage catalog metadata, ending in ROLLBACK. No Apple identities, real user JWTs, real account mutations or S3 bytes were created; no Storage catalog deletion bypass was used. Authenticated HTTP/S3 byte behavior subsequently passed the user physical sequence above.
- Hosted security retains all **16 private tables with RLS**, zero anonymous application-table grants, zero unrestricted authenticated application writes and protected identity links. Storage objects retain RLS and four account-scoped policies. Helpers have fixed empty search paths and anonymous media RPC execution is denied. Existing identity-link no-policy INFO and password-protection WARN remain unchanged; Email/password remains disabled.
- Debug build and ordinary Release build succeeded. Release authentication gate passed **1 test / 1 execution**, zero failures/skips. Result: /private/tmp/staygrubby-photo-release-gate.xcresult. Test products use command-line ENABLE_TESTABILITY=YES for existing imports, without enabling DEBUG.. Debug-only restore/demo paths remain excluded from Release; canonical bundle, signing/Apple entitlement and upright-portrait configuration remain unchanged.
- The Simulator development manifest remains exactly 1 ranking, 12 dishes, 15 attempts/items, 356 comparisons, 10 Sources, 21 tags, 48 memberships and 190 media files, with every field/relationship/evidence/identity/media hash matching the preserved baseline. No account binding, outbox or transfer journal leaked into it.
- Final read-only hosted state before physical approval: 1 Auth user/Apple identity/account/link/profile/library/global ranking; zero active cooking data/media/manifests/Storage objects. Existing one soft-deleted dish/attempt/item, three receipts and sync revision 4 remain intact. The new cooking-photos bucket is private, JPEG-only, 2 MiB per variant.
- Credential/secret scan, all eight migration hashes/reference concatenation, protected source/configuration hashes, Release binary/symbol exclusions and whitespace checks pass. Backups, dependencies, local Supabase state/secrets and build artifacts are excluded; the intended 25 files remain unstaged/uncommitted/unpushed on main at the starting checkpoint. Anonymous HTTP media RPC returned 401, Storage list returned an empty array, and attempted anonymous upload was rejected; no object was created. Normal final Debug launch succeeds and onboarding is visually checked; the post-launch full development manifest, SQLite integrity and metadata comparison remain exactly equal to the preserved baseline.

## Completed physical-iPhone procedure (retained for reference)

1. Open this uncommitted StayGrubby project on main. Select Debug and your physical iPhone; build/run normally with no demo/review launch arguments. Do not reinstall/reset the primary app or adopt the Simulator dataset.
2. Use the existing real Apple-authenticated account; sign in only if needed. Confirm its permanent Account ID and zero active cooking records. Existing retired rows/receipts/revision history are expected.
3. Create exactly one dish named **Phase 3D Photo Sync Check**. Attach exactly one normal photo. Do not add extra cooks or optional tags/Sources just to test byte transport. Complete the existing reaction/ranking flow and save; with the empty active library, expect one cook and normally zero comparisons.
4. Confirm the normal local dish/detail photo displays immediately. Close creation/detail/edit flows and open Profile. Wait for **Cooking data up to date** without pressing Retry. Pending/review must never be mistaken for a completed backup.
5. In the Supabase SQL Editor run the read-only queries below. Expect one active dish, attempt, item and media row; one active manifest ready=true; exactly **two** private Storage objects (display and thumbnail) matching its paths/sizes. Confirm the bucket remains private. Record media UUID and both content hashes/keys; never copy account/session/Apple tokens.
6. Run Profile → **Verify fresh restore (development)**. Expect **1 dish / 1 cook / 0 comparisons / 1 photo** (or the actual valid comparison count if the flow produced evidence). This success requires authenticated downloads and actual validated local display/thumbnail reconstruction in the separate scratch root. Confirm the main photo remains normally visible afterward.
7. Optional offline coverage: after the initial backup, temporarily disconnect networking, replace the photo through normal Edit with a visibly different image and save. Confirm the new local photo appears and pending status persists. Reconnect/foreground and allow automatic recovery. Do not sign out offline. If skipping this optional variation, simply perform replacement while online.
8. Replace the photo exactly once with a visibly different photo. If step 7 already performed the replacement, do not replace again. Save and return to Profile; wait for fully up to date without Retry.
9. Re-run the read-only queries. Expect a **new media UUID and new hashes/paths**, the old media soft-deleted and its manifest cleaned=true, one active new ready manifest and exactly two current Storage objects. Old paths must be absent after cleanup. Dish/attempt/item IDs and unrelated evidence remain unchanged.
10. Run fresh restore verification again. Expect one photo and successful byte recovery. Compare the active manifest's new hashes against the recorded old hashes; the verifier also compares restored bytes to those new hashes. Confirm the new image remains visible in the primary app. Scratch content is deliberately not mounted as a replacement UI.
11. Delete the final/only test cook through the normal UI. Return to Profile and wait for automatic fully up-to-date status. This retires the final dish and associated media according to existing domain rules.
12. Query again: zero active test dishes/cooks/items/media; zero uncleaned media manifests; zero Storage objects. Raw structured/media tombstones, cleaned manifests, receipts and higher revisions are valid history; do not manually purge them.
13. Run fresh restore verification again: **0 dishes / 0 cooks / 0 comparisons / 0 photos**. Foreground/relaunch normally and confirm the test dish/photo does not resurrect. Report upload, restore, replacement, restore, deletion, no-resurrection and cleanup results for approval. No commit/push until that sequence passes.

The sequence preserves the primary local copy and uses the existing Debug scratch verifier. It neither requires a second device nor claims second-device manual coverage. A second physical device using the same account is optional additional validation. Any missing-byte/integrity/authentication failure should leave the structured app usable and the primary store intact; report it before checkpointing.

Read-only SQL (the account has no other active cooking data):

```sql
select id,public,file_size_limit,allowed_mime_types
from storage.buckets where id='cooking-photos';
select a.id account_id,a.sync_revision,l.global_ranking_id
from staygrubby.accounts a join staygrubby.account_libraries l on l.account_id=a.id;
select 'dishes' entity,count(*) filter(where deleted_at is null) active,count(*) raw from staygrubby.dishes
union all select 'attempts',count(*) filter(where deleted_at is null),count(*) from staygrubby.cooking_attempts
union all select 'items',count(*) filter(where deleted_at is null),count(*) from staygrubby.ranked_items
union all select 'comparisons',count(*) filter(where deleted_at is null),count(*) from staygrubby.comparisons
union all select 'media',count(*) filter(where deleted_at is null),count(*) from staygrubby.media;
select m.id media_id,m.attempt_id,m.deleted_at,b.ready,b.cleaned,
 b.display_hash,b.thumbnail_hash,b.display_bytes,b.thumbnail_bytes,b.display_key,b.thumbnail_key
from staygrubby.media m left join staygrubby.media_backups b on b.account_id=m.account_id and b.media_id=m.id;
select name,metadata->>'size' bytes,metadata->>'mimetype' mime
from storage.objects where bucket_id='cooking-photos' order by name;
select count(*) objects from storage.objects where bucket_id='cooking-photos';
select count(*) uncleaned from staygrubby.media_backups where not cleaned;
select operation_id,kind,accepted_revision from staygrubby.sync_operations order by accepted_revision;
```

## Limitations

No background janitor/execution, original assets, public/social media, signed URLs, transforms, parallel transfer queue, large-library pagination, automatic conflict resolution, history compaction, arbitrary local orphan purge or account-erasure implementation. Offline/terminated deletion cleanup waits for a later authenticated worker, with immediate RLS inaccessibility. Byte hashes are enforced on client read-back/restore; server completion checks catalog metadata, not S3 file contents. Standard Storage API uploads retry whole bounded optimized files. The existing cold-launch transition remains future startup-UX polish.

## Complete changed-file inventory

- `ACCOUNT_ARCHITECTURE.md`
- `Backend/README.md`
- `Backend/schema.sql`
- `Backend/tests/package.json`
- `Backend/tests/photo-security.test.mjs`
- `Backend/tests/provisioning.concurrent.mjs`
- `Backend/tests/schema.test.mjs`
- `Backend/tests/storage-stub.mjs`
- `Backend/tests/structured-sync.test.mjs`
- `MEDIA_SYNC_ARCHITECTURE.md`
- `PHASE_3D_PHOTO_SYNC_REVIEW.md`
- `SYNC_ARCHITECTURE.md`
- `StayGrubby/Accounts/AccountApplicationRoot.swift`
- `StayGrubby/Accounts/AccountSessionCoordinator.swift`
- `StayGrubby/Accounts/AccountView.swift`
- `StayGrubby/DesignSystem/StayGrubbyComponents.swift`
- `StayGrubby/Sync/CookingPhotoJournal.swift`
- `StayGrubby/Sync/CookingPhotoManifest.swift`
- `StayGrubby/Sync/CookingPhotoSync.swift`
- `StayGrubby/Sync/CookingSyncCoordinator.swift`
- `StayGrubby/Sync/FreshCookingRestoreCheck.swift`
- `StayGrubby/Sync/SupabaseCookingPhotoTransport.swift`
- `StayGrubbyTests/CookingPhotoSyncTests.swift`
- `UI_ARCHITECTURE.md`
- `supabase/migrations/20261013043630_private_cooking_photo_backup.sql`
