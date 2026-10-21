# Social UX enhancement review — October 21, 2026

Baseline: clean `main`, `d8b01a7fe1d9111781c4eb9b1ca2b0ef1440c26d`, aligned with local origin/main. Original Social V1 is retained. Hosted baseline: 16 aligned migrations, two private photo buckets, 24 RLS application tables. Original 12 private count/hash groups match the preceding social review; the simulator demo manifest remains the preservation baseline. No real social users, content or media are used for tests.

## Checkpoint 1 — Profile photo foundation

A dedicated private profile-photos bucket, owner-scoped immutable version paths and draft/publish/remove/cleanup RPC implement optional identity media. Only intended authenticated social audiences can read; blocks apply and listing is denied. Friends/search/request lists, own identity/setup, minimal friend profile, Feed authors and comments use the same circular avatar/initials component. No private cooking-media architecture is reused except its pure image encoder; there are no cooking-media graph/file writes. Account deletion guards and cleans all three buckets, retaining Apple verification/revocation order. See SOCIAL_ARCHITECTURE.md.

Local focused SQL: 29 assertions passed, including draft/upload ownership, unauthorized replacement/removal, discoverability/friends/block visibility, no listing/anonymous access, safe DTOs, immutable replacement, cleanup, deletion guard/cascade and ranking-cache preservation. Synthetic deletion-function tests: 8 passed, including avatar cleanup failure preventing graph/Auth erasure. Native avatar/session tests: 5 passed. Debug build passed. Initial new UI failure identified automatic Form-row button propagation between photo selection/removal; independent borderless controls correct it. Final dark avatar preview/save/remove UI passed 1/1 in `/private/tmp/staygrubby-avatar-ui-final.xcresult`, zero failures/skips. The account/schema checks also passed 82 assertions against the additive migration. Native photo-library selection itself remains for real-device review; the isolated UI test injects synthetic selected bytes into the same preview/save path.

Hosted deployment completed after the owner supplied direct approval. The initial attachment-only authorization rejection was respected; no alternate route was used. Exact deployed versions and verification are recorded below.

No TestFlight/archive, physical device, real Apple deletion, secret inspection, website publication or App Store Connect work occurred.

## Checkpoint 2 — Sharing preference and social setup

`profiles.auto_share_new_cooks` is an account-owned, account-synced boolean with a non-null OFF default. The narrow identity RPC reads/updates it; an old client's omitted field preserves an existing deliberate choice. A separate sharing action requires configured social identity and derives the owner from live Auth. Setup can choose ON/OFF without a photo or automatic sharing being required. Profile → Social settings provides the normal user-facing control. The setting affects future New Dish/New Version defaults only, with no post creation/deletion or cooking mutations in its RPC.

The focused preference SQL harness passed 12 assertions, including legacy OFF, intentional setup ON/OFF, cross-account forgery denial, anonymous denial, old-client preservation and no retroactive publication. Native legacy/unconfigured default unit passed. Settings save/reopen passed 1/1 in `/private/tmp/staygrubby-defaults-setting-ack.xcresult`; light accessibility-size setup with deliberate ON selection passed 1/1 in `/private/tmp/staygrubby-sharing-logic-setup.xcresult`. The first new test tapped the full SwiftUI labeled switch row rather than its nested control; hierarchy evidence identified the selector error. The final harness uses the actual switch and asserts the new value and navigation completion. An earlier large-text text-entry focus miss uses the existing focus-aware helper. No assertion was removed. Hosted deployment is complete; the local and hosted SQL hashes match as recorded below.

## Checkpoint 3 — Per-entry sharing integration

New Dish/New Version show an account-defaulted, individually overridable sharing control. Continue freezes the choice, including privacy-safe OFF if preference loading has not completed. Only new completed-cook creation records an intent. The separate owner-validated local outbox uses the new RankedItem identity before the private save, then publishes through the same SocialPostPublisher/social_content architecture as manual sharing after private save/rank and accepted structured sync. It never persists social intent in the private cooking graph. Photos use social-photos, never another user's private cooking object. Existing snapshots, explicit manual sharing and native image exports remain intact.

