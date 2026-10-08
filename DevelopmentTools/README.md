# Manual development cooking seed

These utilities are **outside all Xcode targets**. There is no reset/seed call in the app, launch flag, schema change, migration or ranking implementation change. Normal launches and the standard test suite cannot invoke them.

The requested October 5, 2026 reset targeted only the Debug app `com.guyrettig.Grub-Ranked` on iPhone 17 / iOS 26.5 Simulator `D839186C-3810-4C98-99FA-3C88230212DC`, with CloudKit disabled by the existing persistence configuration. A consistent SQLite backup and complete before snapshot were saved under the ignored `.local-backups/seed-20261005/` directory before mutation.

## One-use execution

`OneTimeDevelopmentSeed.swift` was temporarily copied into the unit-test target and compiled before any reset authorization was placed. Only its named test was invoked. It requires a manual `staygrubby-one-time-seed-request.json` in that simulator app's Application Support directory. It verifies the simulator, bundle ID, default-store path, existing ranking UUID, item/comparison/cook/dish UUIDs, tag count, absence of uninspected media/Sources, and the recorded backup fingerprint supplied by the manual preflight. It first builds and validates the whole dataset in memory, then consumes the request **before** deleting anything. A retry cannot reset the store again.

Deletion uses `CookingStore.delete` for the original 14 cooks and their incident evidence/empty Dishes. Only the five resulting unused cooking tags are explicitly removed. The existing RankingList and CookingLibrary identities remain; unrelated `Item` data is retained. Creation uses completed `RankingEngine` sessions through `CookingStore.create`, including shared Dish/Source inheritance for versions. `RankingStore.record` adds three rounds of observations for all 105 pairs. Synthetic preferences include close ties and upsets; no final rank, score, strength or uncertainty is written manually. A fresh Bradley–Terry analysis is checked against every stored estimate.

The utility is deliberately not an automatic/reusable reset script. To repeat a reset, inspect and back up the actual store again and issue a new explicit request describing its current IDs. The Swift utility and temporary copies are easy to remove; no production path depends on them.

## Representative records

The saved review library has 12 Dishes and 15 independently ranked CookingAttempts. Lamb Chops, Harissa Chicken Kabobs and Sea Bass each have two cooks. There are seven canonical Courses, short and long names, custom/default version labels, mixed notes, custom tags, Dietary selections, and optional simplified Sources: My Own, Cookbook, Online, Restaurant, Friend / Family, and no Source.

Attributions are illustrative development metadata, not verified cookbook/restaurant provenance. Online Sources use reserved `example.com` URLs, preserved verbatim. No network access or metadata retrieval is performed. The original seed included illustrative Free labels; the Phase 2C polish update below explicitly replaces those disposable labels with Contains metadata. Neither is medical verification or a cross-contact safety claim. The cake explicitly notes almonds, eggs and wheat. All 15 cooks intentionally retain the normal no-photo placeholder; no media is downloaded or added.

## Review verification

`SeededLibraryReview.swift` is likewise outside the UI-test target. A temporary copy substitutes a uniquely generated `__CLONE_TOKEN__` backed by a SQLite copy of the seeded store. The real-store test searches, filters, opens versions and exercises/cancels re-ranking. The isolated-clone test actually saves New Dish, New Version and re-rank answers, then relaunches. These test-created records never enter the review store.

After verification, temporary files inside both test targets are removed, and a normal app build/launch uses the seeded development store. Before/after source hashes verify that all existing application files, project configuration and Phase 2C documentation remain unchanged. The request marker is absent. The baseline, seeded snapshot, exact order/scores/IDs, test results and visual captures are retained in `.local-backups/seed-20261005/` for manual review and recovery. No commit or push is performed.

## Phase 2C polish: one-time presence metadata update

`OneTimeDevelopmentAllergenUpdate.swift` is another manual utility outside every target. It **does not repeat the reset**. A new consistent backup/manifest under `.local-backups/polish-20261005/` identifies the existing 12 Dishes, 15 cooks/items and 356 observations. The one-use `staygrubby-one-time-allergen-request.json` checks those identities, the selected Simulator/bundle/default store and recorded backup fingerprint, and is consumed before mutation. A temporary unit-target copy runs only its named test and is then removed.

The update replaces the reviewed disposable seed Free labels with explicit `contains` tags. Corn velouté versions contain Fish/Milk; Butter Chicken and saffron-yogurt Street Corn contain Milk; couscous contains Wheat; matzo balls contain Egg/Wheat; Tuna Crispy Rice contains Fish/Soy/Wheat/Sesame; almond cake contains Tree Nuts/Egg/Wheat. These are illustrative ingredient choices for fixtures, not medical verification. Other seed dishes have no presence marks. No photos, names, dates, notes, Sources, scores, strengths, uncertainties, diagnostics, ranking evidence or identity relationships are changed.

Ordinary saved legacy Free labels remain semantically intact in the application. The seed template now uses presence metadata for future explicitly authorized resets. SeededLibraryReview uses Avoid and the automatically saved result close action. The original seed reports remain historical evidence of that earlier reset.
