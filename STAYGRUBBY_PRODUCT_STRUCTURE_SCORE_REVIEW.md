# StayGrubby product structure and score review

## Starting audit

October 22, 2026: `main` at `11a0bbd3c5e09ce559234b6bf51f56099d29f85e`, clean and synchronized with tracking `origin/main`. The approved design checkpoints are ancestors. The owner's build 2 is already committed in `11a0bbd`; it is not an uncommitted edit to exclude. Keep the warm editorial design and official assets.

One primary agent and one Simulator lane. No physical testing, distribution, destructive hosted operations, reset or Recipe Engine implementation. Risk-based checks at each checkpoint, one broader affected integration near completion.

Baseline: the complete demo manifest matches SHA-256 `bedd790ea8487f3b1baad442acd9092a6890b0a38cede4951aef0018469b9a51`: 1 ranking, 12 dishes, 15 attempts/items, 356 comparisons, 10 sources, 21 tags, 48 memberships and 190 media files. Fresh hosted fingerprints captured before edits: 3 accounts/rankings, 32 dishes, 37 attempts/items, 133 comparisons, 13 sources, 10 tags, 51 memberships, 35 media records, 68 sync receipts, 5 social posts, 1 comment and 57 Storage objects. The 45-object figure from the prior review predates owner activity; this cycle preserves the current baseline. All 21 hosted migration hashes match local SQL; all 32 application tables have RLS.

## Navigation checkpoint

Four native tabs: Grub List, Grub Rank (default), Food Bible, My Kitchen. Food Bible now hosts the existing Recipes/Tickets library; Recipes and private want-to-cook Tickets are selected within it. The redundant completed-cook browser and standalone Tickets tab are removed. Grub Rank and its existing Detail/creation routes remain the photographic cooking record. Existing Ticket save/remove, Recipe revision, Make This and historical provenance contracts are retained. Current Tickets reference accessible Recipes; no separate inspiration-ticket model exists, and none is invented here. The library's existing Recipe service/content abstraction remains available for the later on-device Recipe Engine.

## Profile, Settings and post presentation

My Kitchen leads with an 88-point profile photo/initials, full-width display name and @username. Its own published, active, server-authorized posts live in a compact three-column food grid (one column at accessibility sizes), keyed by stable post IDs, with named button semantics and one Post destination. No follower/following counters or duplicate Food Bible/Recipe/Ticket shortcuts. Signature Dishes still derive from true global ranks, now compact rows rather than a dominating hero; score/export gates and truthful private counts are retained.

Sous Chefs still points to the existing FriendsView. The old intrinsic-width text link inside an adaptive shared row did not establish an explicit full-row interaction shape. The replacement has a full-width label, minimum 44-point height and rectangular hit area; a test taps its padded far-right edge and verifies connections, Find Sous Chefs and Requests. This addresses the observed control geometry/wiring; physical-device confirmation remains the owner's review, not a claim made from Simulator.

Settings uses native full-width grouped sections with StayGrubby colors. Account contains Profile and Account & Sync; Social contains Sharing Preferences and Sent Requests; Privacy & Safety contains Blocked Accounts and truthful mutual-friend/discoverability guidance; Support & About contains Privacy Policy, Support and version/build. Account & Sync separates sign-in/synchronization, the bundled Privacy Policy and destructive Account Actions. There is one Profile editor, directly reached from Settings, with photo, name, username and discoverability. Sharing defaults have one dedicated settings destination; editing Profile omits that unrelated field so it preserves the current server setting. No pretend public/private follower control. Existing account confirmation, Apple authorization cancellation, safe scratch restore, Retry and sign-out remain supported.

Grub List remains chronological, with no Shared by Me mode; that experience is now the profile grid. Its food preview opens Post Detail. Detail retains Hands, comments, Run It Back and authorized provenance, adds full description, existing consented Course/Cuisine/public source attribution and an authorized linked Recipe. Unconsented dietary/allergen fields are omitted. No private cooking history is fetched to enrich another person's post.

