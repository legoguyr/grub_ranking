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

In progress. Checkpoint details, focused tests, representative visual evidence, preservation audit, honest limitations and owner review handoff will be completed as work proceeds. No physical testing, real account deletion, upload or unrelated product phase is authorized here. Website/AASA publication/device association remain the previous phase's outstanding gates and do not block native design work.
