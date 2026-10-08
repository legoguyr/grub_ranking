# StayGrubby UI architecture

Phase 2C extends the native local cooking shell with a compact StayGrubby visual language. Ranking math, evidence selection, persistence ownership, and score calculation remain unchanged. The Phase 2C section below describes the current presentation; the preceding Phase 2A/2B sections record its foundation.

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
- `CookingUITests` covers the Add, Comparison, Rankings, and Detail screens in the complete cooking workflow. The workflow also passed with an accessibility Dynamic Type size. Xcode's launch matrix exercises light and dark appearances; iPhone layout review targets upright portrait only.
- The final app build launched successfully against the saved simulator store. A pre-change SQLite checkpoint and post-launch comparison matched 1 RankingList, 14 RankedItems, 34 Comparisons, 14 Dishes, and 14 CookingAttempts exactly on semantic fields, including IDs, scores, uncertainty, diagnostic data, evidence, timestamps, and relationships. The additive migration produced zero `CookingMedia` rows, as expected, and did not reset or replace the store.
- Final visual inspection used the same saved store and confirmed the three-tab shell with Rankings selected and all 14 existing ranked items present.

The Phase 2A review pass removed the obsolete generic ranking-list UI. Focused simulator fixtures cover photo/photo, photo/placeholder, placeholder/photo, and placeholder/placeholder comparisons with portrait-shaped source media and unequal title lengths. Every fixture uses two explicitly equal square frames, aspect-fill cropping, a centered OR separator, and constrained dish/version labels; dark and light appearances were inspected.

## Phase 2C visual architecture

Phase 2C gives the local product a compact, food-first presentation. The root ranking opens directly into the existing global cooking order. Feature views own navigation and value state; the design system owns appearance. Ranking mathematics, evidence selection, score mapping, identity and persistence schema remain unchanged. The polish pass adds Contains search and changes the earlier Allergy discovery group into Avoid exclusion.

### Theme and components

`SGTheme` defines adaptive charcoal/ivory backgrounds, opaque content surfaces, secondary surfaces, primary/secondary text, accent, selection and destructive roles; spacing, radii, image dimensions, tap targets, typography, and motion. The accent still comes from the asset catalog. Typography uses Dynamic Type roles, with rounded identity/title/score roles. `SGButtonStyle` provides primary and secondary actions. Content remains opaque; the native bottom tab bar provides restrained system Liquid Glass. No decorative blur is applied to food or ranking rows.

`StayGrubbyHeader`, `SGIconButton`, `SGCreationChoices`, `SGSelectionRow`, `SGFormSection`, `DishPhoto`, `ScoreBadge`, `TagChip`, and `SourceSummary` are shared presentation building blocks. Future colors, font roles, control language, radii, spacing, press feedback and photo/score treatment can be changed centrally without changing the feature services. This is a small application design system, not a generic theme framework.

### Header, search and creation

The Rankings root hides its native navigation bar and installs a safe-area header: circular creation control on the left, centered StayGrubby/page identity, search on the right. Detail destinations restore native navigation and back behavior. Feed/Profile use the same identity component but expose no pretend search or social creation actions. The native accessible three-tab shell remains.

Search takes over the header with a native `TextField`, submit/keyboard dismissal, independent clear action and Done. Done collapses the header without clearing the query; reopening restores it. Query and filters remain Rankings-owned state and survive details and creation/edit sheets. Search presentation only forwards the existing query into `CookingDiscovery`; normalization, searchable fields, order and scores are unchanged. Custom tags remain searchable, not structured filters.

The + reveals an inline, styled pair of New Dish/New Version buttons with native interaction and accessibility. The reveal closes on route selection or search expansion; it can be collapsed by tapping + again. New Version remains disabled without eligible saved dishes. Dish selection still includes eligible dishes independently of discovery filters. No permanent large creation buttons occupy ranking content.

### Rankings and filters

Rows show exactly Dish title, Version label, Course, rank, square thumbnail/placeholder, and the shared score badge. Tags, Source and notes are absent from rows and remain available in Detail/search/filters. Rows preserve stable cook IDs and original global ranks. Normal titles/versions wrap up to two lines rather than competing with multiple pills. At accessibility sizes the photo/rank/score line sits above unrestricted identity text. A centered maximum content width and wrapping identity text support the upright portrait layout.

