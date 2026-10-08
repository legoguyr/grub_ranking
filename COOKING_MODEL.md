# StayGrubby cooking data foundation

Phase 1 adds local cooking metadata around the existing generic ranking system. The Bradley–Terry fit, score mapping, insertion policy, confidence calculation, and original ranking tests are unchanged. See `RANKING_MODEL.md` for inference details.

## Ownership and relationships

- **Dish**: unique UUID, shared base name, default controlled category, creation timestamp, and versions. It contains no score or inference logic.
- **CookingAttempt**: unique UUID, parent Dish, unique `rankedItemID` plus a SwiftData reference to that RankedItem, cooked date, optional version title and notes, category snapshot, tags, sequence number, created/updated timestamps, and legacy-import provenance. The interface calls it a *cook* or *version*.
- **RankedItem**: owns ranking identity, cached display name, creation date, estimated strength/uncertainty and insertion diagnostics. Every cook has its own item. All new cooks, including versions of one dish, enter the same global RankingList.
- **CookingLibrary**: persists the UUID of the chosen global list. This application adapter keeps cooking ownership out of RankingList and the inference engine.
- **CookingTag**: shared structured rows identified by `kind:value`, with separate dietary, legacy allergy, Contains, and custom kinds. Relationships support filtering by a tag; scalar raw codes support SwiftData predicates. Unused tag rows are retained for reuse.
- **DishSource**: optional, single Dish-owned attribution record with its own UUID, controlled type code, type-specific manual metadata and timestamps. The dish cascades deletion to its Source. Source does not carry a score or recipe instructions.
- **CookingMedia**: file-backed, ordered media metadata owned by one CookingAttempt. V1 writes at most one image with display and thumbnail filenames; bytes live under Application Support rather than in SwiftData. Media has no ranking identity or score.

SwiftData references are optional to support nullification and additive migration; `CookingStore` is the application write boundary and creates complete Dish → cook → RankedItem links atomically. Do not delete cooking-related RankedItems or Dishes directly through a ModelContext: use the cooking service so scalar comparison references are cleaned up too.

## Courses and tags

`DishCategory` is the controlled Course list (the persisted category property/code is retained): Main, Appetizer, Side, Soup, Salad, Pasta/Noodles, Sandwich, Breakfast/Brunch, Snack, Dessert, Baked Good, Sauce/Condiment, Drink, Other. Persisted raw codes are stable and separate from labels. The dish default initializes each new version; changing a cook's category changes only its snapshot. Phase 1 does not expose a separate default-category editor.

Dietary: Kosher, Vegetarian, Vegan, Dairy-Free, Gluten-Free, Halal.

Legacy Free labels (compatibility only): Peanut-Free, Tree-Nut-Free, Sesame-Free, Milk-Free, Egg-Free, Wheat-Free, Soy-Free, Fish-Free, Shellfish-Free. These are user-entered labels, never a safety certification.

Custom labels trim/collapse whitespace; identity also folds case and character width. The first saved display spelling is retained. Blank labels are ignored. Standard tags and identically named custom tags remain distinct kinds. Tags are separate records, not a hashtag string or comma-delimited database field.

The original Phase 2B discovery read ranked CookingAttempts without introducing persistence entities or altering ranking evidence. The Phase 2C polish replaces the earlier Allergy matching group with Avoid exclusion; see Contains and Avoid below. Course stays single-select and Dietary matches any selected dietary value. Custom tags are searchable text, not a structured filter taxonomy. Each matching version stays independently discoverable in global ranking order with its original global rank and score. Search reuses the same custom-tag normalization. See `UI_ARCHITECTURE.md` for exact searchable fields, state ownership, and empty states.

## Source attribution

Source records **where the dish idea came from**. A future Recipe would record **how the user makes it**. Neither concept enters the ranking engine. Source is optional: leaving the optional editor at No source creates no record and adds no questions to ranking.

