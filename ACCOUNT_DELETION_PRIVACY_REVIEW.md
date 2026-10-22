# StayGrubby post-V1 account deletion and privacy readiness

## Owner closeout — October 20, 2026

The owner confirms staygrubby.com is publicly deployed with operational HTTPS and appropriate HTTP/HTTPS and www/non-www routing. The canonical policy is https://staygrubby.com/privacy; privacy contact is privacy@staygrubby.com and support contact is support@staygrubby.com. The owner completed the App Store Connect App Privacy questionnaire. The ninth account-deletion migration and delete-account Edge Function v2 are deployed. **Implemented and automated/security verified; real Apple credential revocation remains physically unverified.** The owner intentionally deferred that destructive physical test; it does not block continued core development. Earlier publication/disclosure/test-pending statements below describe the prior review state, superseded by this owner closeout. No new deployment, App Store Connect action or real deletion test was performed for Cuisine.

Review continued October 20, 2026. Starting checkpoint: `ba539bd0bf971fa3ea5afff18a956d7411005fce` on `main`. The canonical checkout is the original working tree. GitHub renamed the repository from the historical `legoguyr/grub_ranking` name to `legoguyr/StayGrubby`; `origin` now uses the renamed HTTPS URL. Application, bundle, Apple and Supabase identities remain unchanged. The starting 23 tracked modifications and 10 new files exactly matched the previous 33-file inventory; nothing was staged. All prior work was retained.

## October 20 deployment and website status

The owner supplied `privacy@staygrubby.com`, `support@staygrubby.com`, canonical domain `staygrubby.com`, policy URL `https://staygrubby.com/privacy`, and effective date October 20, 2026. The owner configured the Apple secret directly in Supabase. The Dashboard's exact secret name was verified without opening or reading its value. CLI secret-name listing was unavailable because the CLI has no access token; no token was requested or read as a workaround.

The ninth migration is deployed as `20261020141022_account_deletion_foundation.sql`. Supabase assigned that deployment timestamp, so the previously undeployed file `20261018202309_account_deletion_foundation.sql` was renamed to match; its SQL bytes and MD5 `2eab2fe25d0205b2528e4c4660c40436` are unchanged. All eight earlier migration hashes still match exactly, and all nine files concatenate byte-for-byte to `Backend/schema.sql`. `delete-account` version 2 is ACTIVE with `verify_jwt=true`. Its deployed source is the reviewed source, including the Apple identity mapping correction described below. An unauthenticated empty POST returns 401 before deletion. No live Apple authorization, revocation, destructive test, account creation, data upload or real-account deletion was attempted.

