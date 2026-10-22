# Recipes, Tickets & Shareable Social Foundation

Review date: October 21, 2026 (America/New_York). Native implementation and focused automated/Simulator verification are complete. Scope is the native product/data/routing foundation before **STAYGRUBBY DESIGN SYSTEM + FULL UI/UX + MOTION REFINEMENT**, not that redesign. Website publication, Apple capability/device association and actual beta-link gates below remain outstanding and must not be treated as completed.

## Reconstructed state and checkpoint boundaries

Started on `main`, HEAD `b37a56eed915d0a15efdac5852c0101e19b53f01`, four existing Shared Cooking commits ahead of the tracking `origin/main`. No staged files. The only pre-existing edit was `StayGrubby.xcodeproj/project.pbxproj`, app build number 1 → 2 in both configurations. It remains preserved and excluded from feature commits. No reset, stash, clean, worktree or parallel worker was used. The continuation prompt arrived during this cycle; existing uncommitted implementation and successful evidence were retained rather than recreated.

Prior phase was actually **28**, not the prompt's 24, RLS-protected tables; 20 deployed migrations. delete-account v4 ACTIVE with JWT verification, three private buckets and the existing Shared Cooking/Run It Back/notifications implementation were retained.

Backend checkpoint: `debf276` — private Recipe/Ticket/provenance/route tables, narrow RPCs, migration and security tests. Later app/website/verification checkpoints are recorded in the final report. No distribution or Apple portal action is performed here.

## Recipe, Ticket and cooking architecture

| Concept | Identity and behavior |
| --- | --- |
| Recipe | Durable UUID in its own account-owned cloud table; makeable content, not personal cooking or ranking |
| Recipe content | Title, optional description, ordered ingredient rows and instruction steps, optional canonical Course, Cuisine label, source attribution and validated HTTPS source URL |
| Creator/source | Record owner is server-derived and displayed as **Added by**. User-entered original source/author text is separate; adding or running back a record does not claim original authorship |
| Ticket | One `(account, recipe)` save with creation timestamp; account-owned, private, idempotent; removing a Ticket never deletes its Recipe |
| Dish / CookingAttempt / RankedItem | Existing private SwiftData graph and normal cooking/ranking lifecycle, unchanged |
| Recipe cooking reservation | Account-owned UUID, separate reserved item UUID, immutable recipe-content snapshot/revision; no Dish, attempt, item, evidence, score or rank is created by a reservation |
| Completed provenance | Links that reservation only to the caller's own synchronized attempt whose ranked-item identity matches; idempotent completion |

Ingredients/steps are ordered JSON string arrays, rather than an opaque recipe blob. Each entry has a bounded size and the server constructs an explicit content allowlist. No client owner/creator ID, score, private note, photo or evidence is admitted to content. No scraping, inference, AI, nutrition, units/scaling engine or popularity ranking was added.

Recipe visibility defaults to private. **Share recipe with Sous Chefs** deliberately allows current eligible friends to read the entered recipe fields. No public/anonymous recipe API or web recipe route exists. Friendship/block/account state is checked on every recipe read and social reference. Only the owner edits/deletes. Revision checks reject stale overwrites. Recipes have no media transport in this cycle: existing private cooking/photo systems and all buckets stay unchanged.

Recipes/Tickets are fetched through the same resolved account/session-bound Supabase transport as social data; they survive relaunch, sign-in and account restore because their canonical records live in the cloud. They are not added to `CookingGraph` or its schema/migrations. Recipe management currently requires connectivity; no new offline Recipe cache/outbox is claimed. Existing offline private cooking remains unchanged.

## Make This and Run It Back

Recipe/Ticket → Make This reserves stable provenance, prefills a value-only editable `CookingDraft`, then uses the existing `AddCookingView`, `RankingEngine` and `CookingStore.create`. The Recipe's Course/Cuisine/source can prefill safely; no private annotation, photo, allergen, score or evidence is copied. The user can edit the cook before continuing.

Canceling/abandoning creates no private cooking graph, ranked entry or evidence. The harmless cloud reservation may remain until account cleanup; it cannot complete without the caller's independently saved/synchronized cook. Tickets remain saved until deliberately removed; title matching never marks them cooked. Repeating Make This deliberately can produce independent attempts, while request retries reuse the current reservation.