Owned-post overflow offers Edit Post (description only) and Delete Post with confirmation. Other-post overflow offers existing Report and Block with confirmation. No unsupported social export action is advertised; existing private native image sharing remains unchanged. Native navigation is driven by one explicit button action at a time. Verification found that multiple NavigationLinks inside one feed List row could trigger both Post and Run It Back; explicit route state at the owning screen removes this competing-row selection. Profile-grid buttons similarly retain their own accessibility identity and independent routes.

## Description and privacy contract

Personal Notes are labeled private in the cooking form and Detail. A Post Description starts empty in the manual composer, is independently authored, and is never initialized from a cooking note. Automatic publication supplies no description. Feed descriptions truncate at three visual lines; Detail shows the complete text. Edit Post changes only the description, including clearing it. Empty descriptions are omitted without filler.

Additive `social_post_descriptions_profiles` migration: nullable `social_posts.post_description`, maximum 2,000 Unicode characters, paragraphs allowed, other control characters rejected. Existing rows remain null. Preparation sets it only for a genuinely new snapshot; retries/old clients never overwrite an existing caption. Owner-only `editDescription` rejects deleted, unpublished or moderated posts; concurrent caption-only edits use last-write-wins, with no new conflict protocol. Profile pages use the existing actor/visibility predicates, descending timestamp/ID keyset pagination and 25-row bound. All tables remain RLS-protected with no added direct grants. Helpers have explicit empty search paths and private execution privileges.

Post cards expose only explicitly allowlisted fields from the already-consented safe snapshot. No live private notes, private Source URLs, Friend/Family identity, tags, allergens, comparison evidence, rank or sync payload enters social serialization/AX. Authorized linked Recipes retain their existing independent visibility test. Block, friendship removal, moderation, source deletion and account deletion retain existing access and cascade behavior. Previously viewed/exported information cannot be recalled; access changes take effect on the next request/refresh, as before. The in-app Privacy Policy now describes optional captions/profile grids; no website publication was performed.

## Score philosophy and exact mapping

Rank answers “How does this compare with everything else I cooked?” Score answers “How good did I actually think this was?” Rank continues to sort quantized BT latent strengths, then the existing stable identity tie-breaks. Reaction is never a ranking key and never modifies BT fitting, acquisition, outcomes or historical comparisons.

`ScoreCalibration` version 1 is a presentation transform. Let `s` be the existing regularized BT latent strength and `σ(x)=1/(1+exp(-x))`:

| Assessment | Displayed score before one-decimal formatting | Soft range |
| --- | --- | --- |
| Liked it | `7 + 3 × σ(s / 1.6 − 0.4)` | 7–10 |
| It was fine | `4.8 + 3 × σ(s / 1.6)` | 4.8–7.8 |
| Didn't like it | `1 + 4.8 × σ(s / 1.6)` | 1–5.8 |
| No known explicit assessment | `1 + 9 × σ(s / 2)` | Original legacy mapping |

These are smooth overlapping regions, not hard clamps or rank percentiles. Stable positive/negative sigmoid evaluation avoids exponential overflow. No collection minimum/maximum normalization, forced #1=10, fake endpoints, evidence deletion or model retuning. One-decimal display ties are expected; distinct strengths retain distinct real positions. Extreme supported scores may round to endpoints, but normal #1 need not reach 10.

Three approaches were compared across latent strengths −4, −2, 0, 2 and 4. Clamping the old score to the Liked range collapses the first three estimates to 7.0. A 55% Liked-anchor/45% old-score blend gives a Liked estimate at −4 only 5.6, violating semantic intent. The selected bounded nonlinear mapping differentiates those estimates as 7.2, 7.5, 8.2, 9.1 and 9.7. Fine gives 5.0, 5.5, 6.3, 7.1, 7.6; Disliked gives 1.4, 2.1, 3.4, 4.7, 5.4. The 1.6 scale gives useful within-band movement without a steep response to one observation; the Liked offset avoids treating a neutral/uncertain strength as already exceptional. Adjacent bands overlap, so reaction does not impose a disjoint pseudo-ranking. No ML or external scoring API.