Course, Dietary and Avoid controls sit in a compact horizontal strip below the header. Selected Course shows its label; multi-select groups show counts and an accessible selection count. Each opens just its own scrolling selection sheet. Native buttons expose checkmarks and selected values; selections update immediately and can be unchecked. Course remains single-select, Dietary matches any selected value, Avoid excludes cooks containing any selected allergen, and groups/search combine with AND. The independent reset button is outside the scrolling strip and appears only with structured selections. It never clears search. No-result actions retain separate search/filter recovery paths.

### Comparison

A receding focus background, centered preference prompt, two square choices and nearby Undo/Too Tough/Skip form one compact interaction. Choices show Dish and Version only, never numerical scores. Both photo and placeholder use the same explicit square dimensions and aspect-fill clipping; OR is centered between the photo areas. Upright portrait uses centrally limited image sizes; content scrolls when height is limited. Accessibility sizes stack the choices with OR between them so full labels can grow. Answer selection has brief press feedback and a single haptic, with duplicate taps blocked during the short presentation transition; Reduce Motion answers immediately. Existing callbacks alone change the ranking session.

### Detail and forms

Detail starts with a hero photo, or a compact placeholder when absent, then Dish/Version, score/global rank, Edit/Re-rank, Course/date/tags, Source, Notes and Versions. Tags wrap into an adaptive grid when they do not fit on one line, instead of truncating. Version rows show identity/date/rank/score, an optional thumbnail, current indication or a chevron, and remain navigable. New Version stays in the Versions section.

Delete is in the toolbar overflow menu, marked destructive. It always opens a separate native “Delete this cook?” alert with visible Cancel and destructive Delete Cook. An alert is intentional: iOS 26 can present a confirmation dialog as a popover and suppress its cancel-role button. The existing cooking service handles evidence/recomputation, final-Dish and media cleanup; the redesign introduces no new deletion path.

Add/New Version/Edit use a scrolling photo editor and reusable opaque sections. Dish name/Source are explicitly shared Dish information; Course, Version, cooked date, Dietary/Contains, custom tags and notes describe this cook. Course stays a cook snapshot initialized from the Dish default. Dietary uses a compact draft selection sheet; Contains uses its own presence selector, sharing canonical allergen choices with Avoid while keeping the opposite selection semantics separate. Custom tags use a secondary disclosure. Continue/Save are clear full-width safe-area actions and remain reachable above the keyboard. Draft cancellation still writes nothing; New Version inherits Dish name/default Course/Source and starts without a photo.

Source is a six-choice optional editor backed by `SourceChoice` and `CookingProductOptions`. Online asks only for the original URL; Cookbook/Restaurant ask only for a name; My Own needs no fields, Friend/Family an optional name, Other short attribution. No lookup, metadata scraping, canonical catalog or Recipe is implemented. Legacy metadata stays in the existing draft/model and remains readable in Detail. See `COOKING_MODEL.md` for compatibility.

### iPhone orientation policy

StayGrubby on iPhone supports **upright portrait only**. Landscape left, landscape right and upside-down portrait are intentionally unsupported. Screens and reusable components must be designed and reviewed in normal upright portrait, including scrolling content, keyboard/safe-area behavior, accessibility and Dynamic Type. Large text and both appearances remain required within portrait. No iPad layout work is part of this decision.

The app target's generated Info.plist uses Xcode's `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait` in both Debug and Release, producing `UISupportedInterfaceOrientations~iphone` with exactly one value. iOS enforces the supported orientation through application configuration; there are no per-screen rotation overrides or custom orientation locks. Existing iPad settings remain outside this pass.

### Accessibility and responsive behavior

Native navigation, tabs, sheets, text input, date/course pickers, menus and photo selection preserve platform behavior. Custom actions use minimum 44-point targets, selected text/checkmarks and complete VoiceOver labels. Search/filter clearing stays independent. Semantic adaptive colors support both appearances. Large text stacks ranking identities, comparison choices, actions when required and version identity. Long Detail labels have unrestricted wrapping. Scroll views and safe-area actions prevent bottom-tab/keyboard overlap. Reduce Motion removes reveal/search/answer animation and press scaling; a DEBUG-only test hook exercises this path without overriding production accessibility settings.

