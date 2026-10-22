# StayGrubby Master Roadmap

Canonical product roadmap, reconciled October 21, 2026. Future sections are **planning only**, not implemented features or authorization to build them.

**DISCOVER → SAVE → COOK → RANK → REMEMBER → SHARE → INSPIRE**

Personal comparison ranking remains central. Saving something never means it was cooked or ranked. Popularity and commercial relationships never affect personal scores.

## Current status and review gates

- Core V1, Apple account gating, private structured/photo sync, versions, re-ranking, score visibility and native local sharing are implemented. Combined V1 checkpoint: `9968390465658c2a118d2668ee44a0958ea1ec1b`; release configuration: `067c7b69b223ea60067297132a765a0ccd352238`.
- User-confirmed **StayGrubby 1.0 (1)** archive, validation and **TestFlight Internal Only upload succeeded**. Upload is not outstanding. This build predates the three presentation branches.
- Completed Onboarding/Profile/Sharing work is integrated and passed physical-iPhone review as one application through [V1_INTEGRATION_REVIEW.md](V1_INTEGRATION_REVIEW.md).
- The integrated physical approval does not authorize an automatic upload, build-number change or tester addition.
- Default development is one primary workflow on main, one Simulator lane; see [PARALLEL_DEVELOPMENT.md](PARALLEL_DEVELOPMENT.md). Feature worktrees remain for later cleanup.
- Coordinated account deletion and canonical in-app/public policy foundations are implemented. The owner configured the Apple server credential, published the minimal Cloudflare website and completed the prior App Store privacy entries. Contact foundations remain `staygrubby.com`, `https://staygrubby.com/privacy`, `privacy@staygrubby.com` and `support@staygrubby.com`. The new optional-social policy is effective October 21, 2026 locally; publication and App Privacy review for social practices remain owner release actions. Physical Apple revocation/deletion verification is intentionally deferred, not a development blocker. No new app distribution occurred; do not reimplement existing account/cloud systems.

## Architecture and ranking independence

| Domain | Concepts | Boundary |
| --- | --- | --- |
| Private cooking history | Dish → CookingAttempt/version → unique RankedItem → Comparison | Things actually cooked; personal evidence, score/rank and history |
| Recipe discovery | Recipe → Source/Creator → Want to Cook relationship | Discovered/saved ideas, separate from cooking/ranking |
| Social | Profile → Friendship → Post → Tag → Like/Comment → Notification | Explicit publication and backend-enforced audience access |

A post may reference cooking; a recipe may supply provenance. Neither transfers another user's score/comparisons. Profile and post privacy are distinct. A public profile never automatically exposes private cooking records. A notification/deep link is never authorization to private content.

Likes, comments, saves, made counters, creator popularity, friend activity, sponsorship and community popularity never modify ranking evidence or scores. Every user's ranking remains independent.

## 1. Core App / V1 — current

Implemented contracts to preserve:

- iPhone upright portrait, light/dark, accessible Dynamic Type; canonical supplied **#stayGRUBBY** logo/icons and cream/red/charcoal system.
- Native Apple → Supabase → permanent account → exact account-store readiness → personal app. No production guest mode; development bypass is Debug-only.
- Local cooking/photos, notes, Sources, Course/Dietary/Contains/Avoid/custom tags, search/filter and Add/Edit/New Version workflows.
- One global comparison ranking. Top Version / All Versions are projections preserving true global ranks, not alternative ranking truth.
- Re-rank: Liked/Fine/Didn't Like → adaptive comparisons → automatic finalize/result; same CookingAttempt/version/RankedItem, retained historical evidence, no extra entry/unlock count.
- **10 eligible ranked entries/versions** reveal numerical scores; visibility only. Delete below threshold relocks without changing evidence. No score leakage through UI/export/accessibility. First-unlock celebration is locally account-scoped; passive hydration does not replay it.
- In-app score colors: muted coral 1.0–4.9, orange 5.0–7.5, gold 7.6–10.0. Exported scores always official red.
- Approved image-only sharing: photo card 1080 × 1350; universal no-photo fallback 1080 × 1080; Top 3 1080 × 1350. Private global rank/movement never exports.
- Evidence-backed achievements. NEW #1 and optional Updated Top 3 require a genuine new global leader; individual sharing stays primary. Reusable Profile Top 3 omits SCORES UNLOCKED; the genuine milestone includes it.
- Private structured/photo backup/restore, durable retry, exact identities/evidence, tombstones/account isolation and no resurrection. Existing conflict rejection remains; no silent overwrite.
- Integrated presentation: branded onboarding/loading/recovery, cooking-focused Profile/current Top 3, result identity/privacy hierarchy, preview retry and truthful native Save Image feedback. The subsequent friends-only Feed is implemented separately in section 5.