Initial completion already persists `initialReaction` in the existing syncable diagnostic JSON. A completed re-rank atomically appends legitimate evidence and adds `latestSemanticReaction`/`scoreCalibrationVersion` in that same opaque JSON, preserving all original/unknown diagnostic keys. The latest recognized assessment wins, then recognized initial reaction, then deterministic legacy mapping. No inference from an old numerical score. Cancelled/incomplete sessions write nothing; re-ranking keeps the same Dish/CookingAttempt/RankedItem and does not count again. The existing sync graph carries these bytes without a local/hosted cooking schema change; restore is passive and deterministic. Invalid non-object diagnostic bytes remain readable through legacy fallback; a completed re-rank refuses to overwrite malformed diagnostics silently.

The separate additive `semantic_score_presentation` migration mirrors the exact formula for genuinely new social snapshots. Original server eligibility/unlock checks remain authoritative. Existing social snapshots, including their numerical score, are not rewritten by reaction changes or deployment; explicit future publication uses the current assessment. No ranking/cache/evidence row is changed by this SQL helper.

Score colors remain the approved accessible coral/orange/gold palette and displayed thresholds: below 5.0 coral, 5.0–7.5 orange, 7.6+ gold. Liked cannot enter coral territory. Native scores use the central palette; exported cards/preview images retain official brand red. Numerical labels and lock/progress text convey meaning without relying on hue. Official assets, renderer layouts and export privacy are untouched.

Unlock remains 10 eligible ranked cooks/versions. Versions count independently; re-ranks do not. Locked native/AX/export values remain absent; dropping below 10 relocks. Calibration does not write a new final-score cache or reset evidence. Historical social/native exports retain their existing snapshot semantics.

### Preserved demo, read-only calculation

The following values are computed from existing strengths and explicit initial reactions; no demo record was rewritten. The 15 identities and their true order are unchanged.

| Rank | Cook/version | Reaction | Previous display | Calibrated display |
| --- | --- | --- | --- | --- |
| 1 | Herb-Crusted Lamb Chops — Rosemary & Lemon | Liked it | 7.3 | 9.0 |
| 2 | Harissa Chicken Kabobs — Smoky Sunday | Liked it | 6.9 | 8.8 |
| 3 | Red Wine Braised Short Ribs — Sunday Braise | Liked it | 6.8 | 8.8 |
| 4 | Sea Bass with Corn Velouté — Summer Corn | Liked it | 6.7 | 8.7 |
| 5 | Herb-Crusted Lamb Chops — Mint & Garlic | Liked it | 6.2 | 8.5 |
| 6 | Tomahawk Steak — Cast-Iron Finish | Liked it | 5.9 | 8.4 |
| 7 | Butter Chicken — Weeknight Curry | Liked it | 5.5 | 8.2 |
| 8 | Sea Bass with Corn Velouté — Brown Butter & Charred Corn | Liked it | 5.3 | 8.1 |
| 9 | Lemon Olive Oil Cake with Toasted Almonds — Weekend Bake | Liked it | 5.1 | 8.0 |
| 10 | Matzo Ball Soup — Family Friday | It was fine | 5.0 | 6.1 |
| 11 | Harissa Chicken Kabobs — Oven-Roasted Batch | It was fine | 4.8 | 6.0 |
| 12 | Persian Street Corn — Lime & Saffron | It was fine | 4.5 | 5.9 |
| 13 | Israeli Curried Couscous — Version 1 | It was fine | 4.4 | 5.9 |
| 14 | Moroccan Carrots — Cumin & Orange | It was fine | 4.1 | 5.7 |
| 15 | Tuna Crispy Rice — First Try | It was fine | 4.1 | 5.7 |

