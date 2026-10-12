# Phase 3C Part 1 — account provisioning foundation

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