Phase 2C uses six centralized user-facing `SourceChoice` options: **My Own, Online, Cookbook, Restaurant, Friend / Family, Other**. `CookingProductOptions` is the product selection source for Courses, Dietary, Contains/Avoid allergens and Source choices. Views consume it rather than maintaining duplicate lists. Underlying raw enum codes remain unchanged for persistence and discovery compatibility; Category is called **Course** throughout the interface.

Source asks only where the idea came from:

- My Own: type alone.
- Online: original URL, with no scraping or metadata lookup.
- Cookbook: cookbook name as a lightweight local fallback.
- Restaurant: restaurant name as a lightweight local fallback.
- Friend / Family: optional person/source name.
- Other: short free-text attribution.

The seven existing `DishSourceType` codes and all nullable metadata fields are retained. Both `onlineRecipe` and `socialMedia` display as Online. Opening/reselecting Online on an old Social Media draft preserves its stored type and edits `socialURL`; new Online records use `onlineRecipe`/`onlineURL`. Hidden legacy authors/page/recipe/location/creator/platform/details remain in `DishSourceDraft` and round-trip when saving other fields. Detail continues displaying original saved metadata. There is no bulk conversion, launch-time migration or record deletion caused by the simpler UI.

New Version inherits the parent's single Source without copying or overwriting it. Editing Source still affects every version and retains Source identity. Explicitly switching to a different Source choice or No source follows the existing deliberate replace/remove behavior; canceling the enclosing cook editor writes nothing. Source writes stay in the same cooking transaction and never refit scores or add comparison evidence. Removing one version retains the Dish's shared Source; removing its final cook cascades cleanup.

`SourceChoice` separates presentation from stable storage. Future canonical Cookbook/Restaurant selection or optional Online metadata can supply the same draft through a lookup adapter; no provider/catalog, URL service, recipe instructions or fabricated metadata is part of local V1.

## Creation, editing, deletion

**New Dish** collects metadata as a value-only draft, then uses the existing initial reaction and adaptive comparisons. **New Version** first selects a dish from the global cooking ranking, inherits its name/default category, then follows the identical global comparison flow. There is no per-dish ranking. Cooked dates default to today for new forms; legacy unknown dates remain unknown. Ranking completion automatically commits the dish (if new), cook, item, comparisons, and tags in one transaction, then shows the saved result. Canceling an incomplete flow writes nothing. Undo remains available during comparisons; after completion, feedback describes an already saved cook.

Editing metadata retains cook/item IDs, strengths, uncertainties, diagnostics, and all comparison IDs/timestamps. Renaming a dish updates every sibling's cached display name; the form explains the shared rename. Title, notes, date, category, and tags apply to the individual version. Empty optional text becomes nil.

Deletion explicitly removes every comparison incident to that item, including repeated observations, ties, and later refinement. It removes the cook and item, deletes an empty final parent Dish, and recomputes the remaining list with the existing model. Other versions and unrelated observations remain intact. Tag relationships nullify; shared tags survive. The list itself stays available when empty.

Photo edits follow the same metadata boundary: adding, replacing, or removing a photo does not replace a RankedItem or touch comparison evidence. Each saved cook owns its photo; New Version does not inherit another attempt's image. Deleting a cook removes its app-owned display and thumbnail files after the SwiftData transaction succeeds. See `UI_ARCHITECTURE.md` for the optimization and file-storage strategy and the future Media[] path.

## Re-ranking

`ReRankingSession` is a value-only application session over generic IDs and evidence. It uses `RankingAnalysis.nextRefinement(involving:)`, an optional pair filter on the existing information-gain selector. The explicit initial request may revisit a previously confident pair; subsequent answers use normal refinement thresholds. A pair is asked at most once per session; a later session can collect more evidence about it. Skip adds no evidence; Undo removes only the current draft answer; Cancel leaves saved history alone.

Save Answers appends the complete batch through `RankingStore.record`, preserving every old observation and globally recomputing the owning list. Repeated or contradictory answers remain separate observations with timestamps. No score is assigned manually, no item is replaced, and no historical evidence is erased. Original insertion diagnostics remain the insertion record, not a claim about later re-ranking sessions.