A counterfactual Liked assessment at the preserved #11 strength (−0.5856) produces 8.0; its existing actual assessment is Fine, so it correctly displays 6.0. This is a generic transform, not an item-name/rank special case. The #1 remains below 10. Adjacent entries share displayed scores while retaining their exact ranks.

## Future public/private follower model — recommendation only

Keep this cycle's mutual friendships, approval, feed rules, Shared Cooking eligibility and authoritative blocks intact. A future migration should introduce an explicit account-visibility setting (existing users remain private) and a directed follow edge with pending/accepted states. Preserve every current friendship as two accepted directed relationships, without publishing any old private cooking or friends-only post. Public discovery/following is not permission to expose private CookingGraphs; social post/Recipe audience must remain an explicit, separately enforced choice. A public account's authorized social content may be viewed/followed without approval, while private accounts require approval.

Deploy/test policy and migration compatibility first, then profile/follow UI, then adapt Feed/notifications. Retain the mutual-friend compatibility predicate for invitations, Tag a Sous Chef and existing Shared Cooking until each dependency has a deliberate contract. Blocking must override both directed edges and every profile/post/media/notification read; removal and account deletion need corresponding cleanup. Counters must be real authorized aggregates, never inferred or fabricated. Avoid automatically making an existing friends-only snapshot public. No follower table, visibility migration or public-content permission was implemented here.

## Verification record and limitations

Focused navigation library bundle: `/private/tmp/staygrubby-structure-library.xcresult`, 2 Recipe/Ticket lifecycle tests passed. Profile correction bundle: `/private/tmp/staygrubby-structure-profile-fix.xcresult`, 3 tests passed (native privacy/deletion confirmation without real authorization, Profile setup and avatar save/remove). Final calibration unit bundle: `/private/tmp/staygrubby-calibration-final-unit.xcresult`, 6 methods / 13 parameterized executions passed, zero failures/skips.

Simulations cover sizes 1, 2, 9, 10, 15 and 40, all three uniform assessment collections, mixed/contradictory assessments, repeated wins/losses, calibrated weak/strong collections, a low-ranked Liked entry, distinct ranks with equal formatted scores, no forced endpoints and deletion/refit. Re-rank tests cover all three assessments at 1/2/9/10/30 entries, cancelled/incomplete sessions, historical evidence retention, unchanged item/cook identities/counts, retry idempotency and existing sync/reopen behavior. Newly added legacy coverage verifies that a cook with no diagnostics gains only an explicit latest assessment at completion, without inventing history or exposing a locked score.

Eight focused backend files passed 264 assertions: descriptions/profile pages (43), score parity/publication (46), posts (25), chronological feed (15), interactions (31), Shared Cooking (46), Recipes/Tickets (42) and sharing defaults (16). They cover owner/stranger/friend/block/moderation/deletion, direct-table/helper denial, pagination, Unicode limits, old-client retries, no note serialization, unchanged private records, server/client formula vectors and immutable old score snapshots. No hosted fixture users, posts, media or private cooking writes were performed.

One broader affected integration ran to completion despite the MCP connection's five-minute timeout; the native result bundle `/private/tmp/staygrubby-product-integration.xcresult` is authoritative. It contains 122 methods / 181 executions: 120 methods / 179 executions passed, 2 failed, 0 expected failures/skips. All 93 unit methods / 152 parameterized executions passed. The two UI failures were a leftover five-tab assertion (contradicting its adjacent new four-tab assertion) and a Settings helper waiting for a lazy offscreen row before scrolling. Corrected tests retain actual route, hit-target, status/Retry, restore, sign-out and privacy assertions. Only those targets and directly affected final surfaces are rerun; no second broad suite is run.

Earlier focused verification found and corrected real sheet-presentation anchoring, grid accessibility identity and competing feed-row navigation issues. Initial new simulation assertions were corrected to apply the Liked invariant only to Liked data, choose two estimates on the same decimal side, and compare independent floating-point refits within the existing 1e-12 tolerance; exact ordering and untouched-strength checks remain. No meaningful test was skipped/disabled. Final follow-up results are recorded below after completion.

