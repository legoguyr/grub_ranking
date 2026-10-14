# Private cooking-photo backup and restore — Phase 3D Part 2

This extends the approved structured outbox; it does not replace local photos, SwiftData, authentication or the ranking engine. The development library never connects. No public/social media, signed/public URLs, original Photos assets, video, camera, new photo UI or background-execution service is introduced.

## Local and cloud responsibilities

LocalPhotoStore still prepares approximately 1200px display and 360px thumbnail JPEGs with its existing compression, UUID filenames and account-specific Application Support root. CookingStore commits the normal domain transaction and durable structured SyncOperation before networking. Photo replacement already creates a new CookingMedia UUID and retires the old one; that behavior is preserved.

Both optimized JPEG variants are backed up without recompression. Keeping the small thumbnail avoids different encoder output across devices/OS versions and makes exact byte recovery verifiable. There is no full-resolution asset upload or thumbnail generation service. Each variant is limited to 2 MiB; larger/corrupt local files retain their local data and report review needed rather than silently changing compression.

The private `cooking-photos` bucket accepts only image/jpeg. Exact object names are:

```
<permanent-account-uuid>/<media-uuid>/display-<sha256>.jpg
<permanent-account-uuid>/<media-uuid>/thumbnail-<sha256>.jpg
```

UUID path components are lowercase; existing local UUID filenames remain unchanged. Filenames alone are not integrity proof. An immutable `staygrubby.media_backups` row stores both SHA-256 hashes, byte counts, paths, ready state and cleanup acknowledgement. It references accepted structured media. Transfer state is separate from the canonical cooking graph, so byte progress does not change account sync revisions, comparison evidence or scores.

## Authenticated authorization

Migration `20261013043630_private_cooking_photo_backup.sql` adds one authenticated invoker RPC, `api.media_backup(action, manifest)`, over fixed-search-path private code. Actions are list/register/complete/cleaned. The owner comes from a live nonanonymous Auth session, protected auth_account_links and active permanent account. The read-only media_owner resolver never provisions an account. Arbitrary client account IDs, unregistered paths and mismatched immutable descriptors are rejected. Direct client writes to application tables remain denied; every private table retains RLS.

Storage SELECT/INSERT/UPDATE/DELETE policies call an owner/manifest/active-parent helper, not a path-prefix-only check or storage owner_id. A shared account-row lock serializes object authorization with structured apply's exclusive account lock, followed by a live-session recheck. Cross-account paths cannot read, list, upload, overwrite or delete. Revoked, anonymous and invalid sessions fail closed.

SELECT is operation-aware. Authenticated reads/listing and normal upload/upsert are allowed only for active accepted media and its exact registered paths. Signed/public/copy/move/transform/S3/TUS routes are not enabled by these policies. Retirement immediately denies download/list/upload/upsert. Only Storage delete/delete_many operations may select retired objects for cleanup. DELETE requires retirement. No production SQL deletes Storage object catalog rows; physical cleanup uses the authenticated Storage API.

## Durable upload and retry

CookingSyncCoordinator connects the photo adapter only to the ready account tree. SessionCookingPhotoTransport checks the captured account generation and cancellation before/after each backend suspension; SDK calls also check current identity. Sign-out, account switching and inactivity cancel the worker. Existing triggers remain local commits, readiness, foreground, connectivity recovery, bounded retry deadlines and explicit Profile Retry.

After accepted structured work and safe incoming reconciliation, CookingPhotoSync discovers accepted manifests/tombstones and active local media. It checkpoints discovery/transfer attempts in account-root CookingPhotoTransfers.json using atomic writes, scoped owner IDs, exact manifests, fixed diagnostics and bounded 2–300 second backoff. Missing creator bytes use a pending deadline. No credentials or arbitrary SDK error text are written. State can also be reconstructed from active local files and durable cloud manifests after restart; it never scans/adopts guest/development files.

For local media without a manifest, validate both optimized JPEGs and register their immutable hashes/sizes. Upload both deterministic paths using authenticated SDK upsert, then download each uncached and compare exact bytes. Only after both checks does complete verify catalog presence, sizes and MIME types and acknowledge readiness. A lost upload or completion response safely retries the same paths/content; duplicate domain records/revisions are not created. The server catalog cannot hash S3 bytes itself: client read-back and restore SHA-256 validation provide content verification, while the server enforces immutable expectations and catalog completeness.