Failure preserves private cooking/evidence; Retry and Keep private are available in result/Profile. The outbox survives same-device relaunch and is intentionally not restored from cloud cooking history. Stable/canonical post IDs prevent duplicates and deleted-post resurrection. Re-rank, Edit, photo replacement and restore never create new intents. Pending intents retain their original choice if the account default changes.

A saved locked-score intent that remains pending until scores unlock pauses for explicit review through the existing manual composer. No automatic historical numerical disclosure/update is introduced; actual unlock state comes from the unchanged ScoreUnlockPolicy and the server continues enforcing eligibility.

Initial focused new-flow verification passed the existing manual composer and default-OFF → explicit per-entry ON → completed cook/post/locked-score path. The first default-ON override test over-scrolled past the switch and let XCTest auto-scroll its target during the tap; the harness now scrolls the actual control into a hittable position before mutation. No deletion/publication/private-state assertion is weakened. Final default-ON override-OFF/private Feed plus New Version default-ON/rank/publication passed 1/1 in `/private/tmp/staygrubby-entry-sharing-scoped.xcresult`. The failure snapshot established that a background ScrollView was targeted while the software keyboard remained open; synthesized swipes entered keyboard predictions instead of scrolling the cook. The harness now dismisses the keyboard with the native Return key, scopes the cooking form by identifier and requires the nested switch to be hittable. The five publication units (including delayed unlock review) and two avatar units passed in `/private/tmp/staygrubby-entry-sharing-final.xcresult`; that bundle’s earlier scrolling UI failure remains recorded and is not counted green.

## Checkpoint 4 — Integrated verification and release state

The enhancement is **implemented, locally verified and deployed**. Automatic approval review initially rejected attachment-only authorization; the owner then directly approved this exact hosted scope and a normal push. The approved migration/function tools deployed the tested changes. No Auth user, cooking record, social post or photo object was created, reset or deleted. Physical review and the owner release actions below remain; no upload is authorized by this checkpoint.

### Final verification evidence

| Focused check | Final result |
| --- | --- |
| Avatar ownership/visibility/cleanup/schema | 33 SQL assertions passed |
| Sharing defaults, no backfill, forgery/friend/block boundaries | 16 SQL assertions passed |
| Existing post/score-lock/private-media boundaries directly affected by shared publisher | 25 SQL assertions passed |
| Account/schema/RLS/grants and complete migration reference | 82 SQL assertions passed |
| Total focused PostgreSQL assertions | **156 passed** |
| Synthetic account-deletion/Apple-identity tests | **8 passed**, including avatar cleanup failure preventing graph/Auth erasure |
| Canonical policy/website consistency | **5 passed**, no site deployment |
| Integrated native tests | **13 methods / 15 parameter-expanded executions passed** |
| Integrated UI tests | **7 passed**, zero failures/unexpected failures/skips |
| Combined result bundle | **20 methods / 22 executions passed**, zero failures/expected failures/skips |

Integrated bundle: `/private/tmp/staygrubby-social-ux-integrated.xcresult`. Native coverage: avatar optimization/aspect ratio/buckets/failure recovery; legacy OFF and unconfigured identity; frozen overrides; owner-validated journal persistence/backup exclusion; completed-cook timing; API/photo failure preserving private graph; retry idempotency; no publication from edit/re-rank/restore; delayed locked intent requiring review after unlock; JSON/photo replies rejected after sign-out; foreign-account food/avatar writes denied; bounded JPEG/path validation and no private graph fields in social DTOs.

UI coverage: own avatar preview/save/removal in dark mode; settings OFF→ON save/reopen; light accessibility-size social setup choosing ON with an optional photo; default OFF with an individual ON cook publishing only after ranking with score locked; default ON with an individual OFF cook creating no post, followed by a New Version using the fresh ON default and normal comparison/publication; light large-text friend identity/request and comment-report surfaces. The existing manual composer also passed in the preceding focused bundle. No physical device, real Apple authorization/deletion, full historical ranking/Cuisine/photo-sync suite or Release suite was run.