The existing account-bound `SharedCookingOutbox.json` now optionally carries `recipeOriginID`, backward-compatible with older journal entries. An intent is persisted before the existing private save. Completion waits for actual saved cooking and structured-sync readiness, retries after relaunch/foreground/sync, and uses generation/account fences. Social-origin completion and invitation creation remain separate steps. A failed attribution request never manufactures or duplicates private cooking. Completion posts the existing social-content change notification so provenance refreshes.

Run It Back preserves two independent origins: the existing `cooking_origins` social post/person, plus `recipe_cooks` original Recipe snapshot/revision. The server derives the Recipe only from the source author's explicitly completed recipe-linked cook, and only if the recipient currently may read it. No supplied foreign Recipe/CookingAttempt/creator is trusted as provenance. Shared Cooking claims can carry the same independent Recipe reference. Legacy posts with no Recipe retain safe existing prefill and are not backfilled. Historical snapshots do not silently change when a Recipe is edited, made private or deleted.

## Profile links and authentication

Canonical share URL: `https://staygrubby.com/@username`, through native `ShareLink`. The profile action is offered only for a configured discoverable identity. Receiving a URL never proves authorization.

`AppRoute` strictly accepts the canonical HTTPS host, exact lowercase username syntax and profile path only. Credentials, ports, query/fragment injection, percent-encoded path tricks, private-object routes and arbitrary hosts are rejected. A typed route enum and central `AppLinkRouter` separate routing from screens and can gain separately authorized object types later. No Recipe/post/Ticket URL was made public.

The app owns the router above the authentication gate. Cold/warm URL callbacks retain a destination, not profile content. The authenticated account-ready `ContentView` presents and resolves it through the bound request transport. Signed-out users must finish normal onboarding/Apple authentication/account readiness first. Existing session guards discard results for switched accounts. Scene refresh clears resolved profile content and reauthorizes. Unavailable/private/blocked/deleted/invalid targets show a generic unavailable state. Own-profile links show own Kitchen identity without self-friendship actions. Other profiles reuse the existing friendship/block/report implementation.

`profile_routes` maps slugs to permanent account UUIDs. Existing configured handles were registered without modifying profiles. Username changes reserve every prior slug; old links resolve to that same account's current handle only while discovery/access permits. Other accounts cannot claim an old slug even after the old temporary 30-day reservation expires. Account erasure nullifies the route owner and leaves only an unlinked anti-impersonation reservation; it no longer resolves or reveals an account.

## Universal Links, website and owner actions

Local entitlement: `com.apple.developer.associated-domains = ["applinks:staygrubby.com"]`. Existing Sign in with Apple entitlement, automatic signing, Team `5DSB36G7LZ`, bundle `com.guyrettig.StayGrubby`, portrait configuration and owner build-number edit are preserved. AASA is generated only for `5DSB36G7LZ.com.guyrettig.StayGrubby`, `/@*`; native parsing further restricts accepted routes.

Static output adds one generic `kitchen.html` fallback, `/@* /kitchen.html 200`, and extensionless `.well-known/apple-app-site-association` with JSON content type. No profile names or other Supabase data are fetched/interpolated into web pages. No JavaScript, analytics, cookies, external fonts, web accounts, social graph, feed, recipe catalog or rankings website was introduced. Existing privacy/support pages and DNS/email configuration are preserved. `PrivacyPolicy.md` remains the single bundled/static-site source and now describes Recipes/Tickets/snapshots/profile routes and deletion.

`Website/distribution.json` is explicitly `{"url": null}`. No TestFlight/App Store address was invented. When the owner supplies the actual External TestFlight public URL, configure it and rebuild/test/deploy. An Apple HTTPS destination allowlist permits later real App Store configuration without changing profile URLs. Unconfigured beta access is stated honestly; the installed-app instruction directs people to the original shared link in Messages/Mail rather than claiming same-domain Safari navigation always launches the app.

**Publication gate:** Cloudflare account inspection was not executed because automatic approval review hit a usage limit. A fresh scoped inspection/deployment question is pending; no alternate credential/CLI path was used to bypass review. The website and AASA are prepared locally but are not yet verified deployed by this cycle. Public web-tool reads were unavailable and are not deployment evidence. Do not claim end-to-end Universal Links complete.

