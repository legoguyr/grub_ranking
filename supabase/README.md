# StayGrubby hosted setup — October 11, 2026

## Post-V1 account deletion deployment — October 20, 2026

The ninth migration `20261020141022_account_deletion_foundation.sql` and authenticated `delete-account` version 2 are deployed. Supabase assigned that version at deployment; the earlier unapplied local filename was `20261018202309_account_deletion_foundation.sql`. SQL bytes/hash are unchanged, and all nine local hashes match hosted history. The original eight migrations were not edited. The function has JWT verification enabled and rejects unauthenticated POSTs. All 17 private tables have RLS, with zero anonymous table grants and zero direct authenticated writes. No user/account/data deletion was invoked.

The owner has configured the correct Sign in with Apple server key for Team `5DSB36G7LZ` and client ID `com.guyrettig.StayGrubby` directly in Supabase. The protected Edge Function secret `STAYGRUBBY_APPLE_CREDENTIALS` contains JSON fields `teamID`, `keyID`, `clientID`, and `privateKey`. Only the name's presence was inspected; no secret value or private key was read. Never place those values in Git, app/website assets, shell history, logs or chat. Remaining: validate cancellation, failure, retry and full Apple revocation/deletion on a disposable physical-iPhone account, never the owner's account. The server compares Apple's signed subject to the linked identity's `identity_data.sub`; `identity_id` is a Supabase row UUID and is not valid for that purpose.

The function fails closed before beginning database deletion if Apple configuration/token verification/revocation fails. The current hosted aggregate data counts remain unchanged and no deletion jobs exist. The canonical privacy policy, effective October 20, is prepared for `https://staygrubby.com/privacy`, with `privacy@staygrubby.com` and `support@staygrubby.com`. Cloudflare website publication remains an owner step (`../Website/README.md`). See `../ACCOUNT_DELETION_PRIVACY_REVIEW.md` for final evidence and limitations.

Current native application/Apple Client ID: `com.guyrettig.StayGrubby`. The project/source rename preserves the client-safe plist, pinned SDK and all hosted migrations/account behavior; see `../PROJECT_RENAME.md`. Initial setup/provider limitations below are historical, not instructions to revert the manually configured Apple provider.

## Target and tooling

Project: `StayGrubby`, reference `lgjxbpycphhsswxoncmz`, region `us-east-1`, PostgreSQL `17.11.0.003`. Preflight confirmed ACTIVE_HEALTHY, no application tables/migrations and zero Auth users. Repository was clean on main with Phase 3B commit `ff6c66ff88246b8cb8ddde78eb7d87a423747b6c`.

Official CLI **2.120.0** generated `config.toml`, `.gitignore`, and both migration files. It was downloaded to temporary storage, not installed as an app dependency. Local config uses PostgreSQL 17, automatic table exposure disabled, migrations enabled and seeding disabled. It exposes only empty `public`; it excludes private `staygrubby`. This is LOCAL configuration, not a claim that hosted settings were changed or a file to blindly push to hosted Auth settings. No Docker stack was started.

The authenticated Supabase connector targeted the exact project, applied both migrations, and verified them. The CLI itself was NOT authenticated or linked; no fake `.temp/project-ref` was written. After application, CLI-generated filenames were reconciled to the server-recorded migration versions; SQL bodies were preserved. No manual migration-history repair was used.

## Initial setup migrations (historical checkpoint)

- `20261011211144_private_cloud_foundation.sql`: Phase 3B schema, explicit client privilege revocation and predecessor FK index.
- `20261011211235_schema_access_hardening.sql`: two additional composite-FK indexes and revocation of client execution on the existing optional `public.rls_auto_enable()` event-trigger helper. The `ensure_rls` event trigger remains enabled. No managed Auth schema or helper body was changed.

`Backend/schema.sql` concatenates these files for first-install reference/tests. Future schema changes belong in new CLI-generated migrations, never in edits to applied migrations. New installations must replay the whole chain.

## Initial setup objects and permissions (historical checkpoint)

Exactly 15 empty application tables in private `staygrubby`:

