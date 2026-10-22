# StayGrubby product structure and score review

## Starting audit

October 22, 2026: `main` at `11a0bbd3c5e09ce559234b6bf51f56099d29f85e`, clean and synchronized with tracking `origin/main`. The approved design checkpoints are ancestors. The owner's build 2 is already committed in `11a0bbd`; it is not an uncommitted edit to exclude. Keep the warm editorial design and official assets.

One primary agent and one Simulator lane. No physical testing, distribution, destructive hosted operations, reset or Recipe Engine implementation. Risk-based checks at each checkpoint, one broader affected integration near completion.

Baseline: the complete demo manifest matches SHA-256 `bedd790ea8487f3b1baad442acd9092a6890b0a38cede4951aef0018469b9a51`: 1 ranking, 12 dishes, 15 attempts/items, 356 comparisons, 10 sources, 21 tags, 48 memberships and 190 media files. Fresh hosted fingerprints captured before edits: 3 accounts/rankings, 32 dishes, 37 attempts/items, 133 comparisons, 13 sources, 10 tags, 51 memberships, 35 media records, 68 sync receipts, 5 social posts, 1 comment and 57 Storage objects. The 45-object figure from the prior review predates owner activity; this cycle preserves the current baseline. All 21 hosted migration hashes match local SQL; all 32 application tables have RLS.

## Navigation checkpoint

Four native tabs: Grub List, Grub Rank (default), Food Bible, My Kitchen. Food Bible now hosts the existing Recipes/Tickets library; Recipes and private want-to-cook Tickets are selected within it. The redundant completed-cook browser and standalone Tickets tab are removed. Grub Rank and its existing Detail/creation routes remain the photographic cooking record. Existing Ticket save/remove, Recipe revision, Make This and historical provenance contracts are retained. Current Tickets reference accessible Recipes; no separate inspiration-ticket model exists, and none is invented here. The library's existing Recipe service/content abstraction remains available for the later on-device Recipe Engine.