**Apple owner action:** In Apple Developer → Certificates, Identifiers & Profiles → Identifiers → `com.guyrettig.StayGrubby`, confirm Associated Domains is enabled alongside Sign in with Apple. If needed, enable it and let Xcode automatic signing refresh the provisioning profile for the same Team. No keys/certificates/passwords need be pasted into Codex. After AASA is live, install a newly signed build, open a profile link from Messages/Mail on a physical iPhone, and verify cold/warm, signed-in/signed-out, private/blocked/deleted/renamed cases. Apple's association cache can delay propagation. No physical testing, portal changes, archive, upload or App Store Connect action occurred here.

## Sous Chefs and Settings

Sous Chefs prioritizes segmented current Sous Chefs / Find Sous Chefs / Requests, replacing the generic all-actions menu. Sent Requests and Blocked Accounts remain fully functional on dedicated destinations, reached through Settings → Social and Settings → Privacy & Safety. Block/Report retain conventional explicit terminology.

Settings contains real Account & Profile (identity/photo/discovery/account/sync/sign-out/deletion), Social (sharing defaults/sent requests), Privacy & Safety (blocked accounts/discovery) and Support & About (support, policy, actual app version/build). It does not invent empty notification preferences. Existing account/sync access remains available. Frequent friend search and incoming requests are outside deep settings. Views can be restyled separately from models/services/router; no full visual or broad terminology redesign was attempted.

## Security and account erasure

Four new closed tables have RLS, no anonymous privileges or direct authenticated read/write grants. Narrow authenticated `api.recipes` / `api.profile_link` delegate to fixed-search-path server ownership checks; internal helpers and wrapped predecessor functions remain client-inaccessible. All 32 hosted application tables have RLS and anonymous API execution grants remain zero. Supabase advisors report intentional closed/RPC-only no-policy INFO entries, not missing access protection: [advisor explanation](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy). The existing unused password-protection WARN remains; email/password is disabled for the Apple-only app: [password advisor](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). No new ERROR was reported.

Foreign ownership/edit/delete/Ticket operations, inaccessible Recipe reads, forged actor/creator/private-attempt/provenance, stale revisions, malformed routes, nondiscoverable and blocked profiles, and username-link takeover are tested. Source attribution is user-written content, not a verified claim that an external author is an account holder. All three media buckets remain private.

Owned Recipes/Tickets/provenance cascade through account erasure. Cross-user Recipe references become NULL; intentionally retained snapshots and the survivor's independently completed private graph remain intact. Published handle reservations are unlinked. Existing delete-account v4 code does not need redeployment: its account erasure already follows these new FK rules. Automated deletion tests use disposable fixtures only; no real Apple credential revocation/account deletion occurred.

## Deployment, integrity and verification evidence

Migration `20261022012426_recipes_tickets_links.sql` was created through the CLI, tested locally, deployed through the authorized Supabase tool, then renamed to its assigned hosted timestamp without changing SQL bytes. MD5 `6815e8014ce34883f2f8925fef7df2de`. **21/21** local/hosted version/name/SQL hashes matched. No earlier applied migration was edited. `Backend/schema.sql` is the exact ordered migration concatenation. Hosted new Recipes/Tickets/recipe-cook reservations are all **0**; **1** configured existing username route was registered. No hosted fixtures or media were added.

Before/after private fingerprint groups matched: accounts 3, rankings 3, dishes 28, attempts/items 33 each, comparisons 104, sources 11, tags 10, memberships 49, media metadata 31, operation receipts 59, Storage objects 45. These raw hosted totals include existing history and are not claims about active user-visible records. All original social/profile/preferences/friendship/block/comment/like/shared-origin/notification fingerprints matched. Buckets: cooking 44, social 1, profile 0, all private.

Preserved simulator demo: **1 ranking / 12 dishes / 15 attempts/items / 356 comparisons / 10 sources / 21 tags / 48 memberships**, 190 media files. Complete manifest SHA-256 `bedd790ea8487f3b1baad442acd9092a6890b0a38cede4951aef0018469b9a51`. Engine/models/private CookingStore/private sync/official assets/client configuration remain unchanged. Tests use isolated UUID stores/media and synthetic social transports.

Focused backend results so far: schema/RLS **82**, new Recipe/Tickets/routes **42**, Recipe/social provenance **16**, existing Shared Cooking **46**, identity **24**, friendship **27**, social safety **25** assertions passed. Existing identity/friendship strict DTO assertions initially failed because they omitted already-approved avatar/sharing fields; their exact allowlists were updated, not removed. Account-deletion Edge tests: **8 passed**, no real service calls. An initial invocation omitted the function's import-map config; rerunning with its existing config passed type checking and all tests.

