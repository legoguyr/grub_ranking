# Cooking data foundation

Phase 1 adds local cooking metadata around the existing generic ranking system. The Bradley–Terry fit, score mapping, insertion policy, confidence calculation, and original ranking tests are unchanged. See `RANKING_MODEL.md` for inference details.

## Ownership and relationships

- **Dish**: unique UUID, shared base name, default controlled category, creation timestamp, and versions. It contains no score or inference logic.
- **CookingAttempt**: unique UUID, parent Dish, unique `rankedItemID` plus a SwiftData reference to that RankedItem, cooked date, optional version title and notes, category snapshot, tags, sequence number, created/updated timestamps, and legacy-import provenance. The interface calls it a *cook* or *version*.
- **RankedItem**: owns ranking identity, cached display name, creation date, estimated strength/uncertainty and insertion diagnostics. Every cook has its own item. All new cooks, including versions of one dish, enter the same global RankingList.
- **CookingLibrary**: persists the UUID of the chosen global list. This application adapter keeps cooking ownership out of RankingList and the inference engine.
- **CookingTag**: shared structured rows identified by `kind:value`, with separate dietary, allergy, and custom kinds. Relationships support filtering by a tag; scalar raw codes support SwiftData predicates. Unused tag rows are retained for reuse.

SwiftData references are optional to support nullification and additive migration; `CookingStore` is the application write boundary and creates complete Dish → cook → RankedItem links atomically. Do not delete cooking-related RankedItems or Dishes directly through a ModelContext: use the cooking service so scalar comparison references are cleaned up too.

## Categories and tags

`DishCategory` is the controlled list: Main, Appetizer, Side, Soup, Salad, Pasta/Noodles, Sandwich, Breakfast/Brunch, Snack, Dessert, Baked Good, Sauce/Condiment, Drink, Other. Persisted raw codes are stable and separate from labels. The dish default initializes each new version; changing a cook's category changes only its snapshot. Phase 1 does not expose a separate default-category editor.

Dietary: Kosher, Vegetarian, Vegan, Dairy-Free, Gluten-Free, Halal.

Allergy: Peanut-Free, Tree-Nut-Free, Sesame-Free, Milk-Free, Egg-Free, Wheat-Free, Soy-Free, Fish-Free, Shellfish-Free. These are user-entered labels, never a safety certification.

Custom labels trim/collapse whitespace; identity also folds case and character width. The first saved display spelling is retained. Blank labels are ignored. Standard tags and identically named custom tags remain distinct kinds. Tags are separate records, not a hashtag string or comma-delimited database field.

## Creation, editing, deletion

**New Dish** collects metadata as a value-only draft, then uses the existing initial reaction and adaptive comparisons. **New Version** first selects a dish from the global cooking ranking, inherits its name/default category, then follows the identical global comparison flow. There is no per-dish ranking. Cooked dates default to today for new forms; legacy unknown dates remain unknown. Save Cook commits the dish (if new), cook, item, comparisons, and tags in one transaction. Cancel writes nothing. The completed comparison screen permits undo before saving.

Editing metadata retains cook/item IDs, strengths, uncertainties, diagnostics, and all comparison IDs/timestamps. Renaming a dish updates every sibling's cached display name; the form explains the shared rename. Title, notes, date, category, and tags apply to the individual version. Empty optional text becomes nil.

Deletion explicitly removes every comparison incident to that item, including repeated observations, ties, and later refinement. It removes the cook and item, deletes an empty final parent Dish, and recomputes the remaining list with the existing model. Other versions and unrelated observations remain intact. Tag relationships nullify; shared tags survive. The list itself stays available when empty.

## Re-ranking

`ReRankingSession` is a value-only application session over generic IDs and evidence. It uses `RankingAnalysis.nextRefinement(involving:)`, an optional pair filter on the existing information-gain selector. The explicit initial request may revisit a previously confident pair; subsequent answers use normal refinement thresholds. A pair is asked at most once per session; a later session can collect more evidence about it. Skip adds no evidence; Undo removes only the current draft answer; Cancel leaves saved history alone.

Save Answers appends the complete batch through `RankingStore.record`, preserving every old observation and globally recomputing the owning list. Repeated or contradictory answers remain separate observations with timestamps. No score is assigned manually, no item is replaced, and no historical evidence is erased. Original insertion diagnostics remain the insertion record, not a claim about later re-ranking sessions.

## Exact legacy handling

1. Keep the four original model definitions (`Item`, `RankingList`, `RankedItem`, `Comparison`) and default store location. `AppPersistence` adds four new entities. SwiftData/Core Data performs an automatic lightweight additive schema migration; no custom destructive migration, reset, or replacement store is used.
2. On Home, run `CookingStore.prepare` as an idempotent transaction. For each RankedItem not already represented by the unique `rankedItemID`, create one separate Dish and one imported cook pointing at the **same** RankedItem. Do not group similar or duplicate names into an inferred dish.
3. Copy only the old item name and creation timestamp. Use category Other as an explicit unclassified default. Cooked date, title and notes are nil; tags are empty. “Version 1” is a generated display fallback, not an inferred recipe or cooking date. `isLegacyImport` records provenance.
4. Do not rename or refit existing items during bridging. Item/list UUIDs, names, creation dates, strengths, uncertainties, diagnostic bytes, comparison IDs, endpoints, winners/ties and timestamps remain unchanged.
5. Preserve all legacy lists. Initially choose the largest established list as the global cooking list (ties: oldest creation date, then UUID), persist that choice, and never silently change it. With no lists, create an empty My Cooking list. Missing previously selected list produces an error, not a reset.
6. Existing generic screens remain accessible under My Rankings. If multiple historical lists exist, their histories remain independent. New Version offers only dishes in the designated global list, preventing accidental cross-list sessions. Consolidating other historical lists would require a future explicit product/migration decision. The user's current saved store has one list, so all existing cooks share its global ranking.
7. A failed bridge rolls back; the Home screen offers retry. A failed store open shows an error and never deletes or resets data.

A consistent SQLite backup of the user's simulator store was made before changes at `.local-backups/phase1-20261003/before.store`, with baseline inventory alongside it. That directory is git-ignored because it contains personal app data. Keep the checkpoint for rollback investigation; do not copy an old store over a running app.

## Extension points and constraints

A future Recipe/source relationship belongs to Dish; an individual cook could later record a recipe revision if needed. A future Media entity should relate many media records to a CookingAttempt, with ordering/type metadata to support photos and videos. There is deliberately no single-image property, media backend, recipe placeholder graph, account, or cloud subsystem in this phase.

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

Substantially changed files: `Cooking/` (models, taxonomy, drafts, persistence, write service and re-ranking session), `Views/Cooking/` (forms, global cooking list and details/re-ranking screens), `Grub_RankedApp.swift`, `ContentView.swift`, `Views/HomeView.swift`, `Models/RankingStore.swift` (transaction staging/batching), and `RankingEngine/RankingAnalysis.swift` (optional focused refinement filter). Added `CookingModelTests.swift`, `CookingUITests.swift`, this document, and a `.gitignore` entry for private backups. The original four model files, fitting code, insertion engine and original test files are unchanged.