Follow-up avatar refinements prevent Save while selected photo bytes are still being prepared, freeze form edits during Save, downsample downloaded avatars to 360px, refresh the current path before removal, and allocate a new asset version if the selection changes. The late targeted light large-text setup test passed in `staygrubby-social-ux-loading-final`; its dark preview attempt failed before editor presentation was acknowledged. The harness now acknowledges the editor navigation bar before checking its preview; the same final product flow passed 1/1 in `/private/tmp/staygrubby-social-ux-avatar-ack.xcresult`. Every original avatar assertion remains. Earlier failed bundles remain failed diagnostic evidence, not green executions. No unresolved deterministic app/test failure remains.

Debug build and Simulator launch succeeded, including the final source build `/private/tmp/staygrubby-social-ux-final-build.log`. New-generation avatar preparation cannot overwrite a newer selection's loading state; cancelling selection preserves the draft/current photo. A failed photo change leaves identity/default saves explicitly acknowledged and offers Retry Save. Replacements/removal revoke the old path before best-effort byte cleanup; abandoned unpublished uploads retire during profile cleanup after 24 hours of profile inactivity, preserving the active avatar (two additional SQL assertions). No background cleanup service is introduced.

Retained light/dark screenshots were inspected: large-text minimal profile with initials and long display name; dark Feed author avatar and locked score; light New Version sharing control. Text wraps, identity remains visible beside the avatar, controls remain reachable and cooking stays primary. The new sharing-toggle label uses primary text; explanatory copy stays secondary. The default-setting copy explicitly states that shared new cooks include a food photo when present and only an unlocked score.

### Hosted deployment and verification

Read-only reconciliation before deployment found **16 aligned migrations**. After deployment, **18/18** local/hosted version/name/SQL MD5 values match, including every unchanged original migration. All **24/24** application tables retain RLS; zero anonymous API execution and zero direct authenticated private-table write grants. `Backend/schema.sql` equals all **18** ordered local migration files. The two additive migrations deployed are:

| Final local/hosted version/name | SQL MD5 | Hosted status |
| --- | --- | --- |
| `20261021214310_social_profile_photos` | d592b61697087bdc9d8d090d12caf1e2 | Deployed |
| `20261021214320_social_sharing_defaults` | cb6fae2acf27abfe8ac8945a66a2df23 | Deployed |

The draft-retention correction was committed before deployment as an ordinary follow-up diff. Local filenames were then aligned from `20261021192915`/`20261021193903` to the two Supabase-assigned versions above without changing SQL bytes. The first authorized request expired with Invalid or expired requestState; hosted history confirmed nothing had applied before a successful retry. The original 16 migrations were not redeployed.

Hosted `delete-account` is now **v4 ACTIVE, JWT verification true**, bundle SHA256 `61be13a0430ab018a0557855e79b4eac05fecc4af456b11f20bd7ac5d7a14f14`. All three deployed files read back exactly equal to the tested local sources. The update adds `profile-photos` to the existing ordered cleanup/verification loop, with the matching SQL erasure guard. Apple proof/revocation remains unchanged. No real deletion was invoked.

Hosted buckets are `cooking-photos` private / 44 objects, `social-photos` private / 0 objects and the new `profile-photos` private / 0 objects. All retain JPEG-only / 2 MiB constraints. Four deployed avatar policies bind authenticated operations to the caller-derived visibility/ownership helper; UPDATE has both USING and WITH CHECK. The internal arbitrary-viewer avatar helper is unavailable to clients. The sharing column is non-null with default false; all three existing accounts remain OFF, with no avatar/draft paths. No public/signed avatar URLs are generated. Photos never grant access to the private cooking bucket.

The hosted security advisor reports no ERROR findings or new warning category: nine existing intentional closed-table RLS/no-policy INFO findings ([reference](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)) and the existing disabled leaked-password-protection warning ([reference](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)); unused password authentication was already disabled. No Auth configuration changed.

