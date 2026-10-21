# StayGrubby Master Roadmap

Canonical product roadmap, reconciled October 20, 2026. Future sections are **planning only**, not implemented features or authorization to build them.

**DISCOVER → SAVE → COOK → RANK → REMEMBER → SHARE → INSPIRE**

Personal comparison ranking remains central. Saving something never means it was cooked or ranked. Popularity and commercial relationships never affect personal scores.

## Current status and review gates

- Core V1, Apple account gating, private structured/photo sync, versions, re-ranking, score visibility and native local sharing are implemented. Combined V1 checkpoint: `9968390465658c2a118d2668ee44a0958ea1ec1b`; release configuration: `067c7b69b223ea60067297132a765a0ccd352238`.
- User-confirmed **StayGrubby 1.0 (1)** archive, validation and **TestFlight Internal Only upload succeeded**. Upload is not outstanding. This build predates the three presentation branches.
- Completed Onboarding/Profile/Sharing work is integrated and passed physical-iPhone review as one application through [V1_INTEGRATION_REVIEW.md](V1_INTEGRATION_REVIEW.md).
- The integrated physical approval does not authorize an automatic upload, build-number change or tester addition.
- Default development is one primary workflow on main, one Simulator lane; see [PARALLEL_DEVELOPMENT.md](PARALLEL_DEVELOPMENT.md). Feature worktrees remain for later cleanup.
- Coordinated account deletion and in-app access to a canonical policy are implemented for the next release. The owner configured the Apple server credential; the ninth migration and authenticated function deployed October 20. Privacy/contact foundations use `staygrubby.com`, `https://staygrubby.com/privacy`, `privacy@staygrubby.com`, `support@staygrubby.com`, and effective date October 20, 2026. A minimal static Cloudflare Pages website is prepared. Remaining external-release gates are owner website publication, disposable-account physical Apple revocation/deletion validation, and final App Store privacy entries. No new app distribution occurred. Existing account/cloud infrastructure is substantial; do not reimplement it as a future phase.

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
- Integrated presentation: branded onboarding/loading/recovery, cooking-focused Profile/current Top 3, result identity/privacy hierarchy, preview retry and truthful native Save Image feedback. No social feed is active.

Historical physical approvals apply to their tested builds; integrated approval is separate. See integration review and [V1_FINAL_REVISIONS_REVIEW.md](V1_FINAL_REVISIONS_REVIEW.md).

## 2. Accounts + Cloud / Privacy Foundation

Already implemented: native Apple/Supabase authentication, protected permanent-account ownership, private structured/photo sync, restore, receipts/revisions/tombstones and account isolation. A minimal private profile table and case-insensitive username constraint also exist; optional social display names/usernames and discoverability are implemented; friendship/public-facing profile access remains future work. Build on this.

Implemented for the next release: deliberate account deletion UI, fresh Apple verification, a deployed server-only idempotent deletion state machine, private Storage/account/Auth cleanup ordering, exact local cleanup, and signed-in/signed-out access to the canonical policy with a public system link and offline copy. Owner-completed release closeout: the static Cloudflare website is publicly deployed with operational HTTPS/routing and App Store Connect App Privacy answers are complete. Real physical Apple credential revocation/deletion testing is intentionally deferred and remains unverified; it does not block continued core development. The single-source policy is `StayGrubby/Legal/PrivacyPolicy.md`; the app bundles it and the website build renders it. Future product work remains usernames, user-facing profiles and public/friends/private concepts; independent content visibility and social ownership/authorization; compatibility with saved recipes, creator attribution and shared cooking. Backend enforcement is mandatory, not merely hidden UI.

## 2A. Cuisine Selection — Post-TestFlight Core Enhancement

Approved for this implementation: one optional primary Cuisine per Dish, stable predefined identifiers and account-owned custom values, searchable Add/Edit selection and display-only Rankings filtering that preserves global ranks. No inference, ranking change or recommendation system. See [Cuisine architecture and verification](CUISINE_REVIEW.md).