Both additive migrations are deployed with exact local SQL hashes:

| Hosted/local version | Migration | MD5 |
| --- | --- | --- |
| 20261022215228 | social_post_descriptions_profiles | 12057b1d0124141c9d883748e6634358 |
| 20261022220341 | semantic_score_presentation | 5417719d52ad15f69fad9f32c356c8df |

All 23 migration versions/names/hashes align. Read-only hosted checks pass for all 32 application-table RLS flags, authenticated-only API endpoints, inaccessible helpers, five still-null old descriptions and synthetic score formula parity. The security advisor has the same intentional RPC-managed deny-all-table INFO notices and pre-existing [disabled leaked-password-protection advisory](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection); no Auth/secret configuration changed. No new security advisory was introduced.

The complete demo manifest remains byte-for-byte semantically identical, including housekeeping tables, identities, strength/uncertainty, diagnostic JSON, comparisons/relationships and 190 media files. All 27 hosted data/storage fingerprint groups match the fresh starting baseline (excluding only the new nullable description key when comparing the old row shape). Storage stays 57, old social posts stay 5 and old descriptions stay null. The frozen RankingEngine directory, RankingList sorting/refit, private Sync directory, official assets, client configuration and Xcode project remain unchanged against starting HEAD. Build 2 is preserved. The intentional score changes are computed presentation; stored strengths/evidence are unchanged.

Visual attachments reviewed include four-tab/default navigation, Food Bible Recipes/Tickets, full-width My Kitchen identity, own grid with photo/no-photo, Sous Chefs connections/Find/Requests, native Settings/Profile editor, Grub List preview, owned overflow, Post Detail/caption, and calibrated gold/orange/coral native scores/Detail in light/dark. Large Dynamic Type uses one-column profile posts and wrapping text; Reduce Motion preserves explicit state and existing native navigation. Stable labels expose title/version and actions, not private notes or locked scores. Existing score-color image tests verify contrast, boundaries 4.9/5.0/7.5/7.6, actual native semantic ink and official-red photo/fallback/Top 3/milestone exports. Synthetic fixture photos are not a claim of physical food-photo or haptic review.

No physical-device test, real Apple authorization/account deletion, data reset, TestFlight/App Store activity, account/credential change, AI/Recipe Engine, public follower graph, push, Stars or unrelated product phase was performed. A new Release build/full frozen photo-sync or 500-item acquisition stress matrix is not repeated: this is a focused product correction, the affected Debug build/tests and frozen-source/data checks establish the relevant boundaries. Physical feel and independent real-account social visibility remain owner-review items. Old exported/social score snapshots intentionally retain historical values; existing exports cannot be recalled. The pre-existing website/AASA/external-tester release tasks are not expanded by this cycle.

## Owner physical review and next cycle

Use existing data without resetting it. Review these exact areas:

1. Four tabs, Grub Rank default, Food Bible Recipes/Tickets switching, Ticket save/remove and Make This into an independently ranked cook.
2. My Kitchen photo/name/@username, compact Signature Dishes, own photo/no-photo grid, and opening the intended post. No duplicate Recipe/Ticket/history shortcuts or fake follower counts.
3. Tap both the text and padded edges of Sous Chefs; open connections, Find and Requests. Check Settings/Profile is full-width, discoverability is truthful, and Sharing Preferences is the single default-setting location.
4. Put distinctive Personal Notes on a controlled cook. Confirm they remain private; manually author a different optional Post Description. Check preview truncation, full Detail, edit/clear and that re-sharing never silently overwrites an old caption. Delete only a controlled social test post and confirm its private cook remains.
5. With independent accounts, check authorized other-profile posts, linked Recipe/public attribution, Hands/comments/Run It Back and existing Shared Cooking/notification paths. Check overflow Report/Block confirmation/access boundaries without destructive real-account testing.
6. Review Liked/Fine/Disliked scores, including Liked below stronger cooks and Disliked near the top of a weak collection. Confirm true rank labels/order, legitimate one-decimal ties, positive Liked presentation and no forced 10. Check native semantic colors versus fixed-red exported previews/cards.
7. Complete and cancel re-ranks: latest completed reaction may change semantic score, but existing identities/counts/evidence remain. Check 9/10-entry locking/unlocking/relocking only with controlled test cooks, plus version modes, persistence/sync and relaunch. Never reset the existing library.
8. Check light/dark, large Dynamic Type, VoiceOver grid/overflow labels, scrolling and Reduce Motion on the changed screens. No account-deletion or distribution action is needed for this review.