Historical physical approvals apply to their tested builds; integrated approval is separate. See integration review and [V1_FINAL_REVISIONS_REVIEW.md](V1_FINAL_REVISIONS_REVIEW.md).

## 2. Accounts + Cloud / Privacy Foundation

Already implemented: native Apple/Supabase authentication, protected permanent-account ownership, private structured/photo sync, restore, receipts/revisions/tombstones and account isolation. A minimal private profile table and case-insensitive username constraint also exist; optional social display names/usernames and discoverability are implemented; mutual friendship and minimal friend-profile access are implemented; public web profiles remain future work. Build on this.

Implemented for the next release: deliberate account deletion UI, fresh Apple verification, a deployed server-only idempotent deletion state machine, private Storage/account/Auth cleanup ordering, exact local cleanup, and signed-in/signed-out access to the canonical policy with a public system link and offline copy. Owner-completed release closeout: the static Cloudflare website is publicly deployed with operational HTTPS/routing and App Store Connect App Privacy answers are complete. Real physical Apple credential revocation/deletion testing is intentionally deferred and remains unverified; it does not block continued core development. The single-source policy is `StayGrubby/Legal/PrivacyPolicy.md`; the app bundles it and the website build renders it. Optional identity, minimal friend profiles, explicit friends-only posts and server-enforced social ownership/visibility are now implemented. Future work includes public web profiles and compatibility with saved recipes, creator attribution and shared cooking. Backend enforcement is mandatory, not merely hidden UI.

## 2A. Cuisine Selection — Post-TestFlight Core Enhancement

Implemented and deployed: one optional primary Cuisine per Dish, stable predefined identifiers and account-owned custom values, searchable Add/Edit selection and display-only Rankings filtering that preserves global ranks. No inference, ranking change or recommendation system. See [Cuisine architecture and verification](CUISINE_REVIEW.md).

Release-foundation owner closeout: public staygrubby.com HTTPS/routing and App Store Connect App Privacy questionnaire are complete; account-deletion foundation and delete-account v3 (private and social photos) are deployed. Implemented and automated/security verified; real Apple credential revocation remains physically unverified and intentionally deferred by the owner. No physical Apple revocation/deletion test is claimed. The new social policy is prepared locally; its public publication and App Privacy review remain owner actions before broader social distribution.

## 3. Profiles + Friends

Social identity is implemented: optional display name, unique editable @username, permanent anti-recycling profile-link reservations in addition to the original temporary handle reservation and discoverability off by default. Mutual friendship, blocking, minimal social profile lookup and Friends UI are implemented; the bounded chronological Friends Feed is enabled. See [social review](SOCIAL_DEVELOPMENT_REVIEW.md).

Dedicated Friends experience/navigation. Prioritize **mutual friendship**, not followers: username search, requests, accept/decline, friends list/removal, minimal friend profiles and explicitly shared cooking posts. A profile does not publish private history. One-way following comes later for creators/chefs.

## 4. Online Safety / Moderation — before public social release

Minimum technical foundation implemented: authoritative blocks, private profile/post/comment reporting, moderation states and service-only hiding, friends-only content visibility and account-deletion cascades. Operator review/response procedures remain a distribution responsibility; no AI/vendor/admin dashboard is claimed.

Published-image moderation; text moderation for captions/comments/bios/display names/usernames; reporting, blocking, moderation states/hooks and enforcement. Build these with social authorization/lifecycles. Private local photos are not automatically public social content.

## 5. Friends Feed + Social Part 1

