# Current Phase 3D Part 2 — private photo sync

The authenticated foreground worker now complements the structured durable outbox with private optimized-JPEG backup, validated account-root recovery and retired-object cleanup. Existing metadata/evidence/revision/conflict behavior is preserved. Both display and thumbnail variants use immutable account/media/SHA-256 paths; Profile only reports fully current after byte work completes. See MEDIA_SYNC_ARCHITECTURE.md and PHASE_3D_PHOTO_SYNC_REVIEW.md for the authoritative current design, security, limits, validation and pending physical-iPhone approval. Earlier structured-only media boundaries below describe the completed Part 1 checkpoint.

---

# Phase 3D Part 1 — private structured cooking sync

Production retains required native Apple authentication, permanent-account resolution and ready account-store gating. There is no production guest/demo mode. Current navigation is Rankings and Profile; Feed remains hidden. The historical foundation sections below are superseded by this current implementation.

## Responsibilities and operation lifecycle

SwiftData remains the working store. CookingStore/RankingStore capture a baseline, stage the existing narrow SyncChanges payload and tombstones, and save domain changes plus the durable SyncOperation atomically. A post-save notification schedules work without waiting for network. No observer uploads arbitrary model edits, and hydration never creates an operation.

The immutable envelope contains operation UUID, installation/store UUID, permanent account UUID, kind, exact JSON bytes, SHA-256 hash, expected accepted revision and predecessor operation UUID. SyncDispatcher uses a separate ModelContext, validates scope/hash before transport, sends serially, and acknowledges only a validated durable server receipt. Failed or ambiguous sends retain the original payload/UUID and persisted bounded retry state. SDK/server error text is never stored; diagnostics are fixed codes. Receipts and deletion markers remain for causal history; safe compaction is deferred.

Acknowledgement advances the accepted snapshot by replaying only the acknowledged delta against its accepted base. Later pending edits are excluded. This retains a correct offline-ready base through restarts rather than clearing it. A previously ready account with pending work mounts its validated local store even when cloud revision advanced; the worker reconciles receipts or reports a conflict without overwriting local work. Fresh/unready accounts still require verified server initialization/restoration.

## Authenticated server path

Migration `20261013022348_structured_cooking_sync` adds the authenticated invoker `api.apply_cooking_operation(envelope jsonb)` over a private fixed-search-path definer. Ownership comes from the existing protected Auth link/live-session resolver, not the supplied account UUID. Per-identity provisioning and the account row lock serialize requests; live session validation is repeated after the account lock wait. Private tables retain RLS and denied anonymous/direct client writes.

The server recomputes the hash from original decoded bytes, verifies exact duplicate-envelope identity, validates expected revision or the accepted predecessor from the same installation, and applies fixed entity mappings. Deletions mark only the specified rows first, then narrow upserts and attempt-level membership replacements occur. Active parent relationships, Source inverse relationships and global-item/attempt integrity are checked before revision advancement and receipt insertion. Constraints enforce immutable comparison observations, ownership/IDs, one global ranking and active Source/version uniqueness. Global library/ranking deletion and library-pointer reassignment are forbidden. Every accepted operation advances the account revision once; duplicate retries return the stored receipt without changing domain rows or revision.

`api.open_account_library()` remains the full owner-derived restore/bootstrap RPC. Its private implementation now shares the account lock with applies, returning a consistent receipt and complete active graph plus deletion references. There is no whole-library replacement apply, caller-selected owner, server ranking engine, signup import or guest adoption.

Migration `20261013023939_snapshot_numeric_fidelity` pins `extra_float_digits=3` on the snapshot function. Hosted integration found the management session default was 0, which rounded JSON Double timestamps. This function-local setting preserves exact domain timestamps/cache values without changing stored values or ranking mathematics; local/native tests exercise the same low-precision caller setting.

