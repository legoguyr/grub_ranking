# StayGrubby design system and product UX review

## Starting audit — October 21, 2026

Starting `main` at `71199a987aa48db6d4ee54a423b56e74608ea514`, eight commits ahead of the tracking remote. The only pre-existing edit raises the app build from 1 to 2; preserve/exclude it. One primary workflow, one Simulator lane. No schema/backend changes are needed for presentation.

The audit found green-tinted neutral tokens inconsistent with the cream/charcoal brand, rounded typography and padded cards applied indiscriminately, two competing header styles, a profile led by generic account copy/admin controls rather than food, and Tickets/cooked history buried in profile. Social and Recipe screens used stock section rhythm and inconsistent naming. The existing comparison geometry, score privacy/export colors and owner-bound services are sound and remain authoritative.

## Design direction and IA

Warm editorial kitchen journal: cream/ink, confident system display type, restrained red interactive accents, generous major-section rhythm and fine rules. Photography supplies visual color. Reserve containers for real grouped actions; use open editorial rows for food/social content. No logo redraw, clip art, new font/network dependency, glass or decorative gradient system.

Five explicit native destinations: Grub List (shared), Grub Rank (ranked), Food Bible (actually cooked), Tickets (want to cook, with Recipes), My Kitchen (identity/signature food). The app still opens in Grub Rank. Sous Chefs and Order Up stay close to social surfaces. My Kitchen gets a secondary Settings gear; account administration belongs in Settings. Cook creation remains directly reachable from Grub Rank/Food Bible. No feature is removed and no data interpretation changes.

## Foundation contract

Colors: canonical cream `#FAF3EC`, charcoal, accessible interactive reds; approved PNG/export red stays byte-for-byte authoritative. Existing coral/orange/gold numerical score thresholds and palette remain unchanged. Photos use existing private loaders; square ranking/comparison crops, prominent dish/social heroes, compact avatars and quiet no-photo treatments. No private images become recipe/social media merely through design.

Type roles: editorial hero/page title, dish/section title, readable recipe body, quiet metadata, tabular rank/score. Use Dynamic Type styles, never fixed-height text containers. Spacing follows shared tokens; image/control/content shapes have distinct radii. Standard native selection, keyboard, sheets, confirmation and Apple authentication controls remain where familiarity helps.

Motion: short opacity/selection changes and stable-ID truthful row movement, gated by Reduce Motion. Never delay a domain action to play an effect; no score/rank interpolation. Haptics only for committed comparison/reaction/result/selection events, not every tap. Reduce Motion retains explicit selection/unread/status indications without spatial animation. Native navigation remains native.

Accessibility: selected states include checks/text; Hands explicitly explains its existing like/reaction meaning to VoiceOver; all meaningful controls retain 44-point targets; screen/section headers retain semantics; numerical scores stay gated before entering text/AX. Large text can stack metadata and actions; contrast reviewed in both appearances. Frozen exports are not recolored or restyled by this cycle.

## Implementation and verification

Implemented foundation `f80058f`, cooking/navigation/Kitchen checkpoint `861ddb3`, and social/Recipe checkpoint `b4b5920`. Integration checks and final evidence are recorded below. No physical testing, real account deletion, upload or unrelated product phase is part of this work.

### Surface decisions

