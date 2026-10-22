# Shared Cooking, Recreated and In-App Notifications

## Starting state — October 21, 2026

Started on main at d42b0ed2847e2b5befeb2773fd729cd93d50f8bb, aligned with origin/main. The owner had pushed the Social UX checkpoints. One pre-existing local edit changes CURRENT_PROJECT_VERSION from 1 to 2 in both app configurations; it is preserved and excluded from feature checkpoints. No other initial changes.

Hosted baseline: 18 aligned migrations, delete-account v4 ACTIVE/JWT verification enabled, three private photo buckets, 24 RLS application tables. Private cooking fingerprints still match the prior review. Storage now has 45 objects (hash 4b135f66fa6a089b14341c5fb2fe630a), reflecting an owner-added object since the preceding closeout; this current state is the new preservation baseline. No real account, cook or media is used as a fixture.

## Checkpoint 1 — backend/domain foundation

Backend foundation deployed as 20261021224851_shared_cooking_notifications (SQL MD5 3e527a744c0420b41b4d6c44270d748b). All 19 local/hosted migration hashes matched after filename alignment. All 28 tables retain RLS, no anonymous API execute/direct client writes, three buckets remain private (cooking44/social1/profile0). All 12 starting private/storage fingerprint groups are unchanged. App integration is now complete at the automated/Simulator scope; final evidence and limitations follow.

Four purpose-specific closed/RLS tables: shared_cooks, shared_participants, cooking_origins and social_notifications. Every object has a stable UUID independent of display names/usernames. An event belongs to the creator's independently completed cook and snapshots only deliberately disclosed title/course/cuisine/public source attribution. One event per owner/cook, up to eight current friends. Participants independently transition pending → joining → joined, or declined/removed. Joining reserves a durable server-owned personal item ID; only the recipient's own later synced cook can complete it. A repeated claim returns the same identity, including across devices. Neither a claim nor an abandoned form creates private cooking or ranking evidence. Existing CookingStore and ranking engine remain authoritative.

Recreated origins reference an accessible friend's controlled social post, not their private cooking graph. One account/post claim is idempotent. New social posts snapshot explicitly shareable metadata; old posts provide only their existing title. Cookbook/restaurant/online creator attribution is distinct from StayGrubby provenance. Private notes, Friend/Family names/notes, URLs, allergens/dietary annotations, comparisons, scores and private-photo paths are not copied. No automatic photo copy is introduced.

Owner-derived narrow social_cooking and social_notifications RPCs have no client-supplied actor/recipient authority. Notification rows arise only from canonical friendship/engagement/event/provenance transitions; no arbitrary notification-create endpoint. Stable dedupe keys suppress retries/repeated likes. Chronological 25-row pages use time/UUID cursors; unread counts cover all currently accessible rows. Current relationship/block/moderation/source visibility gates every read/action/count, not only creation. Read state is recipient-owned. No self-notifications, push or engagement ranking.

Relationship removal retires pending/joining invitations; completed private cooking is never touched. Owner deletion cascades events/participants, nullifies surviving recipients' social origin references and removes actor/recipient notifications. Each recipient's private cook/item/comparisons remain independently owned. Deleted/inaccessible targets are suppressed; notification dedupe history can remain until account cleanup. Existing deletion function's three-bucket cleanup is sufficient because this phase adds no bucket/byte transport. Real Apple deletion is not performed.

Future public StayGrubby web links are routing/deep-link surfaces into the native app, not a public recipe/content website. UUID/provenance contracts support that future layer; no public route, Universal Link, Associated Domain, QR, web profile/feed/recipe page is implemented here.

Local foundation checks: 35 Shared Cooking/provenance, 21 notification, 82 complete schema/RLS/grants, 25 directly affected post and 31 interaction assertions passed (194 total) in disposable PGlite/Auth/Storage-catalog fixtures. These do not claim live Auth/Storage byte tests. App/integration/deployment evidence will be appended as completed. Secret/local-artifact scan passed; whitespace checks passed. No full historical/Release/physical suite is required by default.

