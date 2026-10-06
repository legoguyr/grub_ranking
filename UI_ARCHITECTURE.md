# StayGrubby UI architecture

Phase 2A establishes a native, photo-forward shell around the existing local ranking and cooking systems. Ranking math, evidence selection, persistence ownership, and score calculation remain unchanged.

## App shell and navigation

`ContentView` owns a three-tab shell: Feed, Rankings, and Profile. Rankings is the selected local V1 destination. Selecting it opens the one personal global cooking ranking directly; StayGrubby has no user-facing ranking-list picker, list creation control, category ranking, or separate version ranking. The ranking engine may continue using its saved `RankingList` as the internal container. Feed and Profile are honest empty states; they contain no fake users, posts, accounts, or social data. Each tab owns a `NavigationStack`, so future Feed and Profile navigation can grow independently. Add/Edit/New Version remain modal workflows launched from the ranking or detail screen.

## Design tokens

`DesignSystem/StayGrubbyTheme.swift` is the small source of truth for semantic colors, spacing, corner radii, common image/tap sizes, and animation timing. Colors use iOS semantic backgrounds and labels, so the same views adapt to light and dark appearance. Change the app accent through the asset catalog; change layout rhythm or radii through `SGTheme` rather than editing every screen.

Liquid Glass is reserved for interactive surfaces. The system tab bar provides the primary native glass navigation treatment on iOS 26, and the comparison action bar uses native interactive glass. Food photos and content rows use opaque semantic surfaces rather than turning every card into glass.

## Reusable components

`DesignSystem/StayGrubbyComponents.swift` contains:

- `DishPhoto`, which loads an optimized display image or thumbnail and supplies a consistent accessible placeholder.
- `RankedDishRow`, which presents rank, thumbnail, identity, lightweight metadata, and score.
- `ScoreBadge`, `TagChip`, `SourceSummary`, and `SGSectionHeader` for shared hierarchy and styling.

`CookingPhotoEditor` owns photo-library selection, preview, replacement, removal, progress, and import errors. Domain writes still occur only when the enclosing cook form saves.

## Local photo storage

Each `CookingAttempt` owns an ordered `[CookingMedia]` relationship with cascade deletion. V1 creates at most one `CookingMedia` of type image, but the relationship, type code, and sort order provide a direct migration path to multiple images and video metadata.

`LocalPhotoStore` keeps bytes outside SwiftData under Application Support/StayGrubbyMedia. SwiftData stores UUID-based relative filenames, dimensions, kind, order, and timestamps. Container paths are never persisted.

On import, ImageIO reads the selected asset and applies its orientation while downsampling. It writes:

- a display JPEG with a maximum long edge of 1,200 pixels, starting at quality 0.84 and reducing quality only when needed toward a soft 300 KB target;
- a thumbnail JPEG with a maximum long edge of 360 pixels, starting at quality 0.76 and reducing quality only when needed toward a soft 60 KB target.

The original library asset is not copied into StayGrubby. Already optimized files are used directly by lists, detail, and comparisons. A new file pair is written before a database replacement; the old pair is removed only after SwiftData saves. Failed saves remove the new pair and roll back the model context. Removing a photo or deleting its cook removes both files after the database transaction succeeds.

These optimized files can later become upload inputs. A future multi-media migration can remove V1's one-image UI constraint while retaining current `CookingMedia` records and adding video-specific metadata or remote asset state.

## Core screens

- Rankings opens directly from its tab and uses the existing single global order and score cache. Phase 2B adds local discovery as described below.
- Add Dish and New Version retain the existing ranking session and metadata form. Photo is optional. New Version inherits Dish metadata and Source but begins without an attempt photo.
- Comparison shows large photos or accessible placeholders and never shows either item's numerical score. Undo, Too Tough, and Skip sit on a restrained glass action bar.
- Dish Detail shows the selected version's photo, score, global rank, tags, Source, notes, date, and all versions derived from the existing global ranking. It does not create a second version-ranking model.
- Edit supports add, replace, and remove photo alongside existing metadata, Source, tag, re-rank, and deletion behavior.

## Accessibility and adaptation