Native first pass: **13 passed** (5 Recipe/link tests + 8 existing Shared Cooking tests). Initial UI diagnostics retained genuine failures: querying the unavailable screen as an Other element instead of its visible StaticText; assuming a Close button on a native ShareLink popover; a missed Profile tab tap. Hierarchies showed the expected product content and native share UI. Tests now require the actual visible message, native Copy activity and supported popover dismissal, with bounded navigation acknowledgement. No meaningful privacy/ranking assertion was removed. Recipe create/edit, Ticket listing/removal, own/other profile links, Recipe cook and Run It Back have individual passing evidence; the final combined targeted run passed as recorded below.

Final combined targeted integration: `/private/tmp/staygrubby-recipes-integrated.xcresult`, **29 tests passed / 0 failures / 0 unexpected failures / 0 skips**: 13 native and 16 UI. The UI selection includes all 8 Recipe/link flows, 3 Sous Chefs flows, legacy Run It Back, identity setup and 3 affected avatar/default/settings flows. Light/dark and accessibility text are exercised. Backend totals are **262 assertions** across the seven focused files above; Edge deletion **8 tests**, static website **6 tests**. Debug build succeeds; migration/schema-byte checks, data-manifest audit, privileged-secret/local-artifact scan and both whitespace checks pass. Older diagnostic failures are retained honestly above, not relabeled as passing bundles. No full historical UI suite, physical device or Release build is required by this scoped cycle and none is claimed.

## Limits and next phase

No Recipe image upload, offline Recipe management, public Recipe URLs, web content, push, AI, parsing, nutrition, counters, Stars, challenges or commerce. Website publication, real External TestFlight URL and signed-device Universal Link verification are separate remaining gates. Existing signed-in private cooking remains available offline. Saved/history references can outlive access according to the disclosed snapshot rules; no remote recall is promised.

Before external distribution: publish the updated policy/AASA/landing, confirm Apple capability/provisioning and real-device links, configure the real beta destination, manually review the new recipe/Ticket/friend/settings flows, and review App Privacy disclosures. Do not require another upload merely to continue authorized local development. The exact next major product phase is **STAYGRUBBY DESIGN SYSTEM + FULL UI/UX + MOTION REFINEMENT**, requiring separate authorization.

## Final local checkpoints and publication status

- `debf276a27127b5084290c8f71d33f519109b7ed` — tested/deployed private Recipe, Ticket, recipe-origin and safe profile-link backend (5 files).
- `fdf41f583ad7af4b61fa098c1c727ab76b0e0699` — minimal static landing/AASA preparation and canonical privacy disclosure (6 files; no hosted website publication).
- `544ebd96bf12323f43f9dff0b0736f8b8c8dc112` — integrated native Recipe/Ticket/cooking/provenance, Kitchen links and social/settings navigation with focused tests (25 files).
- Final verification/documentation checkpoint follows those commits; its SHA is reported after creation rather than embedded in its own source.

A normal `main` → `origin/main` push was attempted after the app checkpoint and failed: HTTPS could not read a GitHub username with terminal prompts disabled. No token, credential store, SSH, remote or Git configuration was changed. The final documentation checkpoint is not retried against the same known authentication failure. **Owner: push all local commits through GitHub Desktop.** The tracking branch was already four commits behind at cycle start; this cycle adds four logical commits, leaving eight ahead if the remote is unchanged.

Final hosted/private/social fingerprint checks still match the baseline. All 32 tables remain RLS protected; delete-account v4 remains ACTIVE with JWT verification and the exact original bundle hash `61be13a0430ab018a0557855e79b4eac05fecc4af456b11f20bd7ac5d7a14f14`. Final Debug build succeeded. Secret/local-artifact scan has zero findings; `git diff --check` and staged whitespace checks pass. The only intentionally uncommitted file after closeout is the owner's original project build-number 1 → 2 edit. Backups, local Supabase state, dependencies, generated website output, signing material and build products are excluded.

This is **native implementation/automated-Simulator complete**, with explicit external gates: Cloudflare inspection/deployment was blocked by automatic approval review's usage limit and the fresh scoped approval question remains pending; the local website/AASA cannot be called live. Apple capability/provisioning and cold/warm signed-device Universal Links require owner confirmation/testing. The actual External TestFlight destination is unset. Those gates do not authorize any upload, real account deletion or full design overhaul here.