The next functional cycle can be Intelligent Recipe Engine V1 after owner acceptance of these corrections. Food Bible and existing owner/revision/Ticket/Make This services are ready as its home. A future component/section representation must be additive and preserve old recipes/historical snapshots. Keep on-device-first parsing behind an abstraction, $0 paid AI/API cost, editable output and manual/deterministic fallback. None of that engine was implemented now.

### Final follow-up and checkpoint closeout

`/private/tmp/staygrubby-product-final-targets.xcresult`: 14 methods / 28 executions, 13 methods / 27 executions passed, one expanded palette test failed because its coarse scroll placed the row behind the fixed ranking controls. Both original integration failures, all 8 selected unit methods / 22 parameterized executions (including the new legacy case) and the other 5 selected UI methods passed. The UI hierarchy confirmed that the app remained on Grub Rank, not an app-navigation failure. The palette harness now uses measured short held drags and requires the row to be entirely between the filter strip and tab bar before tapping; destination and exact numerical-score assertions remain.

`/private/tmp/staygrubby-product-palette-precise.xcresult`: the sole affected palette method passed in both light and dark appearances, 0 failures/expected failures/skips. Its final screenshots show all three semantic bands and the matching lower-score Detail, with native rank unchanged. Final grid captures show aligned square media, stable title/version accessibility and the one-column large-text layout. Re-sharing an existing post preserves its old caption and explicitly explains that Edit Post is the separate update path; publisher/backend retry tests retain that boundary.

Across the latest applicable results, all 94 selected unit methods / 153 parameterized executions and 31 distinct UI methods pass. This combines the broader selected integration, focused corrections and two unchanged Recipe/Ticket lifecycle targets from the navigation checkpoint. It is not a claim that the whole repository test scheme was rerun or that the original broader bundle had zero failures. There are no unresolved failures, expected failures or skips in this selected verification. Debug compilation succeeds. No second broad integration or new Release/device/distribution run was needed.

Final privileged-secret/local-artifact scan and staged/unstaged whitespace checks pass. Local backups, dependency/build products, Simulator captures, fixture media, local Supabase state and credentials are excluded. No owner changes remain uncommitted; the pre-existing build update remains exactly as committed in starting HEAD.

Final verified implementation HEAD: `4652cbe4ad61c162c98fc37b73cb468ca8bf5c88`. The documentation-only closeout commit containing this section is the final Git HEAD for this run; its resolved SHA and the normal-push result are supplied in the final delivery (a commit cannot embed its own resulting hash). Four implementation checkpoints:

| SHA | Checkpoint |
| --- | --- |
| `dd13ffc7079a024ce4f7b077bf2f6acf192c3e69` | Navigation / Food Bible |
| `d2e9be691318113c9cb5e095830ca97ac49f83a8` | Profile / Settings / posts / caption privacy |
| `820252fca891fc495ba82097eb9f012d0a302cb3` | Score calibration / simulations / hosted mirror |
| `4652cbe4ad61c162c98fc37b73cb468ca8bf5c88` | Final integration refinements and verified test corrections |

Complete changed-file inventory against starting HEAD: 59 files. The final documentation checkpoint adds no application behavior.