Chronological friends feed and explicit cooking snapshots are implemented, newest first, with pagination, friend-only social photos, private/profile boundaries and blocking/reporting/moderation. Basic likes/comments are implemented with server authorization, bounded comment pages and visible counts. No TikTok/Reels-style personalized feed. Safety/privacy dependencies precede public social release.

## 5A. Social UX enhancement — implemented, verified and deployed

Optional profile photos/initials, normal Social settings, account-synced sharing defaults, social setup choice and per-entry New Dish/New Version sharing are implemented and deployed. Legacy/unset defaults OFF; each new entry can override. The completed-cook outbox reuses explicit social snapshots, preserves private ranking on failure, supports retry and pauses for review if scores unlock while a formerly locked share remains pending. Edit/re-rank/restore do not create sharing intent. Native image sharing remains separate.

At the Social UX closeout, two additive migrations and the avatar-aware account-deletion function update were deployed with 18 aligned hashes and 24 RLS tables. The subsequent Shared Cooking phase adds its separate provenance/notification foundation (see section 6). Three photo buckets remain private and original private-data fingerprints remain preserved. Physical review remains before a separately approved upload. See [Social UX implementation/review](SOCIAL_UX_REVIEW.md). Publish the updated canonical policy and review App Privacy for profile photos before broader distribution. No next-phase functionality is included.

## 6. Shared Cooking + Social Part 2 + In-App Notifications

Shared Cooking/Recreated/in-app notifications are implemented, with final integrated verification recorded in [SHARED_SOCIAL_REVIEW.md](SHARED_SOCIAL_REVIEW.md). Up to eight current friends can be invited through Cooked With after the owner's independent saved/ranked cook. Recipients explicitly Add to My Cooking or decline; claims reserve stable personal item IDs without creating cooking history. The normal editable new-cook/ranking flow creates their own attempt/item/evidence. Make This carries only consented safe metadata from accessible social posts. Retries/duplicate claims never merge rankings or copy scores. Sharing defaults/per-entry overrides still decide independent Feed publication.

Notifications cover requests/acceptance, invitations/joining, completed recreations, likes and comments. Native bell/list/read state/Mark All Read, bounded chronological pages and authorized destinations respect current friendship/block/moderation/source access. Participant consent, pending removal/cancellation, deletion/nullification and private-history preservation are enforced server-side. Physical multi-account review remains separate from automated/Simulator verification. Push, public routes, Shared Cooking analytics and future recipe systems are not implemented.

## 7. Personal History + Stats

Useful private history/activity and understandable statistics from actual cooking/evidence. Historical milestone/recap cards and advanced achievements need separate scope. Presentation/statistics never retune ranking math.

## 8. Recipe Engine / Food Library / Want to Cook

True Recipe identity, dedicated saved **Want to Cook** collection, add/remove/find and retained Source/creator. Saving/discovering never creates cooked/ranked entries.

**Discover → optionally Save → Cook → Made It → personal photos/notes/details → personal CookingAttempt → normal ranking.** Retain original provenance; never copy another score.

Source types remain My Own, Online, Cookbook, Restaurant, Friend/Family and Other. Later source assistance may retrieve online title/thumbnail/site/platform/canonical link and cookbook catalog title/author/cover. Avoid unnecessary manual entry; no new source taxonomy now.

Preserve original StayGrubby creator, website, cookbook/publisher or external social-post attribution. Recreation/sharing never falsely transfers authorship.

Eventually show distinct eligible users who saved/made and friends who made, rather than raw attempt counts. Private/deleted/ineligible activity must not leak. Counters are informational and never affect personal ranking.

The Recipes/Tickets/shareable-foundation cycle implements manual Recipe identity, private/friends recipe visibility, account-owned Tickets, editable Recipe → existing cooking/ranking, historical recipe snapshots and independent Run It Back provenance. See [RECIPE_TICKETS_SHARING_REVIEW.md](RECIPE_TICKETS_SHARING_REVIEW.md) for verification and remaining release gates. Recipe photos, discovery counters, scraping, parsing, nutrition and AI are not included.

Profile links (`staygrubby.com/@username`) now have a native authenticated resolver, durable account identity, permanent anti-recycling slug reservations, native sharing and an app-only static fallback/AASA prepared from the existing signing identity. Hosted website publication and device association verification must be checked in the review; repository configuration alone is not end-to-end Universal Link approval. QR remains deferred.

