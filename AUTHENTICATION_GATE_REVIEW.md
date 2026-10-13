# Phase 3C Part 2 — final authentication checkpoint review

## Hosted provider and security verification

Only Apple is enabled in the hosted public Auth settings. The unused Email provider was disabled with explicit user approval during final review; the existing Apple identity/account was not altered. Anonymous sign-ins and manual identity linking remain disabled. No passwords, tokens, raw nonces, private keys or privileged client configuration are introduced.

All 15 private tables retain RLS, anonymous table/API access is denied, direct authenticated writes and identity-link access are denied, and both exposed API wrappers remain invokers over fixed-search-path private helpers. All five hosted migration MD5 hashes exactly match repository SQL, and the first-install schema is their exact concatenation. Disposable backend fixtures pass 69 schema/RLS and 18 native PostgreSQL concurrency/transaction assertions and create no hosted users; the native cluster is stopped afterward.

The hosted advisor has one intentional INFO for the policy-free, client-inaccessible identity-link table and still emits a WARN for disabled leaked-password protection even after Email is disabled. Password authentication is unavailable and no real user has a password or non-Apple identity, so this password-specific advisory is not an active exposure in the current Apple-only product. Supabase documents leaked-password protection as a Pro-plan feature: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection. Review password protection before adding any future password-based authentication. No warning was hidden or monitor disabled.

## Final checkpoint validation

The complete Debug scheme passed **139 test functions / 177 executions** (121 unit functions / 158 executions and 18 UI functions / 19 executions), with **zero failures, expected failures or skips**, on iPhone 17 / iOS 26.5. Result bundle: `/private/tmp/staygrubby-auth-final-debug.xcresult`. This rerun covers native nonce/session security, required account readiness/empty initialization, existing-account restoration, offline restrictions, sync foundation, ranking/cooking behavior, Contains/Avoid and source semantics, portrait configuration, accessibility/review isolation and fixture media isolation.

The Release authentication-gate test passed **1 function / 1 execution** with zero failures/skips, exercising both normal launch and attempted development/fixture arguments. Result bundle: `/private/tmp/staygrubby-auth-final-release.xcresult`. Test products use command-line `ENABLE_TESTABILITY=YES` solely for the existing internal test imports; DEBUG is not defined and project settings are unchanged. Independent ordinary Debug and Release builds pass. Compiled app plists retain `com.guyrettig.StayGrubby` and only upright portrait for iPhone; the Apple `Default` entitlement, team and automatic signing remain intact. Ordinary Release binary checks find no development bypass strings or symbols.

After the complete suite, every development entity field, identity, score, comparison/evidence relationship and all 190 media hashes still match the original manifest. Store UUID/model metadata is unchanged, and no real-account directory/binding/outbox or fixture media entered Application Support. Fresh hosted reads retain one real empty account graph with zero cooking data and zero Storage buckets/objects. No additional Apple authorization or real-account mutation RPC was performed. The only hosted setting change in this review was the explicitly approved disabling of unused Email authentication.

The complete intended checkpoint is 29 files, listed below. Privileged credential scans pass; approved client-safe configuration is byte-for-byte unchanged. Backups, dependencies/build products, local Supabase state and local secrets remain excluded. Both Git diff whitespace checks pass. No application code or database migration was changed during this final verification pass; only current architecture/review documentation was updated.

## Current product and manual verification

Production: Launch → onboarding → native Sign in with Apple → Supabase authentication → permanent StayGrubby account resolution → restore an existing account or initialize a verified-empty new account → ready authenticated application. There is no production guest mode. Sign Out closes the personal tree and clears the device SDK session as designed, while retaining cloud data and local account files.

The first real physical-iPhone login, empty new-account Rankings, Sign Out to onboarding, and second login returning the same displayed permanent account ID were manually verified. Feed is hidden; current tabs are Rankings and Profile. Its destination and tab identity remain for the future Profiles/Following/Friends Feed phase. No real cooking records were created.