| Surface | Design and retained behavior |
| --- | --- |
| Grub Rank | Editorial header, serif/tabular positions, larger square thumbnails and a true #1 hero. Signature labels use actual global positions. Top Version/All Versions, search/filters, ordering and unlock stay authoritative. A filtered leader never becomes a pretend #1. |
| Comparison | Equal square choices, stronger question/identity, touch-driven press highlight and selection haptic. Immediate existing callbacks; no artificial animation wait, queued answer, score text or score accessibility leakage. Undo/Too Tough/Skip stay explicit. |
| Food Bible | Direct cooked-history destination, photos, version/date and gated score, local search and existing Detail/creation routes. Reads completed CookingAttempts; no analytics, Recipe/Ticket adoption or new persistence. |
| Detail/forms | Photo/title lead; metadata uses open sections rather than nested cards. Edit Cook/Re-rank/Share keep their aligned action family, with New Version and explicit destructive confirmation preserved. Native pickers, keyboard, validation and cancel/save remain. |
| Completion | Restrained check/success haptic, truthful Signature Dish label and clear private native result. Existing achievement truth, auto-save, score gate, renderer and native sheet remain unchanged. |
| My Kitchen | Compact avatar/name/handle; Share My Kitchen and close social destinations, followed by prominent real Signature Dishes. Existing small counts stay below food. Account administration moves to secondary Settings. Large text stacks identity/actions. |
| Sous Chefs | Current connections, Find and Requests remain immediately visible. Request count describes the loaded page, not a fictitious total. Photos/handles clarify people; sent requests/blocked accounts retain dedicated Settings routes. |
| Settings | Account & Profile (identity/photo/username and account/sync), Social (sharing defaults/sent requests), Privacy & Safety (blocked/discoverability), Support & About. No empty notification preferences. Native administration remains familiar. |
| Grub List | Open editorial posts with large real images or compact quiet placeholders. Identity/time, dish, approved provenance and gated score remain distinct. Chronological friends-only data, pagination and privacy are unchanged. |
| Hands | One existing reaction presented as 🙌 Give Hands / N Hands. VoiceOver explicitly explains like/unlike. A successful server reply produces small feedback; existing like/unlike RPC, counts and idempotency are unchanged. |
| Order Up! | Actor avatars, explicit unread dot plus quiet unread surface, chronological read/navigation and Mark All Read. No fabricated counts or persistent new notification behavior. |
| Tag a Sous Chef | Photo, name, handle, checkmark and selected count/limit over the existing eligible-friends selection. Haptic/short selection response; invitation consent, safe metadata and acceptance remain untouched. |
| Run It Back | Social action and provenance wording now distinguish inspiration from copying private data or a score. Existing independent cook/rank/photo and Recipe/social provenance separation remain. |
| Recipes | Strong title/source hierarchy, readable spaced ingredients/numbered instructions and prominent Make This. Recipe editor shares open form grouping. Historical snapshot/revision/ownership/visibility remain unchanged. No invented recipe photos. |
| Tickets | Direct want-to-cook destination; distinct Ticket eyebrow and Recipe summaries. Saving/removing never ranks a cook. Existing Ticket removal, Recipe detail and Make This are retained. |
| Onboarding/sharing | Official wordmark with comparison-first explanation, reachable native Apple button and existing gate/retry. Share My Kitchen keeps canonical links/native sheet. Frozen individual/Top 3 renderers, exported red score and private-rank exclusion are untouched. |

### Motion, accessibility and performance

Short press/selection/photo availability transitions and stable-ID ranking movement communicate actual state. Reduce Motion suppresses spatial effects/custom animation; text/checkmarks, unread dots and action results remain sufficient. Comparison choice, successful Hands, participant selection and completed ranking are the deliberate haptic events. No celebratory delay, score interpolation, global animation or new engagement behavior.

Dynamic Type uses semantic system styles. Accessibility layouts stack comparison choices, identity and actions; scrolling exposes long fields/consent copy. Hands retains an explanatory action label; button geometry and score privacy remain tested. Both appearances use warm neutrals and existing semantic score colors. Native tab/navigation/sheet/text entry controls retain platform behavior. Existing optimized private photo loaders/caches and lazy food/history lists remain; no blur-heavy content layers, new image pipeline or network/font dependency. Simulator review is qualitative, not a frame-rate or physical haptic measurement.

### Vocabulary

Rankings → Grub Rank; #1 → Signature Dish; Top 3 → Signature Dishes; Feed → Grub List; Profile → My Kitchen; cooked history → Food Bible; Friends → Sous Chefs; Cooked With selector → Tag a Sous Chef; Like → Hands/Give Hands; Notifications → Order Up!; social recreation → Run It Back. Recipe Make This remains Make This. Backend enum/action values and stable automation identifiers intentionally retain their original names. New Dish, New Version, Edit Cook, Re-rank, Search, Comments, Requests, Settings, Delete, Block and Report retain clear utility/safety wording. No Stars/86’d gimmicks, new achievements, AI or Stats system.

### Preservation evidence

The read-only complete demo manifest remains `bedd790ea8487f3b1baad442acd9092a6890b0a38cede4951aef0018469b9a51`: one ranking, 12 Dishes, 15 attempts/items, 356 comparisons, 10 Sources, 21 tags, 48 memberships and 190 existing media files. Identity/evidence/score/media bytes are unchanged. Ranking/domain/private sync/official assets/client configuration remain unchanged against the protected baseline.

Hosted pre/post fingerprints match for all 12 private-data/storage groups, 11 social/profile groups and four Recipe/Ticket/profile-route groups. Storage stays at 45 objects. No backend/schema/migration/function deployment, production fixture creation, real authorization, reset or deletion occurred. All visual interactions use isolated UUID stores, media roots and local social mocks. The pre-existing project build-number edit (1 → 2) remains excluded from these commits.