### Phase 2C verification

Validated on **October 5, 2026**, using iPhone 17 / iOS 26.5 Simulator. The complete scheme passed **70 tests / 93 parameterized and configuration executions**, with zero failures, expected failures or skips. This includes 59 Swift Testing functions and 14 UI/configuration executions. Serial execution avoids simulator-clone instability. No ranking/domain or persistence implementation changed.

- Existing discovery, cooking creation/version/edit/re-rank/relaunch/deletion, Source, photo geometry and launch tests were adapted to the new controls while retaining product assertions. Added Source compatibility coverage for all seven stored types and original URLs, plus detail/version/long-name/accessibility forms and Skip/Too Tough/Undo review tests. Deletion cancellation and confirmed cleanup both pass. Large-text launch arguments apply UIKit's content-size category to sheets as well as the root; the DEBUG motion hook combines with, rather than suppressing, the device preference.
- Captures from the successful full suite were reviewed for normal Rankings, active search, combined filters, creation reveal, every photo/placeholder comparison, detail with/without media, Add/New Version/Edit, simplified Source, light/dark and accessibility sizes. Photos remain clipped inside their intended frames. Large identities wrap; forms, comparisons and actions scroll or stack as required. VoiceOver labels/selection values were inspected through XCTest; a physical-device VoiceOver walkthrough remains part of human review.
- The earlier landscape requirement was superseded on October 7, 2026 by the explicit iPhone upright-portrait-only product decision. Landscape and upside-down portrait are intentionally unsupported.
- The saved development store exactly matches the pre-change semantic checkpoint: **1 RankingList, 14 RankedItems, 34 Comparisons, 14 Dishes, 14 CookingAttempts, 1 CookingLibrary, 5 CookingTags and 5 tag relationships, 0 DishSources, 0 CookingMedia**. IDs, names, dates, scores/strengths/uncertainty, diagnostics, evidence and relationships match. No duplicate global ranking, store reset or fixture leakage occurred. Legacy Source safety is independently covered with populated isolated stores.
- Build output contains only the toolchain's unused App Intents metadata notices. Existing disk-test cleanup emits SQLite unlinked-temporary-file diagnostics; those paths are isolated test stores and do not include the saved default store. All corresponding persistence assertions pass.

Review captures and the exact changed-file inventory are retained under the ignored `.local-backups/phase2c-20261005/review/` directory; the semantic checkpoint and verification hashes are alongside it. Phase 2C remains uncommitted pending manual product approval. The polish verification below supersedes this historical verification report. No Phase 2D or remote/social work is included.

## Phase 2C product polish

- Creation now automatically finalizes a complete ranking session through the existing transaction. CookingRankingResultView receives an already persisted CookingAttempt, shows its Dish/Version, optional local hero, shared ScoreBadge, and authoritative global rank. Its accessible X closes the sheet; Rankings observes the saved models immediately. The presentation has no second save decision and uses an opacity transition only when Reduce Motion permits it. Failed persistence offers retry/cancel without losing the draft.
- DishSelectionView presents an always-visible SGSearchField for New Version, using normalized DishSelectionSearch filtering independent of discovery filters. Compact rows show the parent Dish name, version count and available local thumbnail. Empty results and an accessible clear action support longer libraries. Selection routes into the existing version transaction with the selected Dish.
- SGHeroMedia is reusable by Detail and results. A lightweight LinearGradient leaves the upper 55% of a photo unobscured, then blends its bottom into the semantic page background in either appearance. No blur, extra compositing group, hard-coded black or storage changes. Missing photos retain the compact placeholder. Scroll/safe-area behavior and wrapping content support large text.
- ContainsSelector and SGAllergenChoices share centralized canonical presence options with the Avoid discovery sheet. Form Contains selection is deliberately separate from discovery exclusion. Legacy Free claims appear separately in Edit/Detail and require explicit removal. Avoid supports independent clearing and explanatory safety copy; root rank order and numbers remain unchanged.