The apply limit is 8 MiB decoded payload and 20,000 changed/deleted references per operation. Rejection retains local data and needs review; future oversized-operation batching is not implemented.

## Restore, edits, deletion and conflicts

The existing typed export/hydration covers library/global ranking, dishes, all Source fields, attempts, ranked items, comparison observations, tags, memberships, media metadata and legacy date archives. Reference dates remain numeric Doubles, UUIDs and diagnostic bytes remain stable, and UUID tombstone keys normalize consistently across SQL/Swift casing. Complete hydration validates ownership, revision, graph and retained deletion identities before saving. It rejects pending operations/dirty contexts, preserves existing objects where possible, reconnects relationships and generates no outgoing echo.

Canonical ranking inputs are UUID-based comparisons, individual repeated observations, tie/winner outcomes and timestamps. Strength, uncertainty and diagnostic values are compatible on-device caches carried exactly for continuity. Rank numbers/display scores remain derived by existing local behavior. No evidence is regenerated, pair collapsed, strength averaged, score assigned or ranking algorithm changed by sync.

Source/notes/Course/Contains/Avoid/Dietary/custom tags and version edits retain ranking identities and evidence. Deletion uses existing domain cleanup and local refitting, then syncs the affected tombstones/cache updates. The server retains deleted identities, rejects resurrection, and returns tombstones on restore. Raw SQL row counts therefore include retired records; active counts use `deleted_at is null`. Unused shared tags remain according to existing domain rules. Attempt memberships can be selected again on a live attempt, but deleted domain identities cannot be revived.

Account-level optimistic revision checks deliberately reject overlapping offline device edits. The entire operation rolls back on conflict; local graph/outbox remains intact, and Profile shows a small reconciliation status. Permanent conflict/rejection/authentication diagnostics do not enter an automatic retry loop. Explicit Retry retries the same immutable request; it cannot silently rebase a stale operation. Automatic merging, a backed-up manual resolution workflow and complex conflict UI are deferred. No last-write-wins overwrite is implemented.

## Lifecycle and isolation

One worker connects only to a verified, ready account/store. Triggers are account readiness, successful local domain commits, foreground activation, connectivity recovery, bounded retry deadlines and Profile Retry. Notifications coalesce for 250 ms; there is no polling loop or background-execution expansion. Inactive/sign-out/unmounted account trees cancel work and timers. Coordinator and SDK identity checks before/after transport prevent another account's operation or stale reply from mounting/acknowledging data. A server-accepted request cancelled before local acknowledgement remains safely retryable later.

Incoming hydration waits while a cooking form/detail flow holds its lifecycle lease or the working context is dirty. A detail retained behind another tab keeps its lease until the destination lifetime ends; hiding it cannot invalidate its stored models. Outgoing committed changes may continue. This prevents a fresh graph from invalidating a ranking/re-ranking/editing draft. Profile supplies unobtrusive status and Retry; Rankings rows are unchanged. The Debug development library remains unbound/disabled and never connects a transport. Its store/media/fixtures remain independent of real account stores and cloud data.

Offline already-ready accounts keep local edits/outbox and the prior verified owner mapping, under the existing unexpired-session policy. First authentication/initialization still requires connectivity. Offline operation cannot establish remote revocation. Real account edits synchronize automatically on recovery; no production guest fallback is introduced.

## Media boundary and safe manual restore verification

Only CookingMedia identity, relationships, filenames, dimensions/order/kind/date metadata syncs. No JPEG bytes, Storage bucket/object, CDN, remote thumbnail generation or image download is implemented. Another device uses the existing placeholder when bytes are absent. Incoming metadata deletion does not perform remote object cleanup; media transport/orphan management is deferred.

Authenticated Debug Profile offers **Verify fresh restore (development)** after pending work clears and local/cloud graphs match. It restores the full server graph twice into a newly named temporary account directory, compares every canonical field/identity/evidence/cache/relationship, checks no outbox work exists, and removes only that scratch directory. It never selects/replaces the primary store or uploads. This is compile-time excluded from Release and is not a guest/authentication bypass. A second physical device is still the preferred manual cross-device validation.