## Exact legacy handling

1. Keep the four original model definitions (`Item`, `RankingList`, `RankedItem`, `Comparison`) and default store location. Phase 1 added four cooking entities; the Source phase adds `DishSource` and a nullable relationship on Dish. SwiftData/Core Data performs automatic lightweight additive schema migration; no custom destructive migration, reset, or replacement store is used.
2. On Home, run `CookingStore.prepare` as an idempotent transaction. For each RankedItem not already represented by the unique `rankedItemID`, create one separate Dish and one imported cook pointing at the **same** RankedItem. Do not group similar or duplicate names into an inferred dish.
3. Copy only the old item name and creation timestamp. Use category Other as an explicit unclassified default. Cooked date, title and notes are nil; tags are empty. “Version 1” is a generated display fallback, not an inferred recipe or cooking date. `isLegacyImport` records provenance.
4. Do not rename or refit existing items during bridging. Item/list UUIDs, names, creation dates, strengths, uncertainties, diagnostic bytes, comparison IDs, endpoints, winners/ties and timestamps remain unchanged.
5. Preserve all legacy lists. Initially choose the largest established list as the global cooking list (ties: oldest creation date, then UUID), persist that choice, and never silently change it. With no lists, create an empty My Cooking list. Missing previously selected list produces an error, not a reset.
6. StayGrubby exposes only the designated personal global cooking ranking. Generic ranking-list selection and creation are not part of the product UI. If a migrated store contains additional historical `RankingList` records, their histories remain preserved internally and are not merged, reset, or exposed as separate StayGrubby rankings. New Version offers only dishes in the designated global list. Consolidating historical containers would require a future explicit migration decision. The user's current saved store has one list, so all existing cooks share its global ranking.
7. A failed bridge rolls back; the Home screen offers retry. A failed store open shows an error and never deletes or resets data.

A consistent SQLite backup of the user's simulator store was made before changes at `.local-backups/phase1-20261003/before.store`, with baseline inventory alongside it. That directory is git-ignored because it contains personal app data. Keep the checkpoint for rollback investigation; do not copy an old store over a running app.

Before the Source schema change, a second consistent checkpoint was made at `.local-backups/phase1-source-20261004/before.store`. Its `verification.json` records exact before/after semantic-field hashes for the ranking, comparison, Dish, and cook tables after the simulator build launched on the saved store. The test runner changed the app container path during installation; the verification located the active store and matched its contents to the checkpoint.

## Extension points and constraints

A future Recipe relationship belongs to Dish; an individual cook could later record a recipe revision if needed. CookingMedia already relates ordered, typed records to a CookingAttempt; later phases can lift V1's one-image UI constraint and add video or remote-state metadata. There is deliberately no media backend, recipe placeholder graph, account, or cloud subsystem in this phase.

Cooking UI and CookingStore understand categories, tags, dates and parent dishes. The ranking system only receives IDs and preference evidence. Generic save staging and batched evidence recording allow atomic domain writes without importing cooking models into the engine.

Before Phase 2: preserve this write boundary, choose any multi-list consolidation policy explicitly, and introduce versioned schema migrations when a non-additive schema change becomes necessary. The current unique constraints and local store target offline usage; any eventual cloud schema requires its own migration design. No unresolved migration failure is an acceptable reason to reset user data.

## Validation

`CookingModelTests` covers independent items/global ranking, relationships, persisted category and all standard tags, normalized custom tags and querying, metadata edits, safe deletion/refitting, repeated contradictory re-ranking, draft skip/undo/cancel, invalid sessions, disk reload, and a genuine disk upgrade from the four-model legacy schema (including duplicate names and multiple lists).

`CookingUITests` exercises New Dish → New Version → comparison → edit → re-rank/undo → relaunch → delete → relaunch using an isolated store. The original ranking, stress-simulation, persistence, UI undo/relaunch, and launch tests remain intact.