Read-only hosted verification found exactly **1 Auth user, 1 Apple identity, 1 permanent account, 1 protected Auth link, and 1 profile**. All relationships join consistently; the account UUID is independent of Auth UUID. There is **1 account-owned library and 1 global ranking**, bridge version 1, revision 1 and unchanged initial row versions. Dishes, attempts, ranked items, comparisons, sources, media, tags, memberships, sync operations and imports all have count **0**. Duplicate rows are absent. Local concurrency/idempotence tests corroborate the repeated-login mapping without calling hosted mutation RPCs.

The Simulator development/demo library is separate: **1 ranking, 12 dishes, 15 attempts/items, 356 comparisons, 10 sources, 21 tags, 48 memberships and 190 media files**. Its full semantic/relationship/media manifest matches the preserved baseline. No account store/binding/outbox exists in this development container, and no demo data was uploaded, adopted or reassigned. The physical iPhone's Debug Demo Library may remain empty; no seeding/copy is needed. The Debug bypass is explicitly labeled, compile-time DEBUG-only, performs no authentication/provisioning/upload, and cannot impersonate an account. Release/TestFlight/App Store exclude it.

Read-only logged-out public browsing is only a possible future feature. Outgoing cooking sync/conflict handling, remote photo transport and account deletion/revocation remain deferred; local personal edits use the durable outbox until transport is implemented. Offline re-entry retains the documented unexpired-session/verified-ready-owner restrictions and cannot check remote revocation while disconnected.

The historical reviews below record earlier validation before the authorized real login; their zero-hosted-user counts and instructions to stop before Apple authorization are superseded.

# Historical Phase 3C Part 2B — required account access review

This supersedes the optional-auth Part 2 review. All Part 2 native nonce/token work remains uncommitted; nothing was reset or discarded. No real Apple login, commit or push is performed here.

## Access and data boundaries

Normal Debug and all Release launches show onboarding when signed out. The personal SwiftUI tree/model container does not exist behind a sheet. An Auth session is insufficient: permanent account resolution and validated account-store readiness are both required. Loading/provisioning/library errors stay outside the personal app. Sign Out unmounts it immediately and returns to onboarding, preserving account files and cloud data.

A new account's authenticated library RPC creates only one empty cloud library/global ranking, atomically and idempotently. Zero dishes, attempts/items, comparisons, sources, tags or photos are seeded/copied. An existing library is returned as a complete owner-scoped graph and hydrated, preserving identities/evidence/metadata. Partial/deleted library state is rejected, never replaced with an empty library. Local changes sharing the same accepted cloud base survive relaunch; pending local work plus a changed remote base blocks setup for later conflict resolution.

The preserved default dataset is **development/demo only**: 1 ranking, 12 dishes, 15 attempts/items, 356 comparisons, 10 sources, 21 tags, 48 memberships and 190 files. It is never an adoption candidate or real-account template. The root does not open it in production. No client cooking graph or photo bytes are accepted by either authenticated setup RPC.

Real accounts use only `StayGrubbyAccounts/<verified permanent UUID>/cooking.store` and that account's media root. The journal records durable local edits, but outgoing cooking-operation transport and remote photo download/backup are not activated in this step. Until that transport is implemented, newly cooked personal data is local/queued; it will not appear on another device. This is a remaining V1 sync limitation, not automatic demo adoption.

Offline relaunch requires an unexpired SDK session plus a matching previously ready/server-verified mapping in device-only Keychain, and a ready validated store for that exact account. Only connection failures permit this fallback. Missing/expired session, failed refresh, auth/server denial, wrong/missing mapping, unfinished store or new account stays at onboarding/setup. Offline use cannot check server revocation; relaunch after token expiry requires connectivity. Sign Out removes the selected cached mapping and SDK local session. Already-open local work survives disconnection.

## Debug and Release

`DevelopmentLibraryAccess`, review coordinator method, environment key, open/exit controls and launch/fixture selection are inside `#if DEBUG`. Direct explicit review launch does not construct/restore Auth. The labeled Debug button is unavailable during authentication/provisioning and suspends observation on review entry. It creates no session/account and sends no provisioning/upload. No real user is impersonated.

- Debug normal: no arguments → onboarding.
- Debug demo: `--development-library` or the labeled Debug button → preserved demo environment, clearly marked; Exit in Profile → onboarding.
- Debug isolated tests: `--ui-test-store UUID`, optionally `--discovery-fixture` → only temporary DB/media fixtures.
- Release: all these arguments are ignored because selection code is absent. Binary checks found no development/fixture flag/button strings or review type/method symbols. Xcode has DEBUG only in Debug compilation conditions. TestFlight/App Store builds must continue using Release without adding DEBUG.

