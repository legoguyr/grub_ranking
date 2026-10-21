# Shared Cooking, Recreated and In-App Notifications

## Starting state — October 21, 2026

Started on main at d42b0ed2847e2b5befeb2773fd729cd93d50f8bb, aligned with origin/main. The owner had pushed the Social UX checkpoints. One pre-existing local edit changes CURRENT_PROJECT_VERSION from 1 to 2 in both app configurations; it is preserved and excluded from feature checkpoints. No other initial changes.

Hosted baseline: 18 aligned migrations, delete-account v4 ACTIVE/JWT verification enabled, three private photo buckets, 24 RLS application tables. Private cooking fingerprints still match the prior review. Storage now has 45 objects (hash 4b135f66fa6a089b14341c5fb2fe630a), reflecting an owner-added object since the preceding closeout; this current state is the new preservation baseline. No real account, cook or media is used as a fixture.

## Checkpoint 1 — backend/domain foundation

Implementation in progress; deployment and app integration are not yet claimed complete.

Four purpose-specific closed/RLS tables: shared_cooks, shared_participants, cooking_origins and social_notifications. Every object has a stable UUID independent of display names/usernames. An event belongs to the creator's independently completed cook and snapshots only deliberately disclosed title/course/cuisine/public source attribution. One event per owner/cook, up to eight current friends. Participants independently transition pending → joining → joined, or declined/removed. Joining reserves a durable server-owned personal item ID; only the recipient's own later synced cook can complete it. A repeated claim returns the same identity, including across devices. Neither a claim nor an abandoned form creates private cooking or ranking evidence. Existing CookingStore and ranking engine remain authoritative.

Recreated origins reference an accessible friend's controlled social post, not their private cooking graph. One account/post claim is idempotent. New social posts snapshot explicitly shareable metadata; old posts provide only their existing title. Cookbook/restaurant/online creator attribution is distinct from StayGrubby provenance. Private notes, Friend/Family names/notes, URLs, allergens/dietary annotations, comparisons, scores and private-photo paths are not copied. No automatic photo copy is introduced.

Owner-derived narrow social_cooking and social_notifications RPCs have no client-supplied actor/recipient authority. Notification rows arise only from canonical friendship/engagement/event/provenance transitions; no arbitrary notification-create endpoint. Stable dedupe keys suppress retries/repeated likes. Chronological 25-row pages use time/UUID cursors; unread counts cover all currently accessible rows. Current relationship/block/moderation/source visibility gates every read/action/count, not only creation. Read state is recipient-owned. No self-notifications, push or engagement ranking.

Relationship removal retires pending/joining invitations; completed private cooking is never touched. Owner deletion cascades events/participants, nullifies surviving recipients' social origin references and removes actor/recipient notifications. Each recipient's private cook/item/comparisons remain independently owned. Deleted/inaccessible targets are suppressed; notification dedupe history can remain until account cleanup. Existing deletion function's three-bucket cleanup is sufficient because this phase adds no bucket/byte transport. Real Apple deletion is not performed.

Future public StayGrubby web links are routing/deep-link surfaces into the native app, not a public recipe/content website. UUID/provenance contracts support that future layer; no public route, Universal Link, Associated Domain, QR, web profile/feed/recipe page is implemented here.

Local foundation checks: 35 Shared Cooking/provenance, 21 notification, 82 complete schema/RLS/grants, 25 directly affected post and 31 interaction assertions passed (194 total) in disposable PGlite/Auth/Storage-catalog fixtures. These do not claim live Auth/Storage byte tests. App/integration/deployment evidence will be appended as completed. Secret/local-artifact scan passed; whitespace checks passed. No full historical/Release/physical suite is required by default.
