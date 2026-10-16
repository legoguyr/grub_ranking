# Integrated account presentation — October 15, 2026

The onboarding and cooking-focused Profile presentation were integrated without changes to Apple/Supabase services, account resolution, store readiness, session restoration, sign-out or sync contracts. AuthenticationGatePresentation is copy/recovery-action projection only. ProfileSnapshot reads eligible global entries through ScoreUnlockPolicy; it cannot grant access, fit rankings or mutate the graph. ProfileAccountReview is an explicitly isolated DEBUG-only subtree with disposable account/backend state, absent from Release.

Current release: user-confirmed 1.0 (1) Internal Only upload succeeded. The integrated build still needs physical review. Coordinated account erasure/revocation remains unimplemented; sign-out/dish deletion is not account deletion. Future usernames, public profile concepts and friendship/privacy work are planning in STAYGRUBBY_MASTER_ROADMAP.md, not current behavior.

# Current Phase 3D Part 2 account boundary

Required Apple authentication, permanent-account resolution and verified account-store readiness are unchanged. The ready account tree also injects an authenticated photo adapter guarded by the exact account generation before/after suspension. Sign-out/account switching cancel work; Debug/demo never connects. Structured readiness permits usable placeholders while private photo recovery runs separately. See MEDIA_SYNC_ARCHITECTURE.md and PHASE_3D_PHOTO_SYNC_REVIEW.md; earlier statements deferring byte transport are historical.

---

# Current Phase 3D Part 1 sync integration

The authenticated ready account tree now connects the existing durable outbox to the authenticated structured apply/snapshot RPCs. Local mutations remain immediate and offline-capable; metadata/evidence/identities synchronize separately. No guest adoption, photo-byte transport or social navigation is introduced. Pending local work survives startup and revision conflicts; account switching/sign-out cancels the prior worker. See SYNC_ARCHITECTURE.md and PHASE_3D_SYNC_REVIEW.md for lifecycle, fidelity, limitations and manual verification. The account/authentication architecture below remains applicable except earlier statements deferring structured outgoing transport.

# Phase 3C Part 2 — final required authentication and account libraries

Production flow is Launch → onboarding → native Sign in with Apple → Supabase authentication → permanent StayGrubby account resolution → restore existing account or initialize a verified-empty new account → ready authenticated app. New real accounts start empty. Feed is hidden; current personal navigation is Rankings and Profile. No production guest mode exists. Hosted Auth enables only Apple; the unused Email/password provider was disabled with user approval during the final security review.

The first physical-iPhone Apple test and repeated sign-in were manually verified successfully. The displayed permanent account ID stayed unchanged, new Rankings contained zero dishes, and Sign Out returned to onboarding. Read-only hosted verification found exactly one Apple/Auth identity, one account/link/profile and one owned empty library/global ranking, with revision 1 and no cooking data. No identity/token values are documented here. See AUTHENTICATION_GATE_REVIEW.md for final automated/security evidence.

V1 has no user-facing guest personal application. `AccountApplicationRoot` constructs onboarding until the SDK session is authenticated, the permanent account receipt is validated, and `AccountLibraryAccess` has a ready store for that exact Auth/account pair. The personal tree is conditional, not behind a dismissible sheet. Pending/error/sign-out states unmount it immediately. The internal historical `.guest` session enum now means logged out; it grants no production data access.

Onboarding is a single semantic dark/light SwiftUI screen with the canonical wordmark, “Your cooking, worth remembering.”, a comparison example, Apple's native control, and safe loading/retry/sign-out states. There is no guest, skip, dismiss or fake credential path. The Apple control stays mounted through authorization. The existing secure nonce/ID-token flow is preserved. Authenticated Profile shows account status and Sign Out; it no longer offers optional authentication.

## New and existing account libraries

`api.open_account_library()` is a parameterless authenticated invoker wrapper around a private fixed-search-path definer. It reuses `staygrubby.provision_account()` to derive Auth identity, verify the live session after the advisory lock, and select the protected permanent account. No caller owner or imported graph is accepted. The only writes are a new empty global ranking/library and one revision increment for a genuinely uninitialized account. Any existing cooking rows without a library cause an error rather than reset. Existing or deleted libraries are never replaced. Concurrent/retried calls return identical ranking/library IDs and revision.