The authenticated UI, ranking math, source/tag semantics and portrait configuration are unchanged. Account media-root propagation is the necessary isolation change to existing photo/form calls. Accessibility and fixture media isolation tests remain required.

## Backend

Five tracked migrations match deployment. The new `account_library_bootstrap` migration has the hosted timestamp `20261012225006` (the CLI-created file was aligned to the hosted MCP version without changing SQL). `api.open_account_library()` is parameterless/authenticated-only; its invoker calls the private fixed-search-path definer, which uses the existing secure live-session/identity lookup and per-user lock. Table write grants/policies are not broadened. RLS remains on all 15 private tables; identity-link client access and anonymous RPC execution remain denied.

Disposable local tests pass 69 schema/RLS/bootstrap assertions and 18 native PostgreSQL assertions, including 20 concurrent provisioning and 20 concurrent initial-library callers. No hosted fixture users are created; the native test cluster is stopped afterward. Security advisor INFO “RLS enabled without policy” remains intentional for the protected identity-link table (clients are denied), with no security warning/error findings.

## Manual checks BEFORE first real Apple login

1. In Xcode use StayGrubby / Debug / iPhone Simulator with no review arguments. Launch: only branding, value text, native Apple sign-in and Debug development control should appear. No tabs, Rankings, New Dish/Version, comparisons or personal Profile may be reachable. Do not tap Apple authorization yet.
2. Tap **Open development library**. Verify the DEVELOPMENT marker, expected demo rankings/scores, search/filter, dish/version presentation and existing placeholders. Do not edit/delete these preserved records for this review. Open Profile: it must say Development library, not pretend to be authenticated. Tap **Exit development library**: onboarding returns, with no personal tree behind it.
3. Relaunch Debug normally: onboarding returns, not a remembered demo bypass. If using the explicit Xcode argument `--development-library`, remove it afterward. No gesture/preferences switch activates review mode.
4. Build/run **Release** on the Simulator. It must show onboarding and no development control. Even adding `--development-library --ui-test-store <fresh UUID> --discovery-fixture` must leave it at onboarding with no Rankings. Clear arguments afterward. Automated/binary validation covers this; do not switch Release compilation conditions to DEBUG.
5. To inspect an empty Rankings screen without personal Apple credentials, use Debug `--ui-test-store <fresh UUID>` without `--discovery-fixture`. This is an isolated development fixture, not a real authenticated account. Verify Add Your First Dish opens normal creation, then exit. Empty-account unit/backend tests separately prove real account initialization starts empty.
6. In Supabase review hosted baseline with the read-only query below: still zero users/accounts/libraries/rankings, and no uploaded cooking data. Confirm no real login occurred during these checks.
7. Connect/unlock the physical iPhone and trust the Mac/enable Developer Mode when asked. In Xcode confirm canonical bundle `com.guyrettig.StayGrubby`, team, automatic signing and Apple entitlement. The previous signed build was blocked by lack of a registered device/profile; allow Xcode to register this phone and obtain a profile. Launch logged out and verify the same mandatory gate, then STOP before completing Apple authorization.

```sql
select
 (select count(*) from auth.users) as auth_users,
 (select count(*) from staygrubby.accounts) as accounts,
 (select count(*) from staygrubby.auth_account_links) as links,
 (select count(*) from staygrubby.profiles) as profiles,
 (select count(*) from staygrubby.account_libraries) as libraries,
 (select count(*) from staygrubby.rankings) as rankings,
 (select count(*) from staygrubby.dishes) as dishes,
 (select count(*) from staygrubby.cooking_attempts) as attempts,
 (select count(*) from staygrubby.comparisons) as comparisons,
 (select count(*) from staygrubby.media) as media;
```

After this review, the first real authorized Apple login should create one user/account/link/profile and **one empty account library/ranking**, with zero dishes/attempts/comparisons/media. The displayed account UUID must differ from Auth UUID and repeat login must return the same account. Development data must remain separate. Do not use the superseded Part 2 zero-library expectation.