- `Backend/schema.sql`
- `Backend/tests/score-calibration.test.mjs`
- `Backend/tests/social-descriptions-profiles.test.mjs`
- `RANKING_MODEL.md`
- `SOCIAL_ARCHITECTURE.md`
- `STAYGRUBBY_PRODUCT_STRUCTURE_SCORE_REVIEW.md`
- `StayGrubby/Accounts/AccountView.swift`
- `StayGrubby/Accounts/AuthenticationGateView.swift`
- `StayGrubby/Accounts/KitchenIdentityHeader.swift`
- `StayGrubby/Accounts/ProfileContent.swift`
- `StayGrubby/ContentView.swift`
- `StayGrubby/Cooking/CookingReRankingWorkflow.swift`
- `StayGrubby/Cooking/CookingStore.swift`
- `StayGrubby/Cooking/ScoreCalibration.swift`
- `StayGrubby/Legal/PrivacyPolicy.md`
- `StayGrubby/Models/RankedItem.swift`
- `StayGrubby/Models/RankingStore.swift`
- `StayGrubby/Sharing/ScoreUnlockReviewFixture.swift`
- `StayGrubby/Social/AppLinks.swift`
- `StayGrubby/Social/CookingSharingChoice.swift`
- `StayGrubby/Social/FriendsView.swift`
- `StayGrubby/Social/KitchenSettings.swift`
- `StayGrubby/Social/RecipeViews.swift`
- `StayGrubby/Social/SocialAvatar.swift`
- `StayGrubby/Social/SocialFeedView.swift`
- `StayGrubby/Social/SocialIdentity.swift`
- `StayGrubby/Social/SocialIdentityView.swift`
- `StayGrubby/Social/SocialNotifications.swift`
- `StayGrubby/Social/SocialPost.swift`
- `StayGrubby/Social/SocialPostActions.swift`
- `StayGrubby/Social/SocialProfilePosts.swift`
- `StayGrubby/Social/SocialPublication.swift`
- `StayGrubby/Social/SocialReview.swift`
- `StayGrubby/Social/SocialSettingsView.swift`
- `StayGrubby/Social/SocialShareView.swift`
- `StayGrubby/Views/Cooking/AttemptDetailView.swift`
- `StayGrubby/Views/Cooking/CookingMetadataForm.swift`
- `StayGrubby/Views/Cooking/CookingRankingResultView.swift`
- `StayGrubby/Views/Cooking/FoodBibleView.swift`
- `StayGrubbyTests/AppConfigurationTests.swift`
- `StayGrubbyTests/CookingReRankingWorkflowTests.swift`
- `StayGrubbyTests/ScoreCalibrationTests.swift`
- `StayGrubbyTests/ScoreUnlockPolicyTests.swift`
- `StayGrubbyTests/ShareCardModelTests.swift`
- `StayGrubbyTests/SocialPostDescriptionTests.swift`
- `StayGrubbyUITests/AccountEntryUITests.swift`
- `StayGrubbyUITests/DesignReviewUITests.swift`
- `StayGrubbyUITests/ProductStructureUITests.swift`
- `StayGrubbyUITests/ProfileUITests.swift`
- `StayGrubbyUITests/RecipesLinksUITests.swift`
- `StayGrubbyUITests/ScoreCalibrationUITests.swift`
- `StayGrubbyUITests/SocialFeedUITests.swift`
- `StayGrubbyUITests/SocialIdentityUITests.swift`
- `StayGrubbyUITests/SocialIntegrationUITests.swift`
- `StayGrubbyUITests/SocialUXUITests.swift`
- `StayGrubbyUITests/StayGrubbyUITestHelpers.swift`
- `UI_ARCHITECTURE.md`
- `supabase/migrations/20261022215228_social_post_descriptions_profiles.sql`
- `supabase/migrations/20261022220341_semantic_score_presentation.sql`

Ready for owner physical-iPhone review using the checklist above. No current implementation blocker remains in the selected scope. The Intelligent Recipe Engine may be planned next after owner acceptance; it has not begun.