One transaction returns the current validated account receipt and a complete Swift transfer graph of active records, relationships, soft-deletion references, reference-date doubles and base64 diagnostic bytes. Existing graph data is restored via `CookingGraphHydration`, then prepared through the existing store path. A brand-new account hydrates precisely one ranking/library and zero dishes, attempts, items, comparisons, tags, sources, photos or legacy archives. There are no sample/template records. Missing photos use existing placeholders; remote photo-byte download/backup remains deferred.

`AccountLibraryAccess` opens only `StayGrubbyAccounts/<permanent UUID>/cooking.store`, validates its binding/graph/revision and rejects stale async replies. Auth UUID never owns cooking. Same accepted cloud base preserves local changes/outbox entries; a different remote revision with pending local changes fails closed for later conflict handling. Readiness precedes the root model-container mount. All production photo reads/writes/deletes explicitly inherit that store's media root, including presented forms and old asynchronous view tasks. No account photo operation falls through to the demo directory.

The existing journal is enabled for real-account edits so changes remain durable in the local outbox. This task initializes/restores cloud library structures; it does **not** activate the future outgoing cooking-operation transport. Local edits therefore remain device-local/queued until that transport is implemented. No development graph/file is sent to either RPC.

## Offline policy

SDK sessions remain in the SDK's Keychain storage. A separate `ThisDeviceOnly` Keychain record stores only a previously server-verified permanent receipt after library readiness, not tokens/nonces or an editable preferences UUID. On launch, a missing session or failed/expired-session refresh stays at onboarding. For a valid unexpired SDK session whose provisioning request fails with a connection error, a matching ready cached receipt may resolve the account. Auth/server denials, wrong identity, invalid/uninitialized receipts and missing caches do not qualify.

Offline mounting further requires that exact account's existing binding, completed restoration, accepted snapshot and valid local graph. It never initializes a new account offline, opens another account or falls back to demo data. Already-open personal data stays local while disconnected; relaunch with an expired session requires online refresh. Server revocation cannot be checked while disconnected; offline access is limited to the previously verified device session and owner. Sign-out removes this mapping and the SDK's local session, cancels/invalidate work, and returns to onboarding. Account files/cloud rows remain.

## Development/demo boundary

The preserved default store is now development/demo fixture data: 1 ranking, 12 dishes, 15 attempts/items, 356 comparisons, 10 sources, 21 tags, 48 memberships, 190 media files. It is not a first-account adoption candidate. No automatic adoption/upload path exists. It is never opened by the production root.

`DevelopmentLibraryAccess`, its launch flag `--development-library`, fixture selector, open/exit controls and coordinator review method are all inside `#if DEBUG`. Normal Debug launch still shows onboarding. Explicit launch or the labeled Debug button opens the unchanged demo store; valid existing `--ui-test-store UUID` opens only its isolated fixture. Direct review launch avoids constructing/restoring Auth. Entering review suspends observation and cannot run during authentication/provisioning. Review performs no session creation, account provisioning, owner impersonation or cloud upload. Real session and demo paths cannot cross. Release contains neither the review type/entry symbols nor the flag/button strings. TestFlight/App Store use Release; keep DEBUG absent from those build configurations.

The Debug Demo Library may be empty on a physical development iPhone because its device-local store is separate from the Simulator dataset. No automatic seeding or copy is needed. Read-only logged-out public browsing is only a possible future feature requiring a separate design; it is not implemented. Historical Part 1/Part 2 notes follow and are superseded where they discuss optional sign-in, guest presentation or future adoption.

# Historical Phase 3C Part 2 — native Apple authentication

Native `AuthenticationServices.SignInWithAppleButton` is available in the existing Profile tab. Guest Rankings remain the app's default and sole mounted cooking container. Sign-in is optional. The native button stays mounted throughout authorization so loading-state changes preserve its completion-handler lifetime. The account entry shows Apple authorization, SDK authentication, provisioning, safe retry, connected and local sign-out states. The connected state displays the independent permanent account UUID for the first real-account review and clearly states that the guest library has not moved. No account store is opened or initialized by this flow; no sync worker or guest upload is started.