## Final validation

The complete Debug scheme passed **139 test functions / 177 executions** (121 unit functions / 158 executions; 18 UI functions / 19 executions), with **zero failures, expected failures or skips**. Result: `/private/tmp/staygrubby-gate-complete.xcresult`. This includes the existing native security, account foundation, sync, ranking/cooking and media-isolation tests.

The Release-only gate test passed **1 function / 1 execution**, testing both normal launch and attempted development/fixture arguments; zero failures/skips. Result: `/private/tmp/staygrubby-gate-release-test-2.xcresult`. Release test compilation used command-line `ENABLE_TESTABILITY=YES` for existing internal test imports, without defining DEBUG or changing project settings. The first Release-test attempt failed at compilation because ordinary Release omits testability; no app/UI assertion failed. Debug-only isolation tests are compile-guarded because their target types are absent in Release; their Debug assertions remain unchanged.

Debug and ordinary Release builds succeed. Release binary symbol/string checks and the runtime test prove review exclusion; the shared scheme's Archive action uses Release. The normal Release screen was visually reviewed. Explicit Debug demo launch shows the preserved rankings and DEVELOPMENT marker; a fresh argument-free Debug launch returns to onboarding. The simulator is left there, with no Apple authorization performed.

The final development Application Support manifest exactly matches the baseline, including every entity field, identity, score, evidence/relationship and all 190 media file hashes. SQLite store UUID/model metadata is unchanged. There are no real account store paths, sync bindings, queued operations or new demo media in Application Support. Backups/manifests remain ignored under `.local-backups/auth-gate-part2b/`.

Hosted users/accounts/links/profiles/libraries/rankings/dishes/attempts/comparisons/media remain zero after deployment and runtime review. All five migration checksums match their repository files. Credential scans have no privileged findings; client-safe configuration is unchanged. `git diff --check` and cached diff checks pass. No commit/push. Remaining review is physical signing/native provider integration, outgoing cooking sync/conflict handling and future photo transport.

## Complete checkpoint file inventory (29 files)

- Modified: `ACCOUNT_ARCHITECTURE.md`
- Modified: `Backend/schema.sql`
- Modified: `Backend/tests/provisioning.concurrent.mjs`
- Modified: `Backend/tests/schema.test.mjs`
- Modified: `StayGrubby/Accounts/AccountSessionCoordinator.swift`
- Modified: `StayGrubby/Accounts/SupabaseAccountBackend.swift`
- Modified: `StayGrubby/ContentView.swift`
- Modified: `StayGrubby/DesignSystem/StayGrubbyComponents.swift`
- Modified: `StayGrubby/StayGrubbyApp.swift`
- Modified: `StayGrubby/Views/Cooking/AddCookingView.swift`
- Modified: `StayGrubby/Views/Cooking/AttemptDetailView.swift`
- Modified: `StayGrubbyTests/AccountSessionTests.swift`
- Modified: `StayGrubbyTests/DebugReviewIsolationTests.swift`
- Modified: `StayGrubbyUITests/ReviewEnvironmentUITests.swift`
- Modified: `UI_ARCHITECTURE.md`
- New: `AUTHENTICATION_GATE_REVIEW.md`
- New: `NATIVE_APPLE_SIGN_IN_REVIEW.md`
- New: `StayGrubby/Accounts/AccountApplicationRoot.swift`
- New: `StayGrubby/Accounts/AccountLibraryAccess.swift`
- New: `StayGrubby/Accounts/AccountView.swift`
- New: `StayGrubby/Accounts/AppleSignInSecurity.swift`
- New: `StayGrubby/Accounts/AuthenticationGateView.swift`
- New: `StayGrubby/Accounts/DevelopmentLibraryAccess.swift`
- New: `StayGrubby/Accounts/VerifiedAccountCache.swift`
- New: `StayGrubbyTests/AccountLibraryAccessTests.swift`
- New: `StayGrubbyTests/AppleSignInTests.swift`
- New: `StayGrubbyUITests/AccountEntryUITests.swift`
- New: `StayGrubbyUITests/ReleaseAuthenticationGateUITests.swift`
- New: `supabase/migrations/20261012225006_account_library_bootstrap.sql`