## Validation and manual review

See PHASE_3D_SYNC_REVIEW.md for final test/build/security/hosted results, preserved development-store evidence and the reference physical-iPhone procedure. The real account is not an automated fixture. Hosted SQL tests use isolated temporary Auth/session/account records inside an explicit rolled-back transaction; they emulate authenticated claim context and test actual hosted functions/RLS, not Apple token issuance or a real user's HTTP session. The user subsequently passed the real physical-iPhone create/edit/delete test with automatic sync and repeated scratch restore, without Retry. Final hosted state has zero active cooking records, one soft-deleted dish/attempt/item each, three durable receipts and revision 4; Storage remains empty. A second physical device remains additional manual coverage.

---

# Historical Phase 3B private synchronization foundation

Current project/application identity: **StayGrubby**, `com.guyrettig.StayGrubby`. Guest/account store layouts and sync behavior are unchanged by the rename; see `PROJECT_RENAME.md`. Earlier scheme names and setup limitations in dated validation sections are historical.

The app continues to launch as a local guest. The Supabase SDK and explicit account/session foundation are now present; there is no native Apple login, automatic sync worker, account UI, cloud photo transfer, or social functionality. The existing cooking UI and all ranking-engine implementation remain unchanged.

## Local store boundary and startup

`LocalStoreScope` distinguishes guest from the permanent internal StayGrubby account UUID. Guest startup retains the existing default SwiftData store and Application Support/StayGrubbyMedia location. Explicit account sessions use `StayGrubbyAccounts/<account UUID>/cooking.store` and an independently selected media root. An explicit test root also isolates guest sessions; tests never need the default development database.

`SyncStoreBinding` records the local installation/store UUID independently of its owning account UUID, whether journaling is enabled, whether restoration is required, the accepted server revision and the last accepted snapshot. No Auth/provider identifier is used as an owner.

New account sessions are blocked by `CookingStore.prepare` until `LocalStoreSession.restore` validates/applies an accepted graph. An accepted complete empty snapshot or explicit `initializeVerifiedEmptyAccount` authorizes initialization of an empty ranking. Phase 3C must obtain the server's verified-empty state before using either path; a missing response or partial page is not an empty snapshot. Cached restored accounts can open locally/offline without repeating restoration. `LocalStoreStartup.openGuest` preserves current startup; Home's existing idempotent prepare remains safe behind the readiness guard.

Mount sequence for Phase 3C: resolve authenticated internal account → select its session/root → restore if required → validate → prepare idempotently → mount ContentView with that container. Never mount a fresh account directly into Home before restoration. Account changes must cancel the previous worker, unmount its models/navigation and use another container. Guest adoption/registry routing, real session verification and account switching UI remain Phase 3C work; no ownership reassignment is performed now.

## Transfer graph and fidelity

`CookingGraph` and explicit typed records cover CookingLibrary, all internal RankingLists, Dish, CookingAttempt, RankedItem, Comparison, every DishSource field, CookingTag and memberships, ordered CookingMedia metadata, deletion references and the legacy starter Item's timestamp values. Source's seven storage codes and nullable hidden legacy fields remain intact. All four tag kinds remain distinct; no Free-to-Contains conversion occurs. The one global ranking pointer remains authoritative; hidden historical lists are not merged.

Dates encode as numeric seconds since Swift's reference date, preserving their original Double representation. The SQL foundation uses double-precision reference-date fields for these domain dates, separate from server timestamps. UUIDs and full-precision caches round-trip; diagnostic bytes encode losslessly as Data/base64. Transfer records do not contain PersistentIdentifiers, container paths, media roots or absolute media filenames. Filenames must be safe leaf names. Media bytes are deliberately separate from the graph.