Validated on **October 4, 2026**, iPhone 17 / iOS 26.5 Simulator:

- All 25 pre-existing test functions and 11 new test functions have passing results (43 configured executions counting stress-matrix inputs and launch configurations).
- The complete suite was exercised; simulator resource exhaustion and accessibility-query timeouts required isolated sequential reruns of the UI workflows. The existing UI test and all its assertions remain unchanged. The final cooking workflow and original undo/relaunch workflow both passed.
- Final build and launch succeeded against the real local simulator store. Exact before/after comparison verified 1 RankingList, 14 RankedItems, and 34 Comparisons, including original names, IDs, relationships, scores/uncertainty, diagnostic bytes, winners/ties, and timestamps. The bridge added 14 Dishes and 14 completely linked cooks with safe legacy defaults, one CookingLibrary and no tags. The checkpoint's `verification.json` records counts and matching semantic-field hashes.
- Validation applies to the inspected simulator store; no physical-device store was opened or changed.

The Source extension was validated on **October 4, 2026**, iPhone 17 / iOS 26.5 Simulator. The complete existing and new test suite passed: 44 test cases, 57 parameterized/configuration executions, zero failures. `DishSourceTests` checks all seven types across disk reload, type-specific fields, no-source and legacy defaults, shared New Version inheritance, edits/removal without rank or comparison changes, cancellation, and Source cleanup after deletion. `DishSourceUITests` checks cookbook entry, switching to restaurant, removal, and relaunch. The final build launched with the saved user store. Its 1 RankingList, 14 RankedItems, 34 Comparisons, 14 Dishes, and 14 CookingAttempts matched the pre-change checkpoint exactly on semantic fields, including IDs, scores, uncertainty, diagnostics, evidence, timestamps, and links. It has zero DishSource rows and all 14 Dishes have a null Source relationship. The app display name and Home title are StayGrubby; project, module, and bundle identifiers remain unchanged.

The Phase 2A media extension was validated on **October 5, 2026**, on the same simulator target. The complete suite passed: 49 tests, 62 parameterized/configuration executions, zero failures, and zero skips. `CookingMediaTests` verifies optimized display and thumbnail files, persistence after disk reload, replacement/removal invariants, deletion cleanup, the no-photo path, and independent New Version ownership. The final app build launched against the saved store. Its ranking, comparison, Dish, cook, Source, tag, and library semantic-field hashes matched the pre-media checkpoint exactly; the additive migration created zero media rows for the 14 existing cooks.

Substantially changed files: `Cooking/` (models, taxonomy, drafts, persistence, write service and re-ranking session), `Views/Cooking/` (forms, global cooking list and details/re-ranking screens), `Grub_RankedApp.swift`, `ContentView.swift`, `Views/HomeView.swift`, `Models/RankingStore.swift` (transaction staging/batching), and `RankingEngine/RankingAnalysis.swift` (optional focused refinement filter). Added `CookingModelTests.swift`, `CookingUITests.swift`, this document, and a `.gitignore` entry for private backups. The original four model files, fitting code, insertion engine and original test files are unchanged.

## Phase 2C polish: Contains and Avoid

Allergen presence uses the existing CookingTag entity with **kindCode `contains`** and canonical Allergen codes `peanuts`, `treeNuts`, `sesame`, `milk`, `egg`, `wheat`, `soy`, `fish`, `shellfish`. No entity/property/schema migration or score mapping change is required. CookingProductOptions supplies the same canonical options to metadata entry, discovery, detail and search. CookingDraft.contains restores attempt.containedAllergens when editing; the existing creation/edit transaction persists these independently of other tag kinds.

Existing `allergy:peanutFree` and the other `*Free` codes keep their original, explicit free-of meaning. They are never renamed, inverted, converted into presence, or automatically removed. Editing restores them separately, displays “Legacy free-of labels,” and offers explicit removal; canceling retains the saved values. Detail and search continue to expose their original labels. Presence can coexist with legacy claims without the application pretending to resolve ingredient truth.