## Explicit metadata consent and cancellation follow-up

A separate additive migration requires includeAttribution=true for safe Course/Cuisine/public recipe-source metadata in a newly created social snapshot. Older clients continue sharing only the original fields; neither a retry nor the new client backfills old snapshots. The app explains this disclosure in the new-entry choice, settings and manual composer. Cooked With invitations disclose the same safe metadata explicitly; no photo is copied. The original creator can see their own identity in Recreated provenance. Owner-derived cancellation retires pending/joining invitations idempotently, including after a lost response, while preserving joined private cooking. The final local shared/provenance/security tests pass 46 assertions, including full recreation completion, locked recipient score, notification deduplication and source-creator provenance. Schema82, posts25 and notifications21 also pass against the consent migration.


## Client integration and consent

Cooked With appears only after optional social identity is configured. Its native friend/avatar selector pages current friends and caps selection at eight. Invitations are separate from Feed sharing and disclose their exact safe metadata. The owner can inspect pending/joined participants and remove pending invitations. The recipient sees Add to My Cooking or Decline; accepting opens the editable normal New Dish flow and personal ranking. A new private CookingAttempt and RankedItem are created by the existing CookingStore, with their own independently generated comparisons/score. No private schema/domain/engine changes were needed. New Versions continue using the same cooking architecture and current per-entry sharing default.

Make This on eligible friends' Feed cards opens the same prefill/ranking flow from the accessible social snapshot. Abandoning it reserves only a social origin; it creates no private cook/item/evidence. Claims use one durable server-reserved item ID per recipient/event or recipient/source-post. Reopening a completed/restored claim resolves to the existing own cook; explicit reopening can retry missing origin completion without copying/recreating private data. Once shared, the recipient's own post shows truthful Recreated/Cooked With presentation only to current permitted identities. Source attribution remains distinct from social inspiration. Existing native exported image cards are unchanged.

The account-root SharedCookingOutbox.json is owner/version validated, atomic/protected and excluded from device backup. New-cook intent is durable before the private save. Only a matching saved cook and accepted structured sync permits event/origin work. API failure preserves private history and shows Retry. Cancellation is itself durable: offline Cancel persists before retry, survives relaunch and never turns back into a new invitation. An in-flight successful invitation can be retired safely on the following idempotent cancellation. Reopening an unsaved stable-ID origin uses the latest participant/Share with Friends choices; an abandoned ON publication intent is removed before saving a new OFF choice. Existing saved/manual posts are untouched. Score-unlock review rules, photo consent, defaults and native sharing stay authoritative.

Notifications are reachable from a restrained bell in Feed and a Profile destination. Canonical types: friend request, accepted friendship, invitation, joined participant, completed recreation, like and comment. Avatars/names remain visible beside activity text. The unread indicator/count and Mark All Read are account-scoped; page size25 with an exclusive timestamp/UUID cursor. Counts cover all eligible pages, not only loaded rows. Opening first marks the authorized notice read, then routes to a minimal friend profile/request action, Shared Cooking detail, post or comments. Destinations fetch current authorization again. Background/foreground and account generation clear/discard stale content; no push or public destination is introduced. Repeated likes/retries deduplicate; different actors are chronological rows, not a new engagement-ranking algorithm.

## Final verification