### Product polish verification — October 6, 2026

The complete scheme ran serially on iPhone 17 / iOS 26.5 Simulator: **76 tests / 99 configured executions; 75 tests / 98 executions passed, one failed, zero skipped or expected failures** (`/private/tmp/grub-polish-full.xcresult`). All 62 unit-test functions / 82 parameterized executions passed. UI results were 13 of 14 functions / 16 of 17 configuration executions passing. Build and normal saved-store launch succeeded.

All three new PolishUITests passed in the complete run, including automatic persistence before result close/relaunch, abandonment, Contains edit/reload, Avoid ANY exclusion and independent clearing, normalized parent search, correct version ownership, nested-version result return to root Rankings, and photo/no-photo detail in light/dark at normal/accessibility sizes with Reduce Motion. All nine presence options pass disk persistence tests alongside unchanged legacy Free semantics. Existing cooking lifecycle, Source, discovery, comparison-square and ranking simulation assertions pass. Test helpers scroll a metadata selector clear of the pinned footer before tapping; they do not remove product assertions.

**Historical orientation result, superseded October 7, 2026:** The sole failed check in this earlier run expected a landscape window. That product requirement is obsolete. The review test now asserts upright portrait geometry while retaining Skip/Undo/Too Tough, comparison-square and accessibility checks. AppConfigurationTests verifies the generated iPhone orientation array from the built application bundle.

Thirteen polish captures were inspected for parent search, hero media and saved result across appearances/text sizes. Captures and the full 45-file working-tree inventory are in ignored `.local-backups/polish-20261005/review/`. The final saved-store comparison after tests and normal launch confirms **one global RankingList, 12 Dishes, 15 CookingAttempts/RankedItems, 356 Comparisons, 10 Sources, zero media**. All non-allergen fields/relations, ranking metrics, evidence and schema exactly match the pre-polish backup. Only the explicitly authorized disposable fixture allergen metadata changed; details are in COOKING_MODEL.md. No test fixture leaked into the saved library. No commit or push was performed.

### Final upright-portrait verification — October 7, 2026

The complete existing scheme passed on iPhone 17 / iOS 26.5 Simulator: **77 tests / 98 configured executions, zero failures, unexpected failures, expected failures or skips** (`/private/tmp/grub-portrait-final-20261007.xcresult`). This includes 63 unit functions / 83 parameterized executions and 14 UI functions / 15 appearance/configuration executions. Xcode's launch matrix now runs the two supported upright-portrait appearance configurations instead of the earlier four portrait/landscape configurations. No test function was removed or skipped.

The obsolete landscape-window assertion was replaced by upright portrait device/window assertions in the existing comparison review. Skip/Undo/Too Tough, equal-square geometry, scrolling action reachability, large-text and appearance checks remain. AppConfigurationTests additionally passes against the generated app bundle's one-value iPhone orientation array. Effective Release settings independently confirm the same sole upright portrait value. Build and normal saved-store launch both succeeded; the app was left on Rankings for manual UI approval.

After tests and normal launch, a consistent pre-pass SQLite checkpoint matches every saved entity's semantic fields and relationships, including all Contains/Dietary/custom tag rows and memberships, Dish/Source/cook/item identities, scores/strengths/uncertainty, diagnostics, dates and comparison evidence. Counts remain **1 RankingList, 1 CookingLibrary, 12 Dishes, 15 CookingAttempts, 15 RankedItems, 356 Comparisons, 10 Sources, 21 tags / 48 memberships (16 Contains memberships), zero media**. Schema and SQLite integrity checks pass. No fixture data entered the saved development store.

This final pass changed only the app-target iPhone orientation setting in Debug/Release, AppConfigurationTests.swift, the obsolete assertion/capture label in Phase2CReviewUITests.swift, and orientation/verification documentation in this file and COOKING_MODEL.md. All preceding Phase 2C implementation files were preserved byte-for-byte. `git diff --check` passed. Verification summaries, exact file inventory and the checkpoint are retained under ignored `.local-backups/portrait-20261007/`. There are no remaining automated-verification blockers; Phase 2C remains uncommitted and unpushed pending final manual UI approval.
