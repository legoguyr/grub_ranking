# StayGrubby Master Roadmap

This versioned roadmap records the current launch scope. No existing Master Roadmap was found in this repository or its project directory when this document was introduced on October 13, 2026. It does not replace the detailed phase review documents or turn pending manual approval into completed work.

## Current checkpoints and approval gates

- Phase 3D Part 1: structured private cooking-data sync is checkpointed at `a4b61eb177db055723ed07319e1c0655afbb8bca` following automated and physical-iPhone verification.
- Phase 3D Part 2: private cooking-photo backup and restore is implemented in the working tree and automatically verified. Authenticated physical-iPhone upload, fresh restore, replacement, deletion and no-resurrection verification PASSED on October 13, 2026. See [PHASE_3D_PHOTO_SYNC_REVIEW.md](PHASE_3D_PHOTO_SYNC_REVIEW.md).
- V1 branding and local sharing: implemented on top of the uncommitted photo-sync work. Individual and Top 3 exports, score unlock/locks and general usage passed physical review. On October 14, 2026 the user confirmed the final V1 revisions passed all six physical-iPhone checklist sections using existing data without a reset: Re-rank, unlocking, version display, sharing, achievements, persistence and locked-score protection.
- The combined work remains uncommitted/unpushed. The bounded pre-alpha UI pass centers the Edit Cook pencil and New Version plus and uses the confirmed semantic in-app palette (1.0–4.9 muted coral, 5.0–7.5 orange, 7.6–10.0 gold). Exported scores remain uniform official red. Final verification is recorded in V1_FINAL_REVISIONS_REVIEW.md; no features or domain/backend changes are introduced.

## Core App V1 — required before initial public launch

The following belong to the required first release, rather than a later social phase:

- Official StayGrubby app icon with native light/default and dark appearances, plus the supported tinted appearance treatment.
- A ranking-completion experience after a saved session, with exact relative rank and calculated score when unlocked, or the intentional lock/building-rankings state before unlock.
- One reusable branded share card using the supplied official PNG wordmark: 1080 × 1350 with a usable local photo and 1080 × 1080 without one.
- Native iOS sharing of the rendered card image, entirely locally.
- Optional, deterministic ranking achievements supported by saved ranking evidence/history; no generic completion badge or effect on ranking behavior.
- One universal plate-and-fork no-photo fallback for every dish category.
- Re-sharing the current cook from Dish Detail through the same card model, renderer and native share flow.

The existing Apple-only account boundary, private account ownership, local-first cooking library, accurate sync status, upright-portrait iPhone layout, accessibility and Dynamic Type support remain part of the launch foundation. Private photo backup passed its physical data-path approval gate; sharing itself uses local bytes and does not depend on a cloud transfer.

- Numerical scores remain hidden until **10 eligible ranked entries (dishes and independently ranked versions)**, while ranking and evidence calculation continue from the first cook.
- Locked score indicators and a naturally scrolling Rankings progress banner.
- Automatic score reveal/relock from the current eligible ranked-entry count, including deletion and accepted restore/hydration.
- One locally persisted first-unlock celebration per account on this installation; passive hydration does not replay it.
- A fixed **My Top 3 Dishes So Far** milestone composition, using actual ranked entries (including independent versions), local photos/universal fallbacks and native image sharing.

- Fresh-session Re-rank: normal reaction → adaptive comparisons → automatic result, targeting the same entry, preserving history and adding evidence without incrementing the unlock count.
- Red semantic product accents with explicit red progress fill in both appearances.
- Top Version (default) / All Versions Rankings display, preserving true global rank numbers without aggregation or changes to the underlying ranking.
- Profile access to a normal current Top 3 card; only the actual first-unlock card includes SCORES UNLOCKED.
- Optional Share Updated Top 3 after a new or re-ranked entry genuinely becomes #1; individual sharing remains primary.

See V1_FINAL_REVISIONS_REVIEW.md for the current policy, verification and physical checklist. SCORE_UNLOCK_REVIEW.md records the superseded unique-Dish iteration and its verification history.

## Outside Core App V1

- Historical milestone-card galleries.
- Monthly or yearly recap cards.
- Additional card themes, template selectors or customization controls beyond the two fixed V1 compositions.
- Advanced statistics cards or a sophisticated achievement system.
- Sharing or social posting directly between StayGrubby accounts.
- Dish deep links, App Store marketing links and community/social ranking cards.
- Feed, friends, following, likes, comments, public profiles and public photo Storage.
- Recipe, cookbook or restaurant APIs, video and moderation infrastructure.

These features require their own product and architecture work. The local card export does not introduce a public endpoint, social identity, backend sharing service or second media transport.

## Review references

- [V1_SHARING_ARCHITECTURE.md](V1_SHARING_ARCHITECTURE.md): presentation data, achievement semantics, local rendering and native sharing.
- [V1_BRANDING_SHARING_REVIEW.md](V1_BRANDING_SHARING_REVIEW.md): combined verification evidence, exact file inventory and the single physical/manual approval checklist.
- [MEDIA_SYNC_ARCHITECTURE.md](MEDIA_SYNC_ARCHITECTURE.md): private photo ownership, transfer integrity and lifecycle.
- [UI_ARCHITECTURE.md](UI_ARCHITECTURE.md): current navigation, iPhone orientation and accessibility requirements.
