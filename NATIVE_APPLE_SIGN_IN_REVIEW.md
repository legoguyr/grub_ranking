# Final physical authentication review

The first physical-iPhone native Apple login succeeded, including Supabase authentication, permanent-account resolution and verified-empty account initialization. Required onboarding, empty Rankings, Feed exclusion, Sign Out to onboarding and repeated login to the same permanent account were manually verified. Hosted read-only checks confirm one Apple/Auth identity, one account/link/profile and one owned empty library/global ranking, with no cooking/demo data. See AUTHENTICATION_GATE_REVIEW.md for the final checkpoint evidence and current required-access flow.

The physical iPhone Debug Demo Library may remain empty; its local storage is independent of the preserved Simulator dataset. No dataset transfer or hosted demo account is required. The pre-authentication signing/login limitations below are historical and superseded by this successful physical review.

# Superseded review: Phase 3C Part 2

The native nonce/SDK foundation below remains, but optional authentication and guest library behavior are superseded by required authentication in Part 2B. Do **not** use the old manual flow or expect zero account-library structures after first real login. See AUTHENTICATION_GATE_REVIEW.md for current tests, access requirements and new-account behavior. Development data is never adopted.

# Phase 3C Part 2 — native Sign in with Apple review

Starting checkpoint: `98ab332786e3e24a288344d584cd620508e67266`, clean `main`, October 12, 2026. StayGrubby / `com.guyrettig.StayGrubby`, automatic team `5DSB36G7LZ`, Apple `Default` entitlement and iPhone upright portrait remain unchanged. Supabase Swift is pinned at 2.55.3; client-safe configuration is unchanged and values are not duplicated here.

## Files changed

- `StayGrubby/Accounts/AccountSessionCoordinator.swift` — native attempt/state, restoration and sign-out race handling.
- `StayGrubby/Accounts/SupabaseAccountBackend.swift` — SDK Apple ID-token exchange and current-identity observation.
- `StayGrubby/Accounts/AppleSignInSecurity.swift` (new) — random nonce, hash, native request and ephemeral credentials.
- `StayGrubby/Accounts/AccountView.swift` (new) — optional native entry/setup/sign-out UI.
- `StayGrubby/ContentView.swift` — existing Profile tab integration and parallel guest/session startup.
- `StayGrubbyTests/AccountSessionTests.swift` — mock implementation of the new backend protocol method; existing assertions unchanged.
- `StayGrubbyTests/AppleSignInTests.swift` (new) — security/auth/race/restore tests.
- `StayGrubbyUITests/AccountEntryUITests.swift` (new) — guest account entry at normal/accessibility text sizes.
- `ACCOUNT_ARCHITECTURE.md`, `UI_ARCHITECTURE.md`, `NATIVE_APPLE_SIGN_IN_REVIEW.md` (new) — current boundaries and physical review.

No Xcode identity/signing/entitlement/configuration, package version, schema/migration, ranking engine, cooking-domain service, existing UI-isolation helper or media implementation is changed.

## Implementation boundary

Profile → native Apple authorization → Supabase ID-token verification with original nonce → parameterless secure provisioning → independent permanent account UUID. Cooking UI stays on the original guest container throughout. No guest adoption, account-library initialization/mounting, cooking transport, photo upload, social feature, profile edit or account deletion is implemented. No hosted users are created by automated fixtures. No commit or push is part of this work.

Apple email scope is requested for standard Supabase signup; full-name scope is omitted. The app never reads/requires callback name/email or writes them into the StayGrubby profile. Subsequent sign-ins need neither callback field; no existing profile name can be overwritten. Sign-out uses SDK `.local`, preserves files/cloud rows and does not revoke Apple authorization.

## Validation

Focused auth/account tests and normal/accessibility account-entry UI pass. The first focused test build needed a missing test-only Supabase import; it was corrected before the passing run. Two in-progress full runs were explicitly interrupted to finish email-scope configuration and preserve the native button lifetime; those incomplete bundles are not claimed as passing suites. Final complete scheme: **127 test functions / 165 executions**, **zero failures, expected failures or skips**, on iPhone 17 / iOS 26.5. Unit tests: 110 functions / 147 executions; UI: 17 functions / 18 executions. The 12 Apple tests execute 19 cases; existing Part 1 (14/16) and sync (17/22) suites pass unchanged. Result bundle: `/private/tmp/staygrubby-apple-auth-complete.xcresult`. Three non-failing runtime warnings are the pinned SDK's diagnostic about its default initial-session emission ordering; the app resolves a valid SDK session and permanent account before account access, and does not route from cached/event payload identity alone. The pinned SDK also discards refresh responses if the stored session changed during the request, protecting sign-out/identity changes.

Final Debug build/normal simulator launch and Release build pass. Final unsigned iPhone ARM64 build passes; signed-device installation remains blocked as described below. Canonical bundle/product, team, Apple entitlement and iPhone-only portrait setting are preserved. Normal guest Rankings and optional Account entry were visually reviewed without test arguments or Apple authorization; the app is left on Rankings. Public hosted Auth settings confirm Apple enabled.