Hosted catalogs confirm **17/17 private tables with RLS**, zero anonymous table grants, zero direct authenticated write grants, self-only authenticated deletion status/initiation RPCs, and service-role-only stage/erase RPCs with fixed search paths. There are zero deletion jobs/deleting accounts. Aggregate retained state remains **3 Auth users/accounts, 20 active Dishes, 24 active attempts/items, 79 active comparisons and 44 Storage objects**. Advisor INFO notices for the deliberately inaccessible Auth-link and deletion-job tables are expected; neither table should gain client policies. The existing leaked-password-protection warning concerns the disabled password provider. [RLS notice](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy); [password notice](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

The website is prepared locally for Cloudflare Pages, with `/`, `/privacy` and `/support`. The connector verified an active domain zone and no Pages project. Owner GitHub connection/custom-domain publication remains pending; this review does **not** claim the public policy is live. See `Website/README.md` for exact steps. No Cloudflare resource, DNS or email record was changed.

## Physical V1 approval recorded

The user approved the integrated post-worker build on a physical iPhone with the existing real account and data. The observed PASS list is limited to authentication/sign-in, preservation of existing account data, the integrated authenticated presentation, Profile Entries / Versions / Last Cooked summary, correct Top 3, account disclosure and Sign Out availability, Verify Fresh Restore availability, dark appearance, increased text-size presentation, normal Re-rank, ranking results, native share sheet, and Save Image with the expected output.

The existing StayGrubby 1.0 (1) Internal Only upload remains the previously uploaded baseline. This work creates no archive, upload, App Store submission or tester change.

## Deletion architecture

Profile now separates **Sign out** from **Delete account…**. Deletion requires a native destructive confirmation followed by a fresh Sign in with Apple authorization. Cancellation leaves account, cloud and local state untouched. The same recovery view appears after launch if the server reports an interrupted deletion.

The client reauthenticates with the fresh Apple identity token and requires the returned Supabase Auth UUID to equal the already resolved identity. It sends only the ephemeral Apple authorization code to the authenticated `delete-account` Edge Function. No client request contains a target account UUID. No service-role key, `sb_secret`, Apple private key or other privileged credential is in the app or repository.

The ninth migration adds `staygrubby.account_deletion_jobs` and four narrowly granted API/private function pairs:

- `api.account_deletion_state()` and `api.begin_account_deletion()` are authenticated, parameterless and derive the live caller from `auth.uid()` plus the current nonanonymous `auth.sessions` row.
- Beginning deletion serializes by Auth identity, resolves the protected Auth-to-permanent-account link, snapshots known Storage object keys, and changes the account from `active` to `deleting`. Existing provisioning, sync and Storage authorization then reject the account.
- `api.advance_account_deletion(uuid,text)` and `api.erase_account_data(uuid)` are service-role-only. Public, anonymous and authenticated execution is revoked.
- The state machine is `requested → apple_revoked → storage_cleared → account_erased`. Repeating a completed stage is safe; skipping a stage fails.
- Graph erasure refuses to run until the private `cooking-photos/<account UUID>/` prefix is empty. Deleting the permanent account cascades all account-owned profiles, libraries, rankings, dishes, sources, ranked items, attempts, comparisons, tags/memberships, media metadata, sync operations/imports, receipts, tombstones and backup manifests through the existing ownership graph.
- The deletion job deliberately references Auth rather than the account, so it survives database erasure and can retry Auth cleanup. Deleting the Supabase Auth user last cascades the final job and server sessions.

The Edge Function derives the Auth UUID from its verified JWT context, loads that exact Auth user with server privilege, requires its linked Apple identity, exchanges the one-time authorization code using the protected Apple server credential, validates Apple's signed identity token issuer/audience/subject, and revokes the returned Apple refresh or access token. It then recursively removes known and orphaned objects under the exact permanent account prefix, confirms Storage is empty, advances the durable stages, erases the account graph and deletes the Auth user. Failures return a generic incomplete result and do not claim success. A later fresh authorization can resume the durable job.

After an authoritative success response, iOS journals the permanent account UUID, unmounts account work, returns to onboarding, clears the verified account receipt and local SDK session, and removes only `Application Support/StayGrubbyAccounts/<account UUID>`. The directory contains that account's SwiftData store and media. Sibling accounts and the Debug demo library are outside the selected path. If the local file removal fails, the journal survives for a later launch. A server failure does not queue local deletion or present success.

## Apple configuration and remaining physical verification

The owner has configured the Sign in with Apple private key directly as a protected Supabase Edge Function secret. The single secret name is `STAYGRUBBY_APPLE_CREDENTIALS`; its JSON fields are `teamID`, `keyID`, `clientID`, and `privateKey`. The required client ID is `com.guyrettig.StayGrubby`. The secret value, private `.p8`, access tokens and database credentials must never be committed, bundled, logged, pasted into chat or passed as shell arguments. No private Apple key was read by the agent, and none enters the iOS binary or static website.

Deployment re-review found that Supabase's JSON `identity_id` is the identity-row UUID, not Apple's provider subject. The function now compares Apple's verified signed `sub` against `identity_data.sub` from the server-fetched linked Apple identity and fails closed if it is absent. Two isolated Deno regression tests cover the distinct row/provider identifiers and missing/malformed/non-Apple subjects. [Supabase's identity serialization](https://github.com/supabase/auth/blob/master/internal/models/identity.go) confirms this mapping. No ranking, sync or domain code was altered to fix it.

A retry also obtains a fresh native Apple authorization. The original implementation skipped its validation/revocation after the durable `apple_revoked` stage. Version 2 now verifies and revokes every request's fresh code before proceeding, including retries after graph erasure. Recorded stages still make Storage/database/Auth cleanup resumable; they do not substitute for the current authorization. Four handler-level tests prove invalid fresh retry codes cannot reach cleanup, successful retries revoke before Storage/graph/Auth work, Auth-only retries still revoke, and invalid initial codes create no job. They generate ephemeral synthetic keys in memory and mock all network destinations; no real credentials are inherited, read or logged. Together with the two identity tests, **6/6 Deno tests pass**. Production HTTP still goes through `withSupabase({auth:"user"})`; the exported internal callback exists for isolated contract testing, not a public bypass route.

The migration/function are now deployed together. Full Apple token exchange/revocation and complete hosted deletion still require a **disposable Apple identity/account** on a physical iPhone. Verify cancellation, wrong Apple identity, interruption/retry, photos, final deletion, local cleanup and inability to restore the deleted library. Never use the owner's existing account as the destructive fixture. No claim of successful real Apple revocation is made merely from secret-name presence, type checks or HTTP 401. Publishing the policy and completing this physical gate are required before distributing the deletion release externally.

## Privacy policy and App Store privacy

`StayGrubby/Legal/PrivacyPolicy.md` is the single canonical policy, effective October 20, 2026. It is bundled for offline reading and rendered into the public website during the dependency-free Python build. Both onboarding and authenticated Profile open the same policy sheet with a system link to the permanent public URL; no WebView or website dependency blocks authentication/app use. Tests require the generated policy's complete text to match the canonical document. Future Markdown changes must rebuild the website and update the app-bundled copy in the next app release.

The policy includes both supplied email contacts and the canonical public URL. Website publication and App Store Connect entries remain owner actions. The previously uploaded 1.0 (1) build predates this deletion interface; no archive, upload, submission, version/build change or App Privacy answer submission is part of this task.

Based on current behavior, App Store Connect should evaluate User ID and Apple email/private-relay email; private cooking notes, tags and Sources as Other User Content; user-selected Photos; comparison/ranking interactions as Product Interaction used for app functionality; and Supabase operational diagnostics/provider logs where applicable. All are account-linked app functionality when stored off device. Optional person names in Friend / Family Sources require the Names category if retained off device. The app has no advertising, cross-app tracking or conventional analytics SDK and does not need ATT for audited V1 behavior. Nothing in this review submits those answers for the owner.

The app Privacy Manifest continues to declare UserDefaults required-reason API category CA92.1 for own-app preferences and the durable local cleanup journal. The new flow adds no new required-reason API. PhotosPicker remains selected-photo access; Save Image uses the existing add-only purpose string. The bundled Swift Crypto manifest remains present. No ad, analytics, location, contacts, microphone, broad camera, Bluetooth or local-network SDK/capability was added.

## Final October 20 verification

- Complete Debug suite: **279 test functions / 383 executions**. All **233 unit functions / 336 executions passed**. The UI bundle contains **46 methods / 47 executions** (the launch method has two appearance configurations). Its initial full run had **46 passing UI executions and one failure**, with zero expected failures/skips. Result: `/private/tmp/staygrubby-release-foundation-debug-full.xcresult`.
- The sole full-run failure was the unchanged Polish Contains-edit test at the assertion after Save. The captured hierarchy still showed **Edit Cook**, **Contains, 2 selected**, and **Save**: the synthesized tap had not completed the editor action. Two unchanged repetitions then passed all save, relaunch, Contains and Avoid assertions (**2/2 executions**, zero failures/skips) in `/private/tmp/staygrubby-release-foundation-contains-rerun.xcresult`. No unrelated UI test assertion or product behavior was changed. The initial failed bundle is retained and is not represented as an entirely green run.
- The earlier focused run passed **14/14 unit tests** and caught an incorrect new `app.links` query for the native SwiftUI public-policy control. The query now uses that control's exact accessibility identifier across native element types. The complete Debug run then passed the Profile privacy/deletion-confirmation test. No real Apple sheet was authorized.
- Debug app/test compilation passed. The normal optimized Release app build passed. Release onboarding plus authentication/Profile/sharing isolation passed **7/7 methods/executions**, zero failures, expected failures or skips: `/private/tmp/staygrubby-release-foundation-release-gates.xcresult`. `ENABLE_TESTABILITY=YES` was used only for the separate Release test build, never to add DEBUG behavior to shipping settings.
- Normal Release executable/resources: **zero privileged-secret findings**, **zero of 16 development/fixture markers**, canonical bundle ID, iPhone-only upright portrait, unchanged **1.0 (1)** / **iOS 26.5**, and exact canonical policy/Privacy Manifest present. After tests shut down the simulator, the same iPhone 17 was booted, the Debug app reinstalled without data removal, and a no-argument launch visually verified at ordinary dark sizing/onboarding. A background accessibility-snapshot tool failed, but screenshot capture and app launch succeeded; this was not an app failure.
- Backend: **184 assertions passed** (82 schema/RLS/deletion, 60 structured sync, 42 private-photo policy checks). Edge Function type checking passed and **6/6 isolated Deno tests passed**. The SDK's runtime detection initially requested additional environment permissions; the final tests ran in an empty inherited environment with ephemeral synthetic credentials and no runtime network permission. No actual owner secret was loaded.
- Hosted: all **nine hashes matched programmatically**, the deployed entrypoint/helper/import map match local source, and `delete-account` **v2** is ACTIVE with JWT verification. An anonymous function POST and all four anonymous deletion RPC requests returned **401**. Catalog/aggregate checks confirm 17 RLS tables, zero anonymous application-table grants/direct authenticated writes, zero deletion jobs/deleting accounts, and unchanged **3 Auth users/accounts, 20 active dishes, 24 attempts/items, 79 comparisons, 44 Storage objects**. Required destructive tests remain local/synthetic; no hosted account/photo data was deleted or created.
- Website: **5/5 tests passed** for exact public allowlist, refusal of unexpected publish files, complete canonical policy parity, routes/links/semantic markup, security headers and no remote dependencies. Official PNG bytes match the app asset. Browser review covered desktop and 320/390-point mobile viewports without horizontal overflow; `/`, `/privacy`, `/support` and email links rendered correctly. The site intentionally stays light/cream in either system appearance. Text contrast is **14.99:1**, secondary text **6.49:1**, and the red-button text **5.08:1**. The public output is exactly seven intended files, with no JavaScript, trackers, credentials, user data, internal docs, maps or Git metadata. Cloudflare edge/custom-domain behavior remains an owner publication check, not a claimed live deployment.
- Final preservation: **1 ranking, 12 Dishes, 15 attempts/items, 356 comparisons, 10 Sources, 21 tags, 48 memberships, 190 media files**; complete semantic/media manifest SHA-256 remains `bedd790ea8487f3b1baad442acd9092a6890b0a38cede4951aef0018469b9a51`. Graph identities/evidence/relationships, SQLite metadata/integrity and absence of guest sync/test leakage are verified against the preserved baseline.
- The existing privileged-secret audit and focused PEM/Apple/Supabase/local-file scan cover **221 intended repository files / 217 text files**, with zero findings. No `.p8`, `.env`, local backups, dependencies, generated builds or generated website output enter Git. Approved client-safe configuration and protected ranking/cooking/sync/sharing/design-system/assets/project sources remain unchanged from starting HEAD. Both Git whitespace checks pass. Audit: `/private/tmp/staygrubby-release-foundation-final-safety.json`.

Remaining owner gates are the Cloudflare GitHub connection/custom-domain publication, disposable physical Apple revocation/deletion validation, confirmation/entry of App Store privacy answers and public URLs, and a deliberate iOS coverage decision before broader distribution. These are explicitly documented, not silently treated as complete. No archive, upload, version/build change or App Store Connect submission occurred. Source/backend preparation has no remaining known deterministic regression or unresolved credential/deployment blocker.

## Historical October 18 verification

- Local PostgreSQL: **184 assertions passed** — 82 schema/RLS/deletion, 60 structured sync and 42 private-photo security.
- Edge Function type check: passed with the pinned Deno configuration.
- Focused iOS unit tests: **27/27 passed**, zero failures or skips.
- Focused Profile UI test: first attempt hit the existing simulator tab-navigation tap flake before the new assertions; an identical rerun passed **1/1** without weakening the test.
- Debug app build and build-for-testing: passed.
- Complete Debug suite: **279 test functions / 383 executions passed**, including **232 unit functions / 336 unit executions** and **47/47 UI tests**. Zero failures, expected failures or skips. Result: `/private/tmp/staygrubby-account-deletion-full-final.xcresult`.
- Optimized Release app build passed. The existing Release isolation UI gate passed **1/1** with zero failures or skips. Release binary/resource inspection confirmed the canonical bundle ID, iPhone-only upright portrait, bundled policy and Privacy Manifest, the deletion implementation, zero privileged-secret matches, and zero findings across nine Debug fixture/review markers.
- Final preservation/credential audit passed. The Simulator demo still exactly matches its baseline graph, SQLite metadata and 190 media files: 1 ranking, 12 Dishes, 15 CookingAttempts/RankedItems, 356 Comparisons, 10 Sources, 21 tags, 48 memberships, and zero sync operations/bindings/tombstones. Manifest SHA-256 remains `bedd790ea8487f3b1baad442acd9092a6890b0a38cede4951aef0018469b9a51`.
- The privileged-secret scan covered 212 intended files / 208 text files with zero findings. Client configuration remains public-only; local backups, dependencies, local Supabase state/secrets and generated build products are excluded. All nine local migration files concatenate exactly to `Backend/schema.sql`; the first eight MD5 hashes still match the eight hosted statements. The ninth remains undeployed. `git diff --check` and the unstaged/staged whitespace checks passed.

The hosted read-only audit found the project active/healthy, the original eight migration records, zero deployed Edge Functions, all 16 existing private tables protected by RLS, zero anonymous application-table grants, zero direct authenticated write grants, and a private 2 MiB photo bucket. Current aggregate retained state is 3 active Auth users/accounts/rankings, 20 active Dishes, 24 active CookingAttempts/RankedItems, 79 active Comparisons, 22 active media rows and 44 private Storage objects; zero accounts are in `deleting` state and zero active Dish names match the test/fixture check. This task changed none of that state. Advisor output contains only the pre-existing intentionally policy-less private Auth mapping INFO, two unused-index INFO findings, and the leaked-password-protection warning even though Email/password is disabled and Apple is the only public provider. No hosted destructive test was run.

## Scope

Ranking mathematics, Bradley–Terry fitting, score thresholds/unlock, comparison behavior, re-ranking, versions, Top 3, sharing, structured/photo sync semantics, tombstones, authentication identity, bundle/product identity and portrait-only UI are unchanged. No Friends, social feed, recipes, Want to Cook, avatars, public web sharing or notification feature was implemented.

## Checkpoint file inventory

The complete release-foundation change set contains **42 files** (23 tracked modifications and 19 additions), including the prior 33-file implementation and the website/Edge regression additions. The previously untracked ninth migration is included under its actual deployed version. Generated/local-only files remain excluded.

- `ACCOUNT_ARCHITECTURE.md`
- `ACCOUNT_DELETION_PRIVACY_REVIEW.md`
- `Backend/README.md`
- `Backend/schema.sql`
- `Backend/tests/photo-security.test.mjs`
- `Backend/tests/schema.test.mjs`
- `Backend/tests/structured-sync.test.mjs`
- `PARALLEL_DEVELOPMENT.md`
- `PROJECT_RENAME.md`
- `STAYGRUBBY_MASTER_ROADMAP.md`
- `StayGrubby/Accounts/AccountApplicationRoot.swift`
- `StayGrubby/Accounts/AccountDeletion.swift`
- `StayGrubby/Accounts/AccountSessionCoordinator.swift`
- `StayGrubby/Accounts/AccountView.swift`
- `StayGrubby/Accounts/AppleSignInSecurity.swift`
- `StayGrubby/Accounts/AuthenticationGatePresentation.swift`
- `StayGrubby/Accounts/AuthenticationGateView.swift`
- `StayGrubby/Accounts/PrivacyPolicyView.swift`
- `StayGrubby/Accounts/SupabaseAccountBackend.swift`
- `StayGrubby/Legal/PrivacyPolicy.md`
- `StayGrubbyTests/AccountDeletionTests.swift`
- `StayGrubbyTests/AppleSignInTests.swift`
- `StayGrubbyTests/OnboardingPresentationTests.swift`
- `StayGrubbyUITests/ProfileUITests.swift`
- `TESTFLIGHT_READINESS_REVIEW.md`
- `V1_INTEGRATION_REVIEW.md`
- `Website/.gitignore`
- `Website/README.md`
- `Website/build.py`
- `Website/headers.txt`
- `Website/site.css`
- `Website/test_site.py`
- `supabase/README.md`
- `supabase/config.toml`
- `supabase/functions/delete-account/.npmrc`
- `supabase/functions/delete-account/apple-identity.test.ts`
- `supabase/functions/delete-account/apple-identity.ts`
- `supabase/functions/delete-account/delete-account.test.ts`
- `supabase/functions/delete-account/deno.json`
- `supabase/functions/delete-account/deno.lock`
- `supabase/functions/delete-account/index.ts`
- `supabase/migrations/20261020141022_account_deletion_foundation.sql`


## Shared Cooking and notification deletion integration

The Shared Cooking phase adds four closed/RLS social tables, documented in SHARED_SOCIAL_REVIEW.md. Deleting the event owner cascades shared_cooks and shared_participants. A surviving recipient owns their cooking_origins row: event/post/creator references use ON DELETE SET NULL, preserving their independent private attempt/item/comparisons. Deleting the recipient removes their own origin/participant rows. Notification actor/recipient foreign keys cascade, and all reads/counts reject inaccessible/deleted targets. Existing three-bucket cleanup and delete-account v4 remain unchanged; no new bucket, Apple proof/revocation behavior, secret or real-account deletion test is introduced. Disposable tests verify source-owner erasure leaves the recipient private fingerprint unchanged.