`accounts`, `auth_account_links`, `profiles`, `account_libraries`, `rankings`, `dishes`, `dish_sources`, `ranked_items`, `cooking_attempts`, `comparisons`, `tags`, `attempt_tags`, `media`, `sync_operations`, `sync_imports`.

Exactly three application helper functions: `current_account_id()` (security definer, fixed empty search path, Auth UID lookup plus active account check), `stamp_record()` and `immutable_comparison()` (security invoker trigger functions). Authenticated execution is granted only on the resolver; anonymous execution is denied on all three. Their schema is unexposed.

Fourteen `owner_read` SELECT policies, one per table except `auth_account_links`, restricted to `authenticated` and the resolved permanent account. All 15 tables have RLS. Auth links intentionally have no policy and no client grants. There are no client write policies or write grants. There are 89 constraints including 28 FKs, 33 indexes and 14 actual triggers (the information_schema lists INSERT/UPDATE events separately, yielding 27 rows).

Composite account-scoped keys prevent cross-account relationships. Account libraries allow one owner row, active global ranking uniqueness is enforced, repeated/tie Comparisons remain individual UUID observations, and Source/version uniqueness retains soft deletion. Server stamping controls row versions; evidence and owned entity identity changes are rejected by triggers. Clients cannot supply versions or write any data directly. A future authorized RPC must also validate server timestamps and active-parent/deletion invariants; those workflows are not implemented here.

Provider identity -> Supabase Auth UUID -> protected auth_account_links -> permanent account UUID remains the ownership boundary. Future provisioning must derive the verified Auth UUID server-side, allocate an independent account UUID, serialize concurrent bootstrap calls, return the existing mapping on retries and insert account/link/profile atomically. Never accept an owner from email, username, user_metadata, a provider ID or a client-supplied account UUID. No bootstrap RPC or real account was created in this setup.

## Initial exposure plan (superseded for provisioning by Part 1 below)

Hosted REST explicitly reports exposed schemas `public, graphql_public`. `staygrubby` table and resolver requests with the publishable key return **406/PGRST106**; requests without a key return **401**. Thus application tables/functions remain private even though Data API is enabled. Automatic exposure is OFF; explicit table grants alone do not add a custom schema to the exposed list.

Later create a dedicated `api` schema in a reviewed migration, with only carefully authenticated provisioning/mutation/import/snapshot entry points. Grant schema USAGE and EXECUTE on specific approved signatures to authenticated only. Keep `staygrubby` and Auth mappings/helpers out of the exposed list. Then intentionally add `api` in Dashboard -> Integrations -> Data API -> Settings -> Exposed schemas, reload/verify the API and test with real sessions. Do not copy broad GRANT ALL examples. This setup creates no `api` schema, exposed views or RPC endpoints.

## Initial client configuration and SDK (historical checkpoint)

`StayGrubby/Configuration/SupabaseClient.plist` centralizes exactly ProjectURL, ProjectReference and the supplied PublishableKey. These are client-safe values, deliberately bundled, not secrets. The existing filesystem-synchronized Xcode group includes the resource without project edits. Build succeeded and the bundled plist matches the source.

No Swift SDK was added. Next integration step: select and pin the then-current reviewed `supabase-swift` release from `https://github.com/supabase/supabase-swift` through Xcode Swift Package Dependencies, add only the required Supabase product to the app target, retain Package.resolved, and instantiate a client from `Bundle.main.url(forResource: "SupabaseClient", withExtension: "plist")`. Add a validated configuration loader then; do not scatter URLs/keys, add privileged keys, or activate sync at startup. SDK integration belongs with the authenticated transport work.

## Initial setup validation and boundaries (historical checkpoint)