| Scope | Result |
| --- | --- |
| Shared Cooking/Recreated/metadata consent/duplicate/forgery/block/removal/cancellation/deletion | 46 disposable PostgreSQL assertions passed |
| Notifications/actor-recipient isolation/read state/pagination/invalidation | 21 assertions passed |
| Complete migration reference/schema/RLS/grants/account deletion ordering | 82 assertions passed |
| Directly affected existing post/score-lock/media boundary | 25 assertions passed |
| Directly affected existing interaction boundary | 31 assertions passed |
| Focused SQL total | **205 passed** |
| Canonical policy/static-site checks | **5 passed**, no website deployment |
| Broader focused integration | **25 methods / 27 parameter-expanded executions passed**, zero failures/expected failures/skips |
| Integrated native portion | 15 methods / 17 executions across Shared Cooking, publication and session suites |
| Integrated UI portion | **10/10 passed**: seven new flows plus directly affected Feed/default-OFF/default-ON/New-Version regressions |
| Final durable cancellation/recovery/native suite | **8/8 passed**, zero failures/skips, including one additional offline cancellation test |
| Final visual checks | Light accessibility notifications1/1 and dark joined-state1/1 passed; screenshots inspected |
| Final Debug source build | Succeeded; Simulator app launches verified by isolated UI tests |

Primary bundles: /private/tmp/staygrubby-shared-integrated-final.xcresult; /private/tmp/staygrubby-shared-cancel-final.xcresult; /private/tmp/staygrubby-shared-visual-final.xcresult (light visual method passed; its earlier tab-transition miss is not counted green); /private/tmp/staygrubby-shared-joined-state-final.xcresult (final dark method passed). Final source build log: /private/tmp/staygrubby-shared-final-build.log. Backend logs use /private/tmp/staygrubby-shared-final-*.log. No full historical ranking/Cuisine/photo-sync/share-card suite, Release build or physical-device run was required or performed.

The combined pass is one focused integration pass, not an aggregation of earlier failed attempts. Earlier diagnostics found full-row hit regions missing on new buttons and a decline-state reload; both product issues were corrected. Test harnesses now acknowledge actual tab/navigation completion and use the version-aware ranking label. The old synthetic single-post endpoint ignored blocks; it now mirrors the real backend's already-enforced visibility. The synthetic completion also now updates Joined state, matching SQL. No assertion was removed or meaningful test weakened. Large-text notification body text uses semantic primary/subdued colors and leading wrapping; only the intended controls/badges use accent red. The final screenshot checks cover light accessibility text and dark Joined/duplicate protection. No unresolved deterministic app/test failure remains.

Independent-ranking coverage includes separate in-memory account containers, distinct attempt/item/comparison IDs and an unchanged source graph after the recipient's ranking. Backend tests prove a locked recipient does not inherit an unlocked original score, cannot complete a foreign origin, cannot forge provenance/notifications or access raw closed tables, and cannot recreate/tag inaccessible/blocked/removed accounts. Source-account erasure leaves the surviving recipient private fingerprint unchanged. Tests emulate Auth/JWT/Storage catalogs, not live Apple or multi-device transport. No real Apple authorization/deletion occurred.

## Hosted closeout

| Migration | SQL MD5 |
| --- | --- |
| 20261021224851_shared_cooking_notifications | 3e527a744c0420b41b4d6c44270d748b |
| 20261021235642_shared_metadata_consent | c9fe2e6f806ea90a1501acc9e54705f7 |

All **20/20** local/hosted version/name/SQL hashes match, including all 18 untouched historical migrations. Local filenames were reconciled to Supabase-assigned versions without SQL changes; Backend/schema.sql equals the complete ordered chain. The follow-up tool returned Invalid or expired requestState three times without applying; the official CLI dry run could not authenticate (vault/roles/seed changes excluded). No credentials/configuration were changed or exposed. After direct owner approval for a fresh retry, the proper migration tool succeeded. No alternate unrecorded SQL deployment was used.

All **28/28** application tables retain RLS; zero anonymous API execution, zero direct client table writes and zero client execution of the new internal arbitrary-viewer/creator helpers. The automatic metadata-capture trigger is absent; only explicit new-client consent records extended snapshot metadata. The existing hosted post still has no extended metadata, so no historical snapshot was backfilled. All four new hosted tables are empty: no test events/participants/origins/notifications were inserted. The existing delete-account function remains v4 ACTIVE/JWT verification enabled, unchanged bundle 61be13a0430ab018a0557855e79b4eac05fecc4af456b11f20bd7ac5d7a14f14. No new Edge Function or bucket was needed.

