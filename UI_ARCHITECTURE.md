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

- Rankings opens directly from its tab and uses the existing single global order and score cache. Rows are photo-forward and searchable by dish/version/category. Search is intentionally simple in 2A.
- Add Dish and New Version retain the existing ranking session and metadata form. Photo is optional. New Version inherits Dish metadata and Source but begins without an attempt photo.
- Comparison shows large photos or accessible placeholders and never shows either item's numerical score. Undo, Too Tough, and Skip sit on a restrained glass action bar.
- Dish Detail shows the selected version's photo, score, global rank, tags, Source, notes, date, and all versions derived from the existing global ranking. It does not create a second version-ranking model.
- Edit supports add, replace, and remove photo alongside existing metadata, Source, tag, re-rank, and deletion behavior.

## Accessibility and adaptation

Controls use native buttons, pickers, forms, tabs, navigation, and photo picker behavior. Tap targets are at least 44 points where custom sizing is used. Photos announce either their dish context or a no-photo state. Ranking rows and comparison choices have complete labels. Scores, selection, and current-version state use text or symbols in addition to color. Layouts use Dynamic Type fonts and scrolling; Reduce Motion bypasses comparison selection animation.

## Deliberately deferred to Phase 2B

- Search filters and sorting beyond the basic local text search.
- Semantics for an All / Dishes / Versions segmented control.
- User-selectable theme palettes.
- Camera capture and multiple-media editing.
- Feed, profile, accounts, public content, and every cloud/social feature.
- Recipe UI and cookbook-provider integration.

## Phase 2A validation

Validated on **October 5, 2026**, using an iPhone 17 / iOS 26.5 Simulator:

- The complete test suite passed: 49 tests, 62 parameterized/configuration executions, zero failures, and zero skips.
- `CookingMediaTests` verifies display/thumbnail dimensions, disk-backed persistence, replacement and removal without ranking-identity or evidence changes, deletion cleanup, the no-photo path, and New Version media ownership.
- `CookingUITests` covers the Add, Comparison, Rankings, and Detail screens in the complete cooking workflow. The workflow also passed with an accessibility Dynamic Type size. Xcode's launch matrix exercises light and dark appearances and portrait and landscape orientations.
- The final app build launched successfully against the saved simulator store. A pre-change SQLite checkpoint and post-launch comparison matched 1 RankingList, 14 RankedItems, 34 Comparisons, 14 Dishes, and 14 CookingAttempts exactly on semantic fields, including IDs, scores, uncertainty, diagnostic data, evidence, timestamps, and relationships. The additive migration produced zero `CookingMedia` rows, as expected, and did not reset or replace the store.
- Final visual inspection used the same saved store and confirmed the three-tab shell with Rankings selected and all 14 existing ranked items present.

The Phase 2A review pass removed the obsolete generic ranking-list UI. Focused simulator fixtures cover photo/photo, photo/placeholder, placeholder/photo, and placeholder/placeholder comparisons with portrait-shaped source media and unequal title lengths. Every fixture uses two explicitly equal square frames, aspect-fill cropping, a centered OR separator, and constrained dish/version labels; dark and light appearances were inspected.