- 40 isolated PostgreSQL assertions passed against the entire tracked migration chain, including two-account security/constraints and deletion behavior. Auth claims are simulated only in that disposable engine.
- Hosted catalog confirms RLS, exact owner-read policies, no anonymous table grants, no authenticated write/bypass grants, inaccessible Auth links and restricted helper execution. An authenticated database-role test with no Auth claims resolves no account and reads no ranking rows.
- Hosted REST checks: no-key 401; private table/helper profile requests 406. No real JWT session test was performed, because no real account was created.
- Security advisors: zero warnings/errors; one intentional INFO for Auth links with RLS/no policies. Performance advisors: zero missing-FK-index findings; unused-index INFO is expected for eleven new indexes on an empty project. Retain them for FK cleanup/joins.
- iOS compile-only build succeeded with zero warnings/errors; centralized resource packaging verified. App Swift sources, Xcode project, UI, engine and live guest store were not modified or launched for these checks. The complete app suite was not rerun for configuration/documentation-only changes.
- No credentials, users, guest-library uploads, photos, buckets, social tables or synchronization worker were created. No commit or push.

Advisor references: [private mapping intentionally has no policies](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy), [unused indexes](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index). Exposure guidance: [securing the API](https://supabase.com/docs/guides/api/securing-your-api), [custom schemas](https://supabase.com/docs/guides/api/using-custom-schemas).

## Manual CLI access, if needed later

No credential/action is required to complete this checkpoint. Connector authentication was sufficient. For future local CLI deployment, use a supported pinned CLI and run these yourself in Terminal at the repository root:

```sh
supabase login
supabase link --project-ref lgjxbpycphhsswxoncmz
supabase migration list --linked
supabase db push --linked --dry-run --skip-vault
```

`login` opens Supabase's browser login/token flow; its credential remains local to the CLI/OS credential store. `link` may prompt in Terminal for the project's database password (Dashboard -> Project Settings -> Database). Enter it only in that local secure prompt. Do not put it in command arguments, source files or tracked config. Do NOT paste access tokens, database passwords, service-role/secret keys or signing keys into Codex/chat. Check that both server versions match local history before any future push; these two migrations are already applied. Stop if authentication is requested by an agent; no secret workaround is allowed.

Before Apple sign-in: implement/test atomic idempotent account provisioning, real authenticated sessions and dedicated RPC exposure; decide anonymous-provider access; prepare the Apple Developer capability/provider and redirect/nonce flow separately. Guest adoption, multi-device conflict/tombstone handling, mutation/import/snapshot RPCs and production transport remain later implementation. This checkpoint does not authorize those features.

## Phase 3C Part 1 — account provisioning foundation

Two additional migrations are now applied: `20261012021032_account_provisioning.sql` and `20261012021504_provisioning_session_guard.sql`. The SQL reference and four-file migration history match. Only `api.provision_account()` is added to the exposed Data API surface. It accepts zero arguments and delegates to the private trusted function; the existing 15 tables/14 owner-read policies and direct-write denial remain intact. The session guard validates the current non-anonymous Auth user and matching non-expired server session after acquiring the identity-scoped lock. Accounts/profile/link creation is atomic and idempotent; libraries/rankings remain uninitialized. No hosted user/account or guest data was created during validation.

The migration sets authenticator pgrst.db_schemas to retain public/graphql_public and add api, then reloads configuration/schema. This is a supported explicit role override and is deliberately maintained in migrations; the Dashboard exposed-schema list is no longer authoritative while this override exists. Private staygrubby/auth are not exposed. Hosted POST checks returned 401 without a key, 401/42501 with the publishable key as an anonymous caller, and 406/PGRST106 for private staygrubby. Real authenticated success awaits a separately authorized real login; local-equivalent success/concurrency was verified instead.

Official Supabase Swift 2.55.3 is now an exact SPM dependency. Package.resolved pins the SDK and transitive revisions. Client-safe plist values remain centralized; SDK defaults use Keychain and no logger. The app's guest launch does not construct a client or contact Supabase. AccountSessionCoordinator prepares only an isolated, unresolved/unmounted account store after validated provisioning. See ../ACCOUNT_ARCHITECTURE.md. No Apple capability, Development Team, native login flow, adoption, cloud photos, social feature or production sync was added.

Apple Developer enrollment is processing. Activation is needed for App ID/Sign in with Apple capability, paid-team provisioning and eventual real native login validation, but not this implementation. Do not generate or paste privileged credentials.
