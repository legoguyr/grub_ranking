# Integrated sharing presentation — October 15, 2026

The approved card model/renderer/compositions, export dimensions, brand-red scores and eligibility/achievement policy remain unchanged. Profile's permanent Top 3 and completion/milestone actions share the same image-only native sheet. Reusable Top 3 stays distinct from the genuine SCORES UNLOCKED milestone; Updated Top 3 still requires a genuine new global #1.

ShareCardPreview displays the actual rendered bytes. Results keep identity, semantic native score and private position separate from export accessibility. Preview failures offer retry without committing ranking data again. NativeShareOutcome maps UIKit completion: Save Image success alone reports Image saved, save/share errors report failure, ordinary sharing/cancellation do not claim a saved photo. NativeShareFeedback handles callback/dismissal ordering before showing notices. The DEBUG fault-review subtree requires an isolated UUID store/media root and is excluded from Release.

See V1_INTEGRATION_REVIEW.md for combined regression/visual evidence and pending integrated physical approval. Earlier verification sections are dated history; V1 and release configuration are checkpointed and 1.0 (1) uploaded Internal Only. No new public URL/social service exists.

# Current score gate and second fixed composition

Individual numerical exports are available only when ScoreUnlockPolicy finds at least ten eligible active ranked entries (including independent versions) in the accepted local global ranking. ShareCardModel carries no score before that threshold, and ShareCardRenderer rejects a locked model. Completion and Detail suppress their numerical previews/actions while locked and refresh live models before exporting. The TopThreeShareCardModel factory requires the same gate and preserves the actual first three eligible ranked entries, including versions of the same Dish. Both compositions reuse official branding, palette, bounded JPEG lookup, universal outline, exact ImageRenderer infrastructure and native UIImage-only sharing. Top 3 always exports 1080 × 1350. No historical gallery or themes are added. See V1_FINAL_REVISIONS_REVIEW.md for presentation receipts and current verification.

# V1 branding, ranking results and local image sharing

The V1 sharing feature is a presentation layer over the saved cooking graph and global ranking. It does not persist achievements, add a migration, modify ranking evidence or invoke a cloud operation. Phase 3D Part 2 passed authenticated physical-iPhone data-path verification; this feature coexists with its uncommitted implementation without adding another photo transport.

## One presentation and export path

`ShareCardModel.make(for:event:)` takes a saved `CookingAttempt` and optionally an ephemeral `RankingCompletionSnapshot` captured before its ranking session. The model contains only the exportable title, optional version subtitle, existing formatted score, one eligible achievement and a value copy of the local photo reference. It deliberately has no account information, global position, movement, Source, tags, allergens or notes.

An explicit custom version title is used when present. Otherwise a version subtitle is shown for a later sequence or a dish with retained multiple versions. A single original cook without a custom title has no subtitle. Scores use the existing `RankedItem.score`, formatted with one decimal place and a fixed decimal point; the sharing feature never calculates or writes a score.

The reusable `ShareCardView` is rendered directly into its own image by `ShareCardRenderer` using SwiftUI `ImageRenderer`, an explicit canvas size, scale 1 and opaque output. A photo card exports exactly 1080 × 1350 pixels. If no usable local photo is available, the same rendering system selects an intentional compact 1080 × 1080 card with the universal red plate-and-fork outline. This is not a screenshot of the results or detail screen.

Both `CookingRankingResultView` and Dish Detail use `DishShareAction`, which passes the rendered card to `NativeDishShareSheet`. The native share item is only the image. Sharing needs neither a network connection nor a backend sharing endpoint.