Controls use native buttons, pickers, forms, tabs, navigation, and photo picker behavior. Tap targets are at least 44 points where custom sizing is used. Photos announce either their dish context or a no-photo state. Ranking rows and comparison choices have complete labels. Scores, selection, and current-version state use text or symbols in addition to color. Layouts use Dynamic Type fonts and scrolling; Reduce Motion bypasses comparison selection animation.

## Rankings discovery — Phase 2B

`CookingDiscovery.entries` is a read-only projection over the existing global `RankingList.orderedItems`. A dictionary bridges ranked-item IDs to queried CookingAttempts, replacing the previous per-item linear lookup. It evaluates structured selections and text against each attempt and retains the original one-based global rank. Rows keep the same score cache, thumbnail component, identity, and detail destination. A filtered result at global rank 7 still shows **7**, and the result count says “Global ranks”; no local renumbering or alternate sorting is introduced.

Search uses `TagNormalization.key` for both query and field values: trim/collapse whitespace, fold case and character width, then match a contiguous substring in any one field. Searchable fields are Dish name, version title (or default “Version N”), category label, custom-tag labels, Dietary labels, and Allergy labels. Notes, Source, dates, IDs, and scores are not indexed. Multiple versions of a Dish can match independently. Custom tags remain searchable text and do not become filter options.

`CookingFilters` holds one optional canonical Category, a set of canonical Dietary values, and a separate set of canonical Allergy values. All selected groups AND together with search; values within Dietary or Allergy OR together. An empty group imposes no restriction. `CookingFilterView` uses native Picker/Toggle controls and edits the Rankings-owned binding immediately; Done closes the sheet. Clear Filters resets every structured selection, retaining the query. Active chips remove just one selection; the button announces its active selection count. The controls remain in the list while native search is active because iOS can hide navigation toolbars during search.

Query and filter selections are `@State` in `CookingRankingView`, survive detail navigation and Add/New Version/Edit/Re-rank sheets, and reset on app relaunch. Adding a cook preserves discovery state: a new item can remain hidden if it does not match. Editing metadata updates the projection through SwiftData observation; no persisted filter models, schema changes, ranking writes, or calls to recompute are involved. Delete and Re-rank continue using their existing global-domain services, after which discovery reads the new global order.

Empty states distinguish an empty library (“Your cooking, ranked” with Add Your First Dish), search with no matches (the normalized query and Clear Search), and filter/search combinations with no matches (Clear Filters and Clear Search where applicable). No fixture data is added to production empty states.

The native search field has a descriptive prompt, native clearing and submit behavior, and interactive keyboard dismissal while scrolling. Filters use native accessible selected/on-off states, labeled removal buttons, 44-point custom tap targets, semantic colors, Dynamic Type, and scrolling. Creation and filter/reset controls stack vertically at accessibility text sizes so their labels remain readable. Empty-state action identifiers are attached to individual buttons rather than their container, since SwiftUI can propagate a container identifier to its children. No new animation is required, so Reduce Motion has no extra transition to suppress.

Discovery does one dictionary build and one pass over globally ordered items (plus the existing O(n log n) ordering). It reads text/tag metadata only; it never loads photos or runs inference. List rows retain attempt UUIDs and request thumbnails. `DishPhoto` retains its decoded image in local state and reloads only when its media ID/filename, size choice, or prepared data changes, so an unchanged row does not reread/decode its photo on every keystroke. Review fixtures are DEBUG-only, seeded only when both a valid isolated-store token and `--discovery-fixture` are present; they never seed the real default store.

## Deliberately deferred

- Alternate sorting and an All / Dishes / Versions control (neither is part of local V1).
- User-selectable theme palettes.
- Camera capture and multiple-media editing.
- Feed, profile, accounts, public content, and every cloud/social feature.
- Recipe UI and cookbook-provider integration.

## Phase 2B validation

Validated on **October 5, 2026**, iPhone 17 / iOS 26.5 Simulator. The final complete scheme passed **66 tests / 83 parameterized and configuration executions**, with zero failures, expected failures, or skips. Serial execution (`-parallel-testing-enabled NO`) avoids the previously observed simulator-clone failures. The final build reported no warnings or errors and launched directly into Rankings against the real saved store.