`CookingGraphExport` reads values without saving or fitting. Validation rejects duplicates, invalid relationships, cross-list/self comparisons, impossible tie/winner data, non-finite metrics/dates, unsafe paths and deleted/live identity intersections. It does not infer names, sanitize away legacy metadata, collapse pairs or generate rank numbers. Encoded arrays are canonicalized for deterministic receipts/snapshots.

## Local mutations and durable outbox

Only explicit CookingStore/RankingStore transaction boundaries journal local writes. There is no global hydration flag, model-observer hook or property-didSet uploader. Unbound/disabled guest stores generate no operations. Enabling an account's journal requires a ready, valid graph.

The existing services capture the pre-mutation graph and stage a narrow change set (changed entity records plus deletion references) immediately before their existing context.save. The domain write, operation and local tombstones share one save/rollback. Existing media file rollback/cleanup ordering is retained.

SyncOperation persists its immutable operation UUID, store/account UUIDs, local sequence, type, affected entity keys/payload, SHA-256 payload hash, expected accepted revision, predecessor operation UUID, creation time, retry count/deadline/error and acknowledgment. Entity upserts carry existing record IDs, especially Comparison UUIDs. An edit's tag memberships are an attempt-level replacement, not independent guessed merges.

This is a conservative account-revision/causal-chain foundation, not completed multi-device conflict resolution. A server transport must verify the expected revision or accepted predecessor receipt, reject conflicting payload reuse, preserve pending work on conflicts and never treat cached scores as an overwrite authority. More granular row-version rebasing may be implemented in Phase 3C after the RPC contract is tested.

`SyncDispatcher` is explicitly invoked through a Sendable SyncTransport interface; no production network adapter is installed. It uses a private ModelContext so awaiting a failing request cannot roll back the caller's unsaved edits. It sends in local sequence order, persists retry state with bounded backoff, stops on failure, and retries the same envelope. Acknowledgments validate operation/store/account/payload identity and order; identical repeated receipts are no-ops. Acknowledged rows are retained for causal history in this foundation.

## Remote hydration

`CookingGraphHydration.apply` is a separate full accepted-snapshot path. It validates ownership, revision, graph and tombstones before mutation, and rejects a dirty context or pending local operations rather than silently overwriting them. It upserts existing IDs, reconnects inverse relationships, prunes records missing from the complete snapshot, and saves atomically. Constructors can receive explicit restored UUIDs; no insertion/ranking session runs. Reapplying the same accepted state preserves identity and produces no uploads. A changed snapshot using an already accepted revision is rejected.

The input must be a complete graph, never a page or arbitrary partial patch. Phase 3C must fetch a consistent server snapshot and defer hydration while a ranking/re-ranking draft is active. Pending-operation conflicts require explicit reconciliation; this phase deliberately rejects rather than implements a lossy merge.

## Deletion and ranking

SyncTombstone is separate from visible cooking models. Local deletion diffs capture removed cook/item, incident Comparison, media and final-Dish/Source identities before the domain save removes them. They survive restart and acknowledgment; there is no short retention period or automatic resurrection. Accepted remote tombstones are retained as well. Stale revisions and snapshots containing locally deleted identities are rejected as a whole. Full remote snapshots can remove records without echoing outbox operations.

The existing deletion still removes every incident edge, retains other versions and unused shared tags, and refits through the unchanged ranking engine. Export/hydration copies compatible ranking caches exactly and never averages them. Comparison evidence remains authoritative; repeated pair observations and half-win ties remain separate records. Skip/Undo/incomplete draft actions remain value-only. A future legitimate merged evidence graph must use the existing local engine for recomputation; no server fitting or social signal is introduced.

## Media boundary