`AppleSignInNonce` uses `SecRandomCopyBytes` for 32 random bytes (256 bits), base64url encoding without bias, and CryptoKit SHA-256. Each request has a fresh UUID and fresh nonce; only its hash goes to Apple. Its private pending raw value is consumed once, including failures, and discarded on cancellation/sign-out. Apple identity-token bytes must be bounded UTF-8 with three nonempty base64url JWT segments. This is structural validation only; the server validates the signature, audience, claims and nonce. The SDK receives `OpenIDConnectCredentials(provider: .apple, idToken: ..., nonce: ORIGINAL_RAW_NONCE)` through `auth.signInWithIdToken`. There is no browser OAuth, custom token store, logging or model/preferences persistence of the Apple token/nonce. Ephemeral wrappers are not Codable and redact descriptions/reflection. The resulting Supabase session uses the SDK's existing Keychain storage and default nil logger.

Successful SDK authentication resolves the parameterless `api.provision_account()` RPC before entering connected state. Receipt correlation, independent owner UUID, revision/version validation and restoration-before-initialization guards remain unchanged. Provisioning failure retains the authenticated identity and supports retry without a second sign-in or guessed ownership. Repeated real sign-ins rely on the existing server-side idempotent link; mocked tests do not establish real provider success.

Root `.task` starts restoration once alongside immediate guest presentation. Missing Keychain session needs no provisioning or network. Expired sessions use SDK refresh; restore/provision failures show a safe retry and leave guest cooking available. Isolated DEBUG review stores skip real session restoration, preserving the existing UI-test/media boundary. Auth changes read the SDK's current identity rather than a potentially stale queued event payload. Generations and cancellation reject late restoration/provisioning replies. Token-refresh events for the same identity do not reprovision.

Local sign-out immediately invalidates routing, pending Apple requests and account work, stops the future-sync seam, cancels observation, and returns to guest. An in-flight SDK token exchange is cancelled and drained before local SDK sign-out so a late response cannot silently persist a new session after cleanup. New sign-in is disabled while that cleanup finishes. The pinned SDK removes its local session before the server logout request; remote failure is reported without restoring access or promising revocation. No Apple revoke, account deletion, cloud deletion or local account-file deletion occurs.

The standard Apple email scope is requested so the identity token can include email for Supabase signup. Callback name/email fields are neither required nor copied into the StayGrubby profile. Full-name scope is omitted; missing callback fields cannot fail a subsequent login, and existing chosen profile names cannot be overwritten. A later explicit profile UI can collect a name. Provisioning still creates only account/link/minimal profile and no library/ranking.

Tests: `AppleSignInTests` covers random/hash/original nonce, redacted diagnostics, malformed tokens, single-use callbacks, secure-random failure, auth/setup retries, repeated identity, launch restore, late SDK exchange cleanup and stale provisioning. `AccountEntryUITests` reviews optional native entry and returning to Rankings at normal and accessibility text sizes. Existing Part 1 and Phase 3B tests preserve routing/restoration/media isolation. See `NATIVE_APPLE_SIGN_IN_REVIEW.md` for validation and the required physical-iPhone/hosted first-account review. Real Apple authorization is never performed by test fixtures.

The following Part 1 notes and results are historical; the Part 2 behavior above supersedes references to absent account UI, no startup restoration or future native sign-in.

# Historical Phase 3C Part 1 — account provisioning foundation

Current application identity: **StayGrubby**, `com.guyrettig.StayGrubby`. The manually configured Apple primary App ID and Supabase Apple Client ID use this canonical ID. Team/entitlement setup is now present; actual Apple login remains deferred. Earlier Part 1 validation/setup limitations below are historical. See `PROJECT_RENAME.md` for the rename and simulator data-preservation boundary.

## Identity and database contract

Provider identity -> Supabase Auth UUID -> protected auth_account_links -> independent permanent StayGrubby account UUID -> owned cooking data. Neither Auth UUID, Apple ID, email, username nor editable metadata is a cooking-data owner.

The single parameterless exposed RPC is api.provision_account(). Its security-invoker wrapper calls the private staygrubby.provision_account() security-definer implementation, with fixed empty search paths and fully qualified references. Authenticated-only EXECUTE/USAGE is explicit; PUBLIC/anon execution is revoked. The trusted database owner supplies narrowly constrained writes through that function; client table write grants remain denied and no extra RLS write policy or signup trigger exists.

The implementation derives auth.uid(), serializes calls by transaction-scoped advisory lock, then checks auth.jwt().session_id against a current matching auth.sessions row, not_after, and a non-anonymous/non-deleted auth.users row. Checking AFTER the lock prevents a session revoked during contention from creating an account. A lock hash collision can only serialize unrelated users, not mix ownership. PostgreSQL rollback includes account/link/profile creation, and repeated/concurrent calls return the protected existing mapping. A deleting account is rejected rather than recreated.