The generated application Info.plist declares `NSPhotoLibraryAddUsageDescription` in both Debug and Release: “Save your StayGrubby share card to Photos when you choose Save Image.” This supports the native Save Image action; iOS manages any add-only permission prompt when the user chooses that action. Merely preparing a card or opening the share sheet does not request gallery access. There are no custom Photos authorization calls, broad `NSPhotoLibraryUsageDescription`, automatic gallery writes or upfront permission flow. See [Apple's add-only purpose key](https://developer.apple.com/documentation/bundleresources/information-property-list/nsphotolibraryaddusagedescription) and [native save activity](https://developer.apple.com/documentation/uikit/uiactivity/activitytype-swift.struct/savetocameraroll).

## Branding and card composition

The supplied transparent `#stay Grubby.png` is the canonical wordmark, bundled byte-for-byte as `StayGrubbyWordmark.imageset/StayGrubbyWordmark.png` rather than recreated with a font. `OfficialBrandWordmark` crops its transparent export margins for card placement while preserving the official lettering and pixels. The official raster red takes priority over the conceptual mockup. `SGTheme.Brand` centralizes cream `#FAF3EC`, the supplied PNG's dominant red `#F10607`, and charcoal `#1F1F1F`.

The exported composition remains cream in either application appearance: wordmark, dish title, optional version, dominant square food photo or universal neutral fallback, smaller score and optional single achievement pill. Private ranking position and movement appear only in the in-app results screen. No Source, dietary/Contains/Avoid data, notes, account details, cloud status, App Store links or controls appear in the image.

The app icon uses the official wordmark at matching placement and scale on opaque cream and charcoal backgrounds. Corners are not manually rounded; iOS applies its own mask. `AppIcon.appiconset` contains three 1024 × 1024 RGB PNGs, with Apple's universal iOS default, dark and tinted luminosity entries. The tinted asset retains the same silhouette/placement as white luminance artwork on an opaque black field, allowing native system tinting without a third colored brand design. The optional local `DevelopmentTools/Branding/generate_brand_icons.py` rebuilds these variants from the bundled official PNG using Pillow; it has no network or application-launch hook. Bundle identity, automatic signing, Sign in with Apple entitlement and upright-portrait configuration are preserved.

## Conservative achievements

Eligibility reads the current global ordered items and valid saved non-tie comparisons between those items. At least one such comparison must involve the selected cook. Strict comparisons use the same rounded strength ordering as the existing ranking list, so a date/UUID tie-break does not justify a badge. No ranking fit is rerun.

Only one achievement is selected, in this precedence:

1. **NEW #1 DISH** is event-only. A matching pre-session snapshot must show a different existing leader and that the selected cook was not already first. That previous leader must remain in the current ranking and be connected through real non-tie evidence. The resulting cook must occupy first place with strictly greater ordering strength than every other cook, and newly saved non-tie evidence must involve it. An empty first library or a later Dish Detail share does not claim a new leader.
2. **BEST VERSION YET** requires complete retained sequence history from version 1 through the selected version. The selected attempt must have a later sequence than every retained sibling; each sibling must have a saved item in this global ranking, a real comparison path to the selected cook and a strictly lower ordering strength. Missing/deleted versions, ties, disconnected or later siblings prevent this claim.
3. **TOP 5** requires at least five saved items, at least five connected through real non-tie comparison evidence, and a current exact position in the top five. If a sixth item exists, the selected cook must be strictly above that boundary. A tiny or disconnected library does not earn this badge merely by containing fewer than five cooks.

If these facts cannot be proved, no pill is shown. Historical versions that were deleted cannot be reconstructed, so a sequence gap suppresses BEST VERSION YET. The event snapshot is transient presentation state and is never stored as a permanent achievement. Dish Detail re-sharing omits the snapshot and evaluates current-state BEST VERSION YET/TOP 5 again, preventing a stale NEW #1 claim.

## Completion and re-sharing

The completion screen is presented once after a saved numerical ranking result, not after individual answers. It displays the same card preview, the calculated score and exact personal position from the existing global order. Movement appears only when both a trustworthy previous position and the current position exist and differ; newly created items do not invent a prior position. Done closes the result; Share Dish uses the common image-export action. Motion remains restrained and honors Reduce Motion.

The preview height is bounded by a centralized design token so the normal portrait result can show its private ranking summary. Share Dish and Done live in a bottom safe-area inset, while the heading, preview and summary scroll for large text. This keeps the actions reachable without changing the fixed-resolution exported image.

Dish Detail adds Share Dish for the selected saved attempt. Selecting another version updates the model through that same path. It reflects the current title, score and conservative current-state achievement, rather than retaining the badge of an earlier completion event.

## Local media and privacy boundary

The renderer reads the supplied account-local media root and saved photo reference through the existing `CookingPhotoFiles` safe file lookup and JPEG validation. The existing development-library default storage convention is used when no explicit root is supplied; isolated Debug review resolves its own temporary root. Unsafe filenames/symlinks, oversized or damaged files and mismatched dimensions select the fallback. A valid locally imported photo is immediately sufficient. A photo restored by Phase 3D Part 2 is the same kind of local file and requires no special sharing path. Missing, invalid or currently unavailable bytes select the universal fallback safely. The share action never downloads a photo specifically for export, authenticates, provisions, uploads or changes media ownership/security.

Debug review fixtures must use isolated stores and media roots. Development review remains compile-time excluded from Release, and no fixture or sharing operation may alter the normal Simulator library. Ranking mathematics, stopping rules, comparison callbacks, filter semantics, authentication and the persistence schema remain unchanged.

## Verification and manual approval

Focused tests cover export dimensions, title/version/score formatting, photo selection/fallback, achievement eligibility and precedence, event/current-state separation, export privacy, shared rendering paths and native image items. The complete Debug suite, Release authentication gate, backend policies, builds, migration hashes and saved-store/credential checks are required for the combined working tree.

The exported card is a deterministic graphic; Dynamic Type remains required for the in-app results, actions and Dish Detail within upright portrait. Simulator review covers photo/no-photo, badge/no-badge, long identity text, version/no-version, score range and application appearances. Final physical-iPhone approval covers the actual app icon, visual quality and native image-sharing experience, with the passed photo-sync lifecycle documented separately. That original implementation task did not commit or push; later V1/release checkpoints and upload are recorded above.

See [V1_BRANDING_SHARING_REVIEW.md](V1_BRANDING_SHARING_REVIEW.md) for the combined verification evidence, exact feature inventory and one ordered physical/manual checklist.

## Milestone and reusable Top 3

The existing TopThreeShareCardModel now carries `isUnlockMilestone`. The normal factory defaults to false; Profile and the optional Updated Top 3 result action use this normal mode. The first-unlock view explicitly requests milestone mode. Only milestone mode draws SCORES UNLOCKED; normal mode leaves that footer space blank, preserving the physically approved row/logo composition and exact 1080 × 1350 canvas. Both modes take current top three eligible ranked entries, without Dish deduplication, through the existing local renderer and UIImage-only native sheet.

The Profile action recomputes eligibility/current content at export and becomes unavailable below ten entries. New-#1 detection keeps the existing conservative before/after/evidence achievement rules. Current #1 staying #1 or moving down is not a new leader. A genuine new #1 after either creation or Re-rank leaves its individual NEW #1 card primary and adds one optional Share Updated Top 3 button. It does not open another sheet automatically or replace the result with a second celebration. First-unlock precedence continues to show only its single milestone experience.