Final Application Support entity-field/relationship and file manifest exactly equals the pre-change baseline. Store metadata including UUID/model hashes is unchanged. Counts remain 1 global ranking, 12 dishes, 15 attempts/items, 356 comparisons, 10 sources, 21 tags, 48 memberships and 1 guest library. All 190 pre-existing media files have identical hashes; no new guest fixture files, account store, sync binding or queued sync operation exists. Consistent backup/manifests are ignored under `.local-backups/apple-auth-part2/` and are not app resources.

Privileged-credential scan has no findings; Apple nonce/token wrappers have no persistence/logging path. Only approved client-safe configuration is present. Backups, dependencies, Supabase local state and local secrets remain ignored. `git diff --check` and `git diff --cached --check` pass. `main` remains at the starting checkpoint with six modified and five new intended files (11 total), unstaged/uncommitted. No commit/push.

Hosted migration checksums exactly match all four repository migrations. All 15 private tables retain RLS; authenticated clients cannot INSERT/UPDATE/DELETE auth-account links; anonymous callers cannot execute the provisioning RPC. The exposed invoker calls the private fixed-search-path definer, which derives `auth.uid()` and verifies the live Auth session after its advisory lock. Hosted baseline remains 0 Auth users / accounts / links / profiles / account libraries. The disposable backend schema suite passes 59 assertions; native PostgreSQL concurrency passes 13 assertions including 20 blocked concurrent callers. The cluster is stopped afterward.

No physical login has been performed. A paired iPhone 15 is listed unavailable. Signed build attempts failed because the team has no registered device available to generate the required development profile; the automatic-signing attempt did not produce an installable app. Connect/unlock/register the intended iPhone through Xcode before physical validation. Simulator success does not establish Apple's real token issuance, Supabase audience/nonce validation, Keychain behavior on that device, or real hosted identity mapping.

## First real iPhone test

1. Connect and unlock your iPhone. Enable Developer Mode if Xcode requests it, trust the Mac, and select the phone as the StayGrubby scheme destination. Open `StayGrubby.xcodeproj`; confirm the existing team and automatic signing under Signing & Capabilities. Allow Xcode to register that specific device/create its development profile if requested. Use Product → Run. Do not delete/reinstall an existing installation just to fix signing.
2. Before login, review the phone's existing guest Rankings and several dishes. Record names, scores and counts (a new phone installation may have an empty local library; it does not contain the Simulator library automatically). Record the hosted baseline with the read-only SQL below. Do not paste any Apple token, Supabase session token or private key into logs or the SQL editor.
3. Open Profile, tap **Sign in with Apple**, and complete Apple's native authorization. Verify **Account connected** appears and record the displayed permanent Account ID. The guest-library notice should remain visible. If setup reports a retry, keep the same authenticated session and tap **Try again**; do not manufacture hosted users.
4. In the configured Supabase project, Authentication → Users should now show exactly one user if the baseline was zero. Its provider should include Apple. In SQL Editor, run the identity/count queries below: one account, one protected link and one profile, with the displayed permanent Account ID. That ID must differ from the Auth UUID. New account library/ranking/dish/photo counts must remain zero.
5. Go back to Rankings: the same phone-local guest dishes/scores must remain. Terminate/relaunch online and confirm account resolution reconnects the same ID, while Rankings still shows the guest library.
6. In Profile tap **Sign out**. Verify the native button returns, guest Rankings still load, and hosted account/link/profile rows remain. Terminate/relaunch offline and verify local guest dishes remain available. Sign-out does not revoke Apple or delete the account.
7. Reconnect network and sign in with Apple again. Apple may omit name/email; sign-in must still work. Verify the displayed Account ID equals the first one. Re-run SQL: still one user/account/link/profile and no account library or cooking records. Keep this real account as the first StayGrubby account; do not delete it after review.
8. On the Simulator, the existing development library should still be 1 ranking / 12 dishes / 15 attempts and items / 356 comparisons / 10 sources / 21 tags / 48 memberships. Physical guest data is separate; signing in must not copy either guest library into Supabase.

Read-only SQL, before and after each login/sign-out (do not add session IDs/tokens or caller-supplied identity to the RPC):

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
 (select count(*) from staygrubby.ranked_items) as items,
 (select count(*) from staygrubby.comparisons) as comparisons,
 (select count(*) from staygrubby.media) as media;

select u.id as auth_user_id,
       u.raw_app_meta_data -> 'providers' as providers,
       l.account_id as permanent_account_id,
       a.status, a.sync_revision,
       (p.account_id is not null) as profile_exists,
       exists(select 1 from staygrubby.account_libraries x where x.account_id = a.id) as library_exists
from auth.users u
left join staygrubby.auth_account_links l on l.auth_user_id = u.id
left join staygrubby.accounts a on a.id = l.account_id
left join staygrubby.profiles p on p.account_id = a.id
order by u.created_at;
```

The SQL Editor is an administrative review surface, not a client identity API. Do not export credentials. Multiple pre-existing users require comparison to the recorded baseline rather than assuming project-wide count 1. No schema changes are needed for this manual review.

Implementation references: [Supabase native Swift ID-token API](https://supabase.com/docs/reference/swift/auth-signinwithidtoken), [Supabase Apple guide](https://supabase.com/docs/guides/auth/social-login/auth-apple), [Apple native button](https://developer.apple.com/documentation/authenticationservices/signinwithapplebutton). The October 12 TLS deprecation notice concerns obsolete CBC ciphers/end-of-life clients, and requires no configuration change for this iOS/URLSession client.