Avoid excludes a cook when its Contains set intersects ANY selected avoided allergen. Search, Course, Dietary and Avoid combine with AND; Dietary still matches any selected dietary value. Discovery is a read-only projection of the authoritative global ranking, retaining global ranks, scores, evidence and relationships. Clearing Avoid leaves other selections/search intact. Contains values are searchable as “Contains Milk,” etc.

Absence means **not marked as containing**, never verified/certified allergen-free. The Avoid selector explains: “Based on the allergens you’ve marked. Not marked contains does not mean allergen-free. Always verify ingredients for allergy safety.” These labels are organizational metadata supplied by the user.

Creation is still transactional: no models/files are written while metadata, initial reaction or comparisons remain incomplete. AddCookingView finalizes a complete RankingEngine session once, through CookingStore.create, before presenting its saved result. Persistence failure retains the draft and offers retry/cancel; success guards prevent repeated finalization. New Version reuses its selected Dish and creates one unique RankedItem in the existing global ranking.

The existing disposable simulator seed receives a separate, explicit one-use metadata-only update via DevelopmentTools/OneTimeDevelopmentAllergenUpdate.swift, outside every Xcode target. It checks the simulator, default local store, bundle, exact dish/cook/item/evidence identities and backed-up manifest, consumes its marker before mutation, and changes only tag records/associations. It does not reset or recompute the library. Normal app launches and ordinary tests cannot run it. Legacy Free seed labels are explicitly removed only from these identified disposable fixtures.

### Final polish persistence verification — October 6, 2026

After the complete suite and a normal saved-store launch, the backed-up development library still has **1 RankingList, 1 CookingLibrary, 12 Dishes, 15 CookingAttempts, 15 RankedItems, 356 Comparisons, 10 DishSources, 0 CookingMedia**. The global ranking UUID remains `503B2E64-D08E-42F3-845B-F98096EC93E2`. Every non-allergen semantic field and relationship matches the consistent pre-polish backup, including Dish/cook/item/evidence IDs, dates/updatedAt, strengths, uncertainty, diagnostics, scores, notes, Sources, and dietary/custom memberships. SQLite integrity and schema comparisons pass. No duplicate global list or UI-test fixture records were introduced.

The isolated metadata update removed exactly two unused legacy seed tag rows (Milk-Free/Egg-Free) and their five memberships, and added seven canonical Contains rows with sixteen memberships across eight existing cooks. Total tag rows/memberships are now **21/48**. Seven cooks remain unmarked. It neither rewrote ingredient notes nor inferred medically verified absence. The request marker and temporary target copies are absent; the utility remains outside all targets. Backups and semantic verification are retained under ignored `.local-backups/polish-20261005/`.

All 62 unit functions / 82 configured unit executions passed, including all nine presence values across disk reload, coexisting legacy claims, explicit legacy removal, Contains edits without ranking changes, parent/version ownership, and combined Avoid discovery invariants. The full scheme ran 76 functions / 99 configured executions with one landscape UI failure and no skips; all new polish UI tests passed. That historical landscape expectation was superseded by the October 7, 2026 upright-portrait-only decision; see UI_ARCHITECTURE.md for final verification. Ranking mathematics, score mapping, persistence schema and migrations are unchanged.

The **October 7, 2026 final portrait verification** passed the complete scheme: **77 tests / 98 configured executions, zero failures or skips**. After a normal saved-store launch, all entity semantic fields and relationships—including the complete tag rows/memberships and all ranking evidence—match the consistent pre-pass checkpoint. The library still has 12 Dishes, 15 cooks/items, 356 Comparisons, 10 Sources, 21 tags / 48 memberships (16 Contains memberships), and exactly one global ranking. No data or model/service code changed during this configuration pass. See UI_ARCHITECTURE.md for the portrait policy and full verification breakdown.