- `CookingDiscoveryTests` adds 12 test functions covering normalized dish/version/tag search, each structured filter, AND/OR semantics, clearing, empty results, original global order/ranks/scores, unchanged IDs/uncertainty/diagnostics/evidence, creation and separate versions, metadata edits, re-ranking/deletion, Source retention, and photo/no-photo references. The 500-attempt workload completed 20 discovery evaluations in approximately 0.34 seconds on this simulator; this is a local measurement, not a universal performance guarantee.
- Four `CookingDiscoveryUITests` cover query entry/clearing, each filter group, combined selections, active feedback, individual removal, separate clear actions, empty-state recovery, detail/back state retention, live edit updates with unchanged item ID/score, creation-form navigation from filtered results, and light appearance at accessibility Dynamic Type size. Existing cooking, Source, comparison-photo, and launch tests also remain green. Known simulator event delivery is handled with state predicates and taps targeted at the actual switch control.
- Captured simulator screens were visually reviewed for full ranking, matches/no matches, each filter group, combined search/filters, clearing, detail navigation, New Dish/New Version with an existing ranking, light/dark appearance, and larger text. Creation and filter/reset labels remain readable at accessibility sizes. Dense row labels/tags at those sizes are retained in the Phase 2C handoff.
- A consistent SQLite checkpoint was created before changes under the ignored `.local-backups/phase2b-20261005/` directory. Post-suite and post-launch semantic hashes exactly match it: **1 RankingList, 14 RankedItems, 34 Comparisons, 14 Dishes, 14 CookingAttempts, 1 CookingLibrary, 0 CookingMedia**, plus unchanged Source/tag records. IDs, scores, strengths, uncertainties, diagnostic bytes, evidence, timestamps, and relationships are preserved. No schema migration, reset, restore, or new global ranking was required.

## Phase 2A validation

Validated on **October 5, 2026**, using an iPhone 17 / iOS 26.5 Simulator:

- The final approved complete test suite passed: 50 tests, 63 parameterized/configuration executions, zero failures, and zero skips.
- `CookingMediaTests` verifies display/thumbnail dimensions, disk-backed persistence, replacement and removal without ranking-identity or evidence changes, deletion cleanup, the no-photo path, and New Version media ownership.
- `CookingUITests` covers the Add, Comparison, Rankings, and Detail screens in the complete cooking workflow. The workflow also passed with an accessibility Dynamic Type size. Xcode's launch matrix exercises light and dark appearances and portrait and landscape orientations.
- The final app build launched successfully against the saved simulator store. A pre-change SQLite checkpoint and post-launch comparison matched 1 RankingList, 14 RankedItems, 34 Comparisons, 14 Dishes, and 14 CookingAttempts exactly on semantic fields, including IDs, scores, uncertainty, diagnostic data, evidence, timestamps, and relationships. The additive migration produced zero `CookingMedia` rows, as expected, and did not reset or replace the store.
- Final visual inspection used the same saved store and confirmed the three-tab shell with Rankings selected and all 14 existing ranked items present.

The Phase 2A review pass removed the obsolete generic ranking-list UI. Focused simulator fixtures cover photo/photo, photo/placeholder, placeholder/photo, and placeholder/placeholder comparisons with portrait-shaped source media and unequal title lengths. Every fixture uses two explicitly equal square frames, aspect-fill cropping, a centered OR separator, and constrained dish/version labels; dark and light appearances were inspected.

## Phase 2C UI/UX handoff (not implemented in 2B)

- Make Comparison more compact and improve its density.
- Reduce Dish Detail whitespace and action-button prominence.
- Refine Rankings and Add Dish/New Version hierarchy, spacing, navigation, score treatment, and buttons.
- Develop StayGrubby's visual identity, typography, chips, and controls.
- Revisit row metadata truncation and density at large accessibility sizes.
- Refine the spacing between native search, creation controls, Filters, and result feedback.
- Improve filter-chip presentation when many selections are active; retain practical individual removal.
- Consider haptics, micro-animations, and polished empty states while respecting Reduce Motion.