Security advisor: no ERROR finding; 13 intentional closed-table RLS/no-policy INFO findings (four new RPC-only tables) and the pre-existing disabled leaked-password-protection WARN with unused password provider already disabled. References: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy and https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection. No Auth setting was changed.

All 12 starting private/storage fingerprint groups match after deployment: accounts3, rankings3, dishes28, attempts/items33 each, evidence104, media manifests31, Sources11, tags10, memberships49, operations59, Storage45 (raw counts include retained deletion history). Buckets remain private: cooking-photos44, social-photos1, profile-photos0; no new bytes were uploaded. The starting Storage hash 4b135f66fa6a089b14341c5fb2fe630a is unchanged. Ranking/score/evidence values and identities are preserved.

The Simulator demo exactly matches manifest SHA256 bedd790ea8487f3b1baad442acd9092a6890b0a38cede4951aef0018469b9a51: 1 ranking,12 dishes,15 attempts/items,356 comparisons,10 Sources,21 tags,48 memberships and all190 media files. Frozen ranking/models/CookingStore/private sync/official assets/configuration are unchanged. The owner build-number1→2 edit is preserved exactly and excluded from these checkpoints. Secret/local-artifact scan and whitespace checks pass; no backup, dependency, build product, signing material, fixture media or local secret is included.

## Release limits and next work

Complete at the automated/Simulator scope; physical multi-account verification remains an owner release step. Before a separately approved TestFlight upload, publish the canonical policy through the existing website workflow and review App Privacy for the new explicit relationships/notifications/shared attribution. No website, Apple configuration, archive, App Store Connect or TestFlight operation occurred here.

Use two controlled signed-in accounts on devices: A selects B/Cooked With and completes ranking; B receives/reopens/joins and independently ranks, retries without duplicates, declines a second event without history, and verifies optional own publication follows OFF/ON overrides. Recreate a consented cookbook-source post, edit prefill, abandon/reopen, rank independently and verify correct source/provenance. Review request/accepted/invited/joined/recreated/like/comment notifications, read state after relaunch/account switching, pagination and block/friend removal invalidation. Interrupt sync/network, cancel a pending invite offline, relaunch/reconnect and verify no invitation/post surprise and intact private history. Verify locked/unlocked score boundaries, no hidden numerical disclosure and own photo selection; no real deletion test is required by this phase.

Deliberate limits: up to eight invitees per event; original invite selection is creation-time (pending removal/cancellation is supported), no reactivation of declined/removed invitations; one origin per account/event or account/source-post resolves to the existing cook rather than a second duplicate. Prefill starts a new own dish/cook rather than merging an existing dish automatically; recipients choose their own photos. Abandoned reservations and inaccessible dedupe history may remain until account cleanup. Refresh/foreground enforces other users' changes; no real-time recall/push. Like retries deduplicate, but multi-actor aggregation is not implemented. Optional real-device social photo transport and multi-account timing remain for physical review, not claimed by synthetic fixtures.

The exact next canonical phase is **7 — Personal History + Stats**, under separate scope. No Recipe Engine/Want to Cook, Send to Friend, public web routing/Universal Links/Associated Domains/QR, push, challenges, Discover, creator/commerce or AI infrastructure was implemented. Durable UUID/provenance contracts are compatible with a later authorized app-first link resolver; no identifier grants public access.

## Checkpoints

- e659a1291005fcecf33393206cd3cbd62ad503f1 — Shared Cooking/provenance/notification backend foundation.
- 71b8ffb69eddd9a53113b78c0a6d8756509ab4cd — Explicit metadata consent and safe cancellation.
- 4f4fb69ce44ee9e791ef16839a61fe2b372332e2 — Integrated client, outbox, native/UI tests and consent copy.
- Final verification/privacy/docs/migration-filename closeout SHA and push outcome are reported after creation. No amendment, squash, history rewrite or credential workaround is used. The only intended remaining uncommitted file is the owner's original project build-number edit.