The response is versioned JSON: format_version=1, auth_user_id, account_id, sync_revision, library_state (uninitialized or initialized). Auth identity is returned only to correlate the response with the session used for the request. The app checks identity, format, revision and independent permanent UUID before accepting it.

New provisioning creates only account/link/minimal profile. No account_libraries or rankings row is created. A consistent RPC result explicitly reports uninitialized; absence/errors/partial fetches never authorize empty initialization. Existing library state is preserved. Later adoption/fresh-start/restore logic must decide the library path without generating a duplicate global ranking or replacing guest UUIDs/evidence.

The two Part 1 migrations are 20261012021032_account_provisioning and 20261012021504_provisioning_session_guard. The latter hardens the first without rewriting its applied history. Hosted exposure preserves public/graphql_public and adds only api through supported authenticator-role PostgREST configuration; private staygrubby/auth remain unexposed. The role override must be maintained by migrations, rather than assuming Dashboard exposure changes will replace it.

## App client and session state

Official Supabase Swift 2.55.3 is pinned exactly through Xcode SPM; Package.resolved records dependency versions/revisions. SupabaseClientConfiguration reads the existing bundled plist, accepts only the three approved client fields, validates the HTTPS project URL and publishable-key format, and rejects privileged configuration fields. Environment-specific values are not duplicated in Swift/docs. No new credential is introduced.

SupabaseAccountBackend uses supported SDK Auth storage defaults (Keychain on Apple platforms), default nil logging and local-scope sign-out. Tokens stay within SDK memory/Keychain. They are never placed in the coordinator, SwiftData, preferences, journals, errors shown to users or logs. Future native Apple authentication can use the centralized client's auth interface; no Apple-token acquisition or capability is implemented now. Future sync transport can use this client, but the Phase 3B transport is not activated or replaced.

AccountSessionCoordinator is an Observable MainActor object injected at the app root. States are guest, loadingSession, provisioning(identity), resolved(receipt) and retryRequired(step,identity). Backend construction is lazy and explicit: the normal guest root never constructs a Supabase client, reads Auth state or waits for network. There is deliberately no new account UI or automatic startup restore in Part 1. Future auth UI calls restoreSession after choosing account mode and connects native sign-in to the SDK.

Restoration obtains the supported SDK session and resolves the account through the RPC; cached Auth identity alone cannot authorize an account route. The Auth event observer handles sign-out and identity changes, while token refresh for the same identity does not redundantly provision. Generation checks/cancellation discard stale loading/provisioning replies after sign-out or a different identity. Errors are represented by safe retry states rather than propagating arbitrary SDK/server text. Provisioning failure retains the recoverable Auth context; retry never adopts/uploads guest data.

## Routing preparation

prepareResolvedStore requires a current resolved receipt tied to the active Auth identity, then opens LocalStoreStartup.openAccount using only its permanent UUID. The existing account-specific DB/media paths and binding validation are preserved. It returns/prepares a separate session and never calls CookingStore.prepare, initializeVerifiedEmptyAccount, hydration or SyncJournal.enable. New account binding remains restorationRequired and has zero rankings.

Prepared storage is separate from presented storage. The existing ContentView stays mounted on the original guest container in Part 1. There is no automatic account mounting, guest reassignment, merge, reset or overwrite. Later store switching must restore a complete cloud snapshot or explicitly authorize the verified-empty/adoption path before presentation. Cached account/offline routing and persisted Auth-to-account routing decisions belong to that next stage, not a guessed mapping in this foundation.

## Sign-out

Sign-out first invalidates queued account work and prepared routing, invokes the stopAccountWork hook, cancels Auth observation and immediately returns state to guest. It then calls SDK local-scope sign-out if a backend exists; guest sign-out creates no backend. There is no active sync worker or mounted account UI yet, so the cancellation hook is a safe integration seam for the later worker. The pinned SDK removes its local session before requesting server logout. A network failure sets remoteSignOutFailed, without regranting account access or claiming server revocation succeeded. Account DB/media files and all cloud data are retained. A subsequent account resolution still must match the selected permanent UUID.

Sign-out is not account deletion or Apple authorization revocation. Those require a separate trusted, retryable server workflow later.

## Tests and remaining setup