### Verification evidence and limits

Focused visual bundle `/private/tmp/staygrubby-design-second-visual.xcresult`: nine UI tests passed, zero failures/skips. It covers cooking/Detail/forms/history/Kitchen/Settings, dark social/Hands/Order Up/Recipe/Ticket, large text/Reduce Motion, comparison controls/completion, empty states and onboarding through maximum accessibility text. An earlier first capture found an exact-label selector mismatch in the richer Ticket row; explicit useful accessibility labeling corrected it and the affected flow passed. No Ticket lifecycle change was needed.

The integrated run exposed two test adaptations and one real presentation integration issue. Profile counts now follow food and need scrolling before lazy-grid assertions. The Debug account review must retain its mock coordinator while Settings is pushed, instead of treating that navigation as the end of the fixture. Account privacy/deletion presentation moved from the hidden Kitchen root to the visible account controls, so the same confirmation and native authorization remain reachable after the IA change. Tests retain sync Retry, scratch restore, sign-out, explicit destructive confirmation and authorization cancellation checks; no real deletion is performed.

The combined bundle captures the major cooking/social/Recipe surfaces in both appearances and exercises the integrated affected flows once. Local result bundles and exported screenshots are review artifacts, not committed build products. Existing synthetic fixture images prove crop/geometry; real food photographs and haptic feel still need owner review on iPhone.

One existing AppConfiguration assertion hard-codes the initial uploaded build number 1. The owner’s deliberately preserved build 2 causes that assertion to fail; it is not a design regression. The test and owner edit remain unchanged rather than silently discarding either or weakening an unrelated check.

Website/AASA publication and physical Universal Link association remain outstanding from the previous cycle. The External TestFlight destination remains unset. No URL was invented, no Cloudflare workaround was attempted and no upload/tester/App Store Connect action occurred. These do not block native design review.

Next step: OWNER PHYSICAL IPHONE + MULTI-ACCOUNT PRODUCT REVIEW. Review real food imagery, all five destinations, large text, Hands/notification/read and Shared Cooking/Recipe loops with independent accounts. Fix findings if any, resolve release build-number verification as part of release preparation, publish/verify the prepared site/AASA and real tester destination, then prepare a separately approved External TestFlight build. Do not begin another product phase.


### Final test/build record

| Result bundle | Scope | Result |
| --- | --- | --- |
| `/private/tmp/staygrubby-design-second-visual.xcresult` | Focused visual/onboarding/comparison | 9 UI tests passed; 0 failures/skips. |
| `/private/tmp/staygrubby-design-integrated.xcresult` | One broader integration: 59 unit methods + 61 UI methods | 120 methods / 168 executions: 111 methods passed, 9 failed; 159 executions passed, 9 failed; 0 skips. Failures were the preserved build-number assertion, profile presentation/harness/scrolling integration, stale tab selectors, and one missed Simulator Continue tap. |
| `/private/tmp/staygrubby-design-followup.xcresult` | Only affected UI flows plus final social refinements and Cuisine selector | 12 executions: 10 passed, 2 failed; 0 skips. Remaining failures were the mock status marker's old screen location and another pre-scroll lazy-count assertion. |
| `/private/tmp/staygrubby-design-final-targets.xcresult` | Those last two corrected targets | 2 passed; 0 failures/skips. Includes both mock sync states and the large-text version/unlock lifecycle. |

Across the latest relevant results, all 62 distinct selected UI tests pass (the 61 integrated UI tests plus the focused Cuisine test). Unit results are 58/59 methods, or 106/107 executions: only the unrelated initial-build-1 assertion fails against the preserved local build 2. This is a selected risk-based regression, not a claim that the entire repository suite was run or is green. Meaningful privacy, score, lifecycle, count, sync-read and confirmation assertions remain; none was disabled to obtain a pass. The missed Continue tap left the filled enabled form in the failure hierarchy and passed unchanged on focused rerun.

Final Debug and Release Simulator configurations compile successfully; no archive, distribution or physical test is performed. The final small Recipe summary grammar correction is presentation-only. Visual attachments were inspected for all requested representative surfaces, both appearances, empty states and large Dynamic Type/Reduce Motion. The final feed uses an explicitly horizontal rule and plain Hands explanation. Git whitespace and privileged-secret/local-artifact checks pass, with the full demo manifest and hosted fingerprints unchanged after verification.
