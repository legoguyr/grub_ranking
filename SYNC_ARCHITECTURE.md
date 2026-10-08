# Phase 3B private synchronization foundation

The app continues to launch as a local guest. There is no real authentication, Supabase client dependency, configured project, automatic sync worker, account UI, cloud photo transfer, or social functionality. The existing cooking UI and all ranking-engine implementation remain unchanged.

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

Backend/schema.sql is an unapplied declarative Supabase foundation, not a fabricated migration history or connected project. It includes accounts, private Auth links, minimal owner-only profiles, account libraries, rankings, dishes, full Sources, items, attempts, comparisons, tags/memberships, media metadata, operation receipts and import state. It has account-scoped keys/FKs, one active global ranking, separate observation UUIDs, immutable ownership/identity/evidence and server stamping/version fields. Username uniqueness is case-insensitive, but no rename, alias, reservation or recycling policy is implemented.

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