### Data and scope preservation

All 12 original hosted fingerprint groups are identical before/after: accounts 3, rankings 3, dishes 28, attempts/items 33 each, comparisons/evidence 104, media manifests 31, Sources 11, tags 10, memberships 49, operations 59, Storage objects 44 (including retained soft-deletion history). Full count/hash values remain in SOCIAL_DEVELOPMENT_REVIEW.md. No hosted fixture data or media was created. All new SQL tests use disposable PGlite Auth/session/Storage-catalog stubs; they do not claim live Storage HTTP/S3 byte verification.

The real Simulator demo manifest remains exactly `bedd790ea8487f3b1baad442acd9092a6890b0a38cede4951aef0018469b9a51`: 1 ranking / 12 dishes / 15 attempts/items / 356 comparisons / 10 Sources / 21 tags / 48 memberships and all 190 retained media files. Its settings, SQLite history and identities are preserved. Ranking engine/models, cooking-domain store/encoder, private sync logic, official assets, configuration and Xcode identity remain unchanged from the baseline. Social publication reads server snapshots and does not alter evidence, strength, rank, score or unlock mathematics.

Final refinements mark the account-owned publication journal excluded from device backup. The preference is server-backed and fetched for the account; unreachable/unknown defaults deliberately start OFF rather than guessing ON. Pending intents belong to the device/account that created them and do not reappear merely from cooking-data restore. Already shared locked snapshots remain locked; pending formerly locked entries that unlock require manual review. Native image sharing stays independent.

### Owner release actions and limitations

1. Hosted deployment and focused readback/security/data-preservation checks are complete. Continue with physical review and the privacy/release actions below before any separately approved upload.
2. Publish the updated canonical policy through the existing website workflow and review App Store Connect privacy answers for optional profile photos/account-linked identity/content and automatic-sharing practices. Apple requires current disclosures for collected functional data; review Photos or Videos, User ID and relevant user content rather than treating optional UI as an automatic disclosure exemption: https://developer.apple.com/app-store/app-privacy-details/. No App Store Connect changes occurred here.
3. Physically test two controlled signed-in accounts after deployment: native photo selection/cancel/replace/remove; own/friend/search/request/Feed/comment avatars and refresh after block/removal; account switching with no stale avatar; setup/default ON/OFF and cross-device setting retrieval; OFF→individual ON and ON→individual OFF; a New Version; offline/photo-interrupted sharing with intact private cooking, same-device relaunch/retry and no duplicate post; Keep private; edit/re-rank/restore without new publication; locked snapshots and delayed-unlock review; native image sharing independently. Review light/dark and meaningful Dynamic Type. No physical verification is claimed.
4. Real Apple deletion/revocation remains intentionally deferred; do not turn it into a prerequisite or delete the owner's account. Automated guards/cascades cover avatar storage. Existing human moderation/release responsibilities from Social V1 remain.

Retirement/blocks are enforced on subsequent requests/refresh, not by push revocation; previously viewed/copied content cannot be recalled. Cleanup is best-effort on profile use and account deletion, not a new scheduled worker. Offline/unreachable preference reads start private. No public avatars/profile links, Universal Links/QR, Shared Cooking, notifications, Recipes, Discover, AI, commerce, archive, new version/build number or TestFlight upload was introduced.

### Git checkpoints

- `78e27a601f8e402024603872b02177037f632140` — Add private social profile photo foundation
- `2df5f94f3c969c1465100f233cc8b5d299c029e5` — Add account sharing defaults and social setup choice
- `863999035b02045e9c961cb6fd5f2273f948b15c` — Carry per-cook sharing choices through completed ranking
- `3dd6146e5a1c910eba0fdfd4cc0ac4744daa368e` — Verify social UX enhancements and document release gates
- A small deployment closeout checkpoint records the two filename alignments and current deployment documentation; its SHA and normal push result are reported after creation. The original four checkpoints are unchanged. No amend/squash/history rewrite or credential/configuration workaround is permitted.