LocalStoreSession exposes the selected media root. Existing LocalPhotoStore APIs already accept a rootURL/mediaDirectory, so the account-specific root can be passed explicitly without persisting an absolute path. Guest roots/optimized JPEG strategy remain unchanged. Phase 3C must mount/pass the selected root consistently; the current app offers no account UI yet. Photo upload/download, transfer queues, cloud byte verification, orphan cleanup and downloaded cache eviction are Phase 3D work. The metadata tombstone prevents logical resurrection; actual remote object cleanup is not implemented.

## Backend artifacts and security

Backend/schema.sql is a first-install reference for the tracked Supabase migration chain. The hosted project was initialized on October 11, 2026; see supabase/README.md for applied versions, security verification and the intentionally private API boundary. It includes accounts, private Auth links, minimal owner-only profiles, account libraries, rankings, dishes, full Sources, items, attempts, comparisons, tags/memberships, media metadata, operation receipts and import state. It has account-scoped keys/FKs, one active global ranking, separate observation UUIDs, immutable ownership/identity/evidence and server stamping/version fields. Username uniqueness is case-insensitive, but no rename, alias, reservation or recycling policy is implemented.

All tables have RLS. A narrowly scoped private security-definer helper resolves auth.uid through protected Auth links and active account status; no editable user_metadata authorizes ownership. Authenticated clients have owner-only reads and no direct domain/receipt/version writes. Anonymous reads and Auth-link reads are denied. The staygrubby schema is not automatically exposed to the Data API. There are no service/admin credentials, storage policies/buckets or social tables.

Before hosted deployment, Phase 3C must supply and test account provisioning/linking, atomic authenticated mutation/import/snapshot RPCs, receipt validation, account revision locking, active-parent/tombstone checks, JWT/session validation, explicit API exposure/grants and privileged deletion. This foundation does not claim end-to-end Supabase transport, real authentication or conflict resolution.

Backend/tests executes the schema and RLS/constraint tests on pinned PGlite (PostgreSQL WASM). It stubs only auth.users and auth.uid's verified-JWT boundary in a disposable database. This meaningfully exercises PostgreSQL policies/privileges and constraints, but is not a test of Supabase Auth, PostgREST, network sessions, Storage or deployment permissions. Run npm ci --ignore-scripts then npm test in Backend/tests; npm package/lock files apply only to test tooling.

## Validation

SyncFoundationTests uses isolated memory/disk stores for guest launch, accounts A/B, restoration gating, exact graph round trips, UUID/evidence/cache/Source/tag/media/date fidelity, repeated/tie observations, idempotent/no-echo hydration, local operation counts, rollback, disk reopen, lost acknowledgment retry, invalid snapshots/receipts, deletion/anti-resurrection, all Source codes and separate media roots. Existing cooking/ranking/UI suites are retained. Final results and saved-store verification are recorded after the complete run below.

### Final validation — October 8, 2026

The complete Grub Ranked scheme passed serially on iPhone 17 / iOS 26.5 Simulator: **94 tests / 120 parameterized and configuration executions, zero failures, unexpected failures, expected failures or skips**. This comprises 80 unit functions / 105 executions and 14 UI functions / 15 appearance/configuration executions. The 17 new sync functions / 22 executions all passed, including lost-response retry after reopen, no-echo remote deletion and preservation of another context's unsaved work. No existing UI test was modified. A focused test's initial relationship-array comparison was corrected to compare caches by UUID and actual global ranking order; no ranking behavior changed.

The pinned PostgreSQL WASM harness passed **28 schema/RLS assertions**. It is an isolated PostgreSQL policy/constraint test, with explicitly simulated Auth UID mapping—not a hosted Supabase/Auth/PostgREST/Storage integration result. The schema is unapplied. No hosted resource, credential, Apple capability or production network worker was introduced.