Release-foundation owner closeout: public staygrubby.com HTTPS/routing and App Store Connect App Privacy questionnaire are complete; ninth deletion migration and delete-account v2 are deployed. Implemented and automated/security verified; real Apple credential revocation remains physically unverified and intentionally deferred by the owner. No physical Apple revocation/deletion test is claimed.

## 3. Profiles + Friends

Social identity is implemented: optional display name, unique editable @username, 30-day old-handle reservation and discoverability off by default. Mutual friendship, blocking, minimal social profile lookup and Friends UI are implemented; the bounded chronological Friends Feed is enabled. See [social review](SOCIAL_DEVELOPMENT_REVIEW.md).

Dedicated Friends experience/navigation. Prioritize **mutual friendship**, not followers: username search, requests, accept/decline, friends list/removal, friend profiles and permitted cooking activity/rankings. A profile does not publish private history. One-way following comes later for creators/chefs.

## 4. Online Safety / Moderation — before public social release

Minimum technical foundation implemented: authoritative blocks, private profile/post/comment reporting, moderation states and service-only hiding, friends-only content visibility and account-deletion cascades. Operator review/response procedures remain a distribution responsibility; no AI/vendor/admin dashboard is claimed.

Published-image moderation; text moderation for captions/comments/bios/display names/usernames; reporting, blocking, moderation states/hooks and enforcement. Build these with social authorization/lifecycles. Private local photos are not automatically public social content.

## 5. Friends Feed + Social Part 1

Chronological friends feed and explicit cooking snapshots are implemented, newest first, with pagination, friend-only social photos, private/profile boundaries and blocking/reporting/moderation. Basic likes/comments are implemented with server authorization, bounded comment pages and visible counts. No TikTok/Reels-style personalized feed. Safety/privacy dependencies precede public social release.

## 6. Shared Cooking + Social Part 2 + In-App Notifications

Tagging friends needs permission, notification, removal, approval where applicable and who-may-tag controls. No automatic unwanted publication on the tagged user's profile.

- **RANK THIS DISH:** recipient-owned cooking history/entry, safe reused metadata and normal personal ranking; never copy the original score/evidence.
- **CREATE MY OWN POST:** independent photos, notes, versions, Source and ranking; optional provenance/reference to original.
- **DISMISS:** create nothing.

Distinguish **COOKED TOGETHER** (same real-world experience, independently ranked) and **RECREATED** (new experience inspired by another), without initially building two giant systems.

Reliable in-app notifications precede push: requests/acceptance, tags, likes/comments and relevant shared-cooking interactions. Include bell/unread indicator, read state, deep links, deduplication, deleted-content handling and blocking/privacy enforcement. A notification never grants access to private content.

## 7. Personal History + Stats

Useful private history/activity and understandable statistics from actual cooking/evidence. Historical milestone/recap cards and advanced achievements need separate scope. Presentation/statistics never retune ranking math.

## 8. Recipe Engine / Food Library / Want to Cook

True Recipe identity, dedicated saved **Want to Cook** collection, add/remove/find and retained Source/creator. Saving/discovering never creates cooked/ranked entries.

**Discover → optionally Save → Cook → Made It → personal photos/notes/details → personal CookingAttempt → normal ranking.** Retain original provenance; never copy another score.

Source types remain My Own, Online, Cookbook, Restaurant, Friend/Family and Other. Later source assistance may retrieve online title/thumbnail/site/platform/canonical link and cookbook catalog title/author/cover. Avoid unnecessary manual entry; no new source taxonomy now.

Preserve original StayGrubby creator, website, cookbook/publisher or external social-post attribution. Recreation/sharing never falsely transfers authorship.

Eventually show distinct eligible users who saved/made and friends who made, rather than raw attempt counts. Private/deleted/ineligible activity must not leak. Counters are informational and never affect personal ranking.

## 9. Public Web Sharing

Intentional mobile-friendly public URLs for permitted dishes/posts/recipes/rankings/collections. Potential content: title/photo, attribution/source, intentionally public score, Save/Want to Cook, Make This, eligible counters and Open/Install StayGrubby.

Nothing becomes public automatically. Coordinate with stable Recipe identity/provenance/privacy; then do not unnecessarily delay basic public sharing. Native local image sharing stays independent.

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