Local domain mutation during a suspended transfer invalidates its media snapshot. The worker stops using the retired identity, preserves retry state, flushes the subsequent structured operation and discovers its cleanup/new-media work. Stale structured revision conflicts retain local changes and block photo work; no new conflict merging/rebasing is implemented.

## Incoming recovery and local display

Account readiness still requires the verified structured graph, not synchronous photo downloads. Missing photos use existing placeholders while byte recovery is pending. Active remote manifests must belong to the current account, match the media UUID and exact deterministic paths, and be ready. Pending/unregistered bytes cannot produce a successful restore verification or overall up-to-date status.

Downloads validate hash, size, JPEG completeness/full decode, display dimensions and existing resolution limits. Both variants are validated before either atomic file write into the selected account media root; filenames/symlinks cannot redirect writes. Interrupted pairs are detected and repaired. Failure does not corrupt or discard the structured graph. Model identities/order/relationships remain unchanged and hydration generates no uploads. Successful reconstruction sends a root/media-scoped notification so existing DishPhoto views reload local files; there is no separate network-image rendering path.

Ready local files with matching hashes need no repeated download/upload. Server catalog discovery downgrades missing/wrong-size objects to pending. A fresh device waits when the original device has not yet backed up its bytes. Pending downloads/retries survive termination and resume through the same conservative triggers.

## Replacement, deletion and cleanup

Structured tombstones remain authoritative. New replacement UUIDs get new immutable object paths; stale operations cannot overwrite the replacement. The manifest retains retired paths even after the attempt/dish is deleted. Reads/uploads are denied immediately on retirement, including before physical cleanup succeeds.

Every connected worker discovers retired, uncleaned manifests, removes their pair with Storage.remove, then requests cleaned acknowledgement. The server refuses acknowledgement while catalog objects remain or media is active. Duplicate/missing-object cleanup is safe, and completed manifests/structured tombstones remain as history. If the app is offline/terminated, cleanup resumes on a later authenticated foreground/recovery; no autonomous janitor is added. Temporary retry orphans stay private and inaccessible. Registered identities/paths remain reserved even after cleanup. Remote hydration also removes the retired locally known files after successful graph application. Unindexed legacy local orphan files are not blindly enumerated/deleted.

## Profile and Debug verification

Cooking data up to date is emitted only after structured reconciliation and all discovered photo backup/restore/cleanup work complete. Pending or failed photo work uses the existing pending/review/sign-in status and Retry; Rankings has no new indicators. A missing/not-yet-backed-up photo cannot be silently labelled fully backed up.

Verify fresh restore (development) now creates a new isolated account store AND media root, restores the graph twice, downloads/validates/installs both variants twice, reads reconstructed files back, verifies relationships/no outbox, and removes only its scratch directory. It uses the real current authenticated adapter but never registers, uploads, cleans remote objects or mounts/replaces the primary store. Success includes the photo count. The whole verifier remains compile-time excluded from Release.

## Validation boundary and deferred work

See PHASE_3D_PHOTO_SYNC_REVIEW.md for exact counts/evidence and the passed iPhone data-path verification. Local Swift tests exercise real optimized JPEGs, disk stores, hashes and asynchronous failures. Backend tests exercise real SQL/RLS/locks with disposable Storage catalog stubs; hosted tests exercise actual functions/policies inside a rolled-back transaction with synthetic SQL claims/catalog fixtures, not Auth token issuance or actual S3 byte transfer. The user has now passed real authenticated upload → fresh restore → replacement → fresh restore → deletion → zero restore/no resurrection on the physical iPhone. See the dated physical results in PHASE_3D_PHOTO_SYNC_REVIEW.md. The brief pending status while staying in the dish flow is recorded as later startup/in-flow UX polish; no sync redesign or correctness fix was required.

Automatic conflict resolution, large-library pagination/batching, transfer parallelism, original assets, remote resizing, public/social media, background execution, tombstone/receipt/manifest compaction, arbitrary local orphan cleanup and coordinated account erasure remain deferred. Concurrent signing-out requests may already have been accepted remotely; retained manifests make later reconciliation/cleanup deterministic. Offline use cannot verify remote session revocation. The existing cold-start authentication transition remains future startup-UX polish.