The final app build/normal guest launch succeeded. Exact semantic-field/relationship comparison against the consistent pre-change checkpoint confirms **1 RankingList, 12 Dishes, 15 CookingAttempts/RankedItems, 356 Comparisons, 10 Sources, 21 tags / 48 memberships, zero media**. IDs, names, dates, strength/uncertainty caches, diagnostic bytes, comparison observations and all associations remain unchanged. SQLite integrity passes. The three additive sync tables have zero rows in the real guest store; no test data or account binding leaked into it. Existing database/media locations were retained.

All 26 previously tracked engine, screen/design-system and Xcode-project files match their pre-phase hashes. Model constructor additions and service transaction hooks are the only domain/persistence adapter changes. `git diff --check` passes. Local checkpoint, semantic hashes, test summaries and the full 25-file inventory are retained under ignored `.local-backups/phase3b/`. Nothing is staged, committed or pushed; Phase 3B awaits manual review.

## Phase 3C setup checkpoint — October 11, 2026

The empty hosted project `lgjxbpycphhsswxoncmz` now has the 15 private foundation tables and reviewed grants/policies, with two tracked migrations matching hosted history. No account or guest-data adoption occurred. SupabaseClient.plist centralizes only client-safe configuration; no SDK, Auth provider or network worker is installed. `supabase/README.md` records the 40 local-equivalent assertions, hosted catalog/REST checks, build result and remaining authenticated integration work. Phase 3B validation above is historical; the setup work remains uncommitted/unpushed.

## Phase 3C Part 1 account boundary

See ACCOUNT_ARCHITECTURE.md. The new coordinator is injected at the app root but initially stays guest and lazily constructs its SDK backend only when session restoration is explicitly requested. Only a valid provisioning receipt can authorize preparation of the permanent-account store. Preparing it does not call prepare/initializeVerifiedEmptyAccount, hydrate, enable journaling or mount account data. No existing cooking/ranking/UI source was changed; guest adoption and actual store switching remain deferred. Ordinary local sign-out invalidates pending work and prepared routing, cancels observation and calls the SDK's local-scope sign-out without erasing account files or cloud data.

### Part 1 final validation

The complete scheme passed on iPhone 17 / iOS 26.5: **108 test functions / 136 configured executions, zero failures, expected failures or skips**. This comprises 94 unit functions / 121 executions and 14 UI functions / 15 executions. The 14 new account-session functions / 16 executions all pass, including identity-switch/stale-reply protection. Existing tests were not weakened or changed. Result bundle: /private/tmp/grub-phase3c-part1-full.xcresult.

PostgreSQL validation passed **59 PGlite schema/security assertions and 13 native PostgreSQL concurrency/transaction assertions**. Hosted migration hashes match all four repository files; private/helper/API grants and exposure are verified, anonymous provisioning is rejected, and hosted Auth users/accounts remain zero. Advisors have no warnings/errors, only the deliberately inaccessible Auth-link policy notice and unused indexes in the empty database. No real authenticated hosted success/provider-token exchange is claimed.

Final build/normal guest launch succeeded with zero reported build warnings/errors; the saved Rankings UI was visually checked. Every original development-store semantic field/relationship matches the consistent pre-task snapshot: **1 global RankingList, 12 Dishes, 15 CookingAttempts/RankedItems, 356 Comparisons, 10 Sources, 21 tags / 48 memberships, zero media**. SQLite integrity passes; all three sync tables remain empty in the guest store. The 40 protected cooking/ranking/engine/UI files are byte-for-byte unchanged. SupabaseClient.plist is unchanged and correctly bundled. Credential checks found no real privileged value; a forbidden-key string appears only as a negative configuration test. Backups, test dependencies and local Supabase state remain ignored.

`git diff --check` passes. Part 1 has 18 intended modified/new files, none staged/committed/pushed. Apple-dependent setup/login remains deferred pending enrollment activation. Manual review should confirm ordinary/offline guest Rankings, search/filter/version detail and canceled New Dish/New Version drafts; there is intentionally no new authentication UI yet. Use AccountSessionTests for foundation state/routing/sign-out review.