## 9. Public Web Sharing

Future public StayGrubby web links are routing/deep-link surfaces into the native app, not a public recipe/content website. Stable intentionally shareable profile/post/dish/Shared Cooking/Recreated/recipe identifiers should open the exact native destination through a later Universal-Link layer; when the app is absent, a minimal branded interstitial should primarily offer Open/Download StayGrubby.

Do not turn the website into a browsable recipe catalog, public web Feed, cooking-history site, SEO publication platform or native-app replacement. Nothing becomes public automatically; later resolvers must enforce explicit publication/privacy. Native local image sharing stays independent. No URLs, Universal Links, Associated Domains, QR or landing routes are implemented by the Shared Cooking phase.

## 10. Social + Recipe Expansion / Send to Friend

Send recipe/dish using Friends + notifications. Recipient may view, Save to Want to Cook, make a personal version, rank after cooking or dismiss. No full messaging/chat platform without demonstrated need. External sharing uses native sheets/public links.

## 11. Social Polish / Push Notifications

After reliable in-app notifications: Apple push, preferences, additional tagging/privacy controls and creator discovery improvements. No engagement spam.

## 12. Challenges + Bigger Social

Challenges/sponsored challenges only after reliable personal/social/safety foundations. Sponsorship never changes personal scores.

## 13. Creator / Commerce / Discovery — later

Possible creator profiles, one-way following, public web profiles, recipe/premium creator collections, brand/publisher partnerships, affiliate commerce and advanced discovery/trending. Tasteful website advertising may be considered; **keep conventional display advertising out of the native app**. Commercial relationships never alter personal ranking.

## 14. Personalized Taste Intelligence & Discovery

Final long-term major phase, after Friends, Social, Recipe Engine, public sharing and community discovery. Future inputs may include personal ranking/comparison history, cuisines, ingredients/proteins, techniques, flavor characteristics, recipes/original sources, permitted photos and explicit preferences/feedback. Possible outputs: individual taste profiles, favorite cuisines/ingredients/proteins, flavor profiles, personalized recipes/Discover, friend taste compatibility, recommendation explanations and optional premium advanced analytics.

AI-assisted recipe/photo analysis may suggest characteristics; images alone never prove ingredients, allergens or flavor. Distinguish taste preference from execution quality and avoid confident conclusions from small datasets. Personal ranking and recommendations remain independent: recommendations, popularity, sponsorship, social engagement and monetization NEVER alter Bradley–Terry rankings. Personal ranking remains free; subscriptions must add genuine new value rather than restricting existing core features. No AI infrastructure, processing costs or intelligence integrations are introduced now.

## Supporting references

[RANKING_MODEL.md](RANKING_MODEL.md), [COOKING_MODEL.md](COOKING_MODEL.md), [ACCOUNT_ARCHITECTURE.md](ACCOUNT_ARCHITECTURE.md), [SYNC_ARCHITECTURE.md](SYNC_ARCHITECTURE.md), [MEDIA_SYNC_ARCHITECTURE.md](MEDIA_SYNC_ARCHITECTURE.md), [UI_ARCHITECTURE.md](UI_ARCHITECTURE.md), [V1_SHARING_ARCHITECTURE.md](V1_SHARING_ARCHITECTURE.md), [TESTFLIGHT_READINESS_REVIEW.md](TESTFLIGHT_READINESS_REVIEW.md).

Keep future planning canonical here. Specialized documents explain implementation and dated verification rather than duplicating roadmap entries.

## Current authorized next cycle

The owner moved the focused manual Recipe/Tickets and profile-sharing foundation ahead of the larger later Recipe Engine/Discovery program. This does not mark that future program complete or change ranking behavior. The next separately authorized major cycle is **STAYGRUBBY DESIGN SYSTEM + FULL UI/UX + MOTION REFINEMENT**, preserving these domain/services/routes while refining the complete native experience. Do not start it implicitly. Personal History/Stats, later discovery/Send to Friend/push/challenges/commerce and final Personalized Taste Intelligence remain planned; no AI infrastructure is required.