AccountSessionTests isolates mock Auth/session behavior and temporary guest/account stores. It covers guest use with a failing factory/no network, absent sessions, pending routing denial, failed/retried restoration/provisioning, wrong identity receipts, restoration gating, retained account files, identity changes, stale replies, refresh events, sign-out failure, safe configuration and versioned wire decoding. Existing Phase 3B tests remain unchanged.

Backend/tests applies the complete tracked SQL chain to PGlite with Auth claim/session stubs. 59 assertions cover policy/privilege/constraint behavior and provisioning denial/success/retries. The native concurrency script uses pg 8.23.1 and refuses non-temporary Unix sockets; it creates/drops only its own uniquely named fixture database. PostgreSQL 17.10 ran 13 assertions including 20 real blocked callers, transaction rollback and session revocation during a lock wait. These are genuine PostgreSQL semantics but simulated Auth identities, not real provider/JWT validation.

No hosted Auth/StayGrubby accounts or guest data were created. Hosted migration/catalog/anonymous REST checks verify deployment/exposure/permissions; authenticated hosted success is deferred until real login is authorized. Apple enrollment activation is still required for portal App ID/Sign in with Apple, Xcode entitlement/paid-team signing and physical-device native login. This part adds no team, entitlement, provider setting, real login, adoption, photo backup, social feature or production sync.

Before commit, manually launch the existing guest app, review saved Rankings/search/filters/version selection, relaunch offline and confirm the library remains available. Account state/routing/sign-out is reviewed through the isolated AccountSessionTests until the later auth UI exists. Do not create hosted users just to review this checkpoint. No commit/push is part of this task.

### Part 1 final validation

The complete scheme passed on iPhone 17 / iOS 26.5: **108 test functions / 136 configured executions, zero failures, expected failures or skips**. This comprises 94 unit functions / 121 executions and 14 UI functions / 15 executions. The 14 new account-session functions / 16 executions all pass, including identity-switch/stale-reply protection. Existing tests were not weakened or changed. Result bundle: /private/tmp/grub-phase3c-part1-full.xcresult.

PostgreSQL validation passed **59 PGlite schema/security assertions and 13 native PostgreSQL concurrency/transaction assertions**. Hosted migration hashes match all four repository files; private/helper/API grants and exposure are verified, anonymous provisioning is rejected, and hosted Auth users/accounts remain zero. Advisors have no warnings/errors, only the deliberately inaccessible Auth-link policy notice and unused indexes in the empty database. No real authenticated hosted success/provider-token exchange is claimed.

Final build/normal guest launch succeeded with zero reported build warnings/errors; the saved Rankings UI was visually checked. Every original development-store semantic field/relationship matches the consistent pre-task snapshot: **1 global RankingList, 12 Dishes, 15 CookingAttempts/RankedItems, 356 Comparisons, 10 Sources, 21 tags / 48 memberships, zero media**. SQLite integrity passes; all three sync tables remain empty in the guest store. The 40 protected cooking/ranking/engine/UI files are byte-for-byte unchanged. SupabaseClient.plist is unchanged and correctly bundled. Credential checks found no real privileged value; a forbidden-key string appears only as a negative configuration test. Backups, test dependencies and local Supabase state remain ignored.

`git diff --check` passes. Part 1 has 18 intended modified/new files, none staged/committed/pushed. Apple-dependent setup/login remains deferred pending enrollment activation. Manual review should confirm ordinary/offline guest Rankings, search/filter/version detail and canceled New Dish/New Version drafts; there is intentionally no new authentication UI yet. Use AccountSessionTests for foundation state/routing/sign-out review.

## Part 1 file inventory

Historical inventory at the Part 1 checkpoint, before the StayGrubby project/source/module rename:

- ACCOUNT_ARCHITECTURE.md
- Backend/README.md
- Backend/schema.sql
- Backend/tests/package-lock.json
- Backend/tests/package.json
- Backend/tests/provisioning.concurrent.mjs
- Backend/tests/schema.test.mjs
- Grub Ranked.xcodeproj/project.pbxproj
- Grub Ranked.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
- Grub Ranked/Accounts/AccountSessionCoordinator.swift
- Grub Ranked/Accounts/SupabaseAccountBackend.swift
- Grub Ranked/Grub_RankedApp.swift
- Grub RankedTests/AccountSessionTests.swift
- SYNC_ARCHITECTURE.md
- supabase/README.md
- supabase/config.toml
- supabase/migrations/20261012021032_account_provisioning.sql
- supabase/migrations/20261012021504_provisioning_session_guard.sql
