# StayGrubby parallel development

This contract establishes four isolated local Codex sessions for stayGRUBBY / StayGrubby. Setup is coordination only; worker feature implementation requires a separate task. The GitHub repository remains `legoguyr/grub_ranking`; the primary checkout is not moved or renamed.

## Checkouts and common base

| Role | Branch | Checkout |
| --- | --- | --- |
| Coordinator | `main` | `/Users/guyrettig/Documents/Grub Rankings/Grub Ranked` |
| Profile | `feature/profile` | `/Users/guyrettig/Documents/StayGrubby-Worktrees/profile` |
| Onboarding | `feature/onboarding` | `/Users/guyrettig/Documents/StayGrubby-Worktrees/onboarding` |
| Sharing | `feature/sharing` | `/Users/guyrettig/Documents/StayGrubby-Worktrees/sharing` |

The verified post-TestFlight release checkpoint is `067c7b69b223ea60067297132a765a0ccd352238` — `Finalize TestFlight release configuration`. It follows `9968390465658c2a118d2668ee44a0958ea1ec1b` — `Finalize StayGrubby V1 for TestFlight`.

All three workers initially branch from the same coordination-only commit, `Establish StayGrubby parallel development contract`, whose parent is the release checkpoint above. That commit first adds this document. Its exact hash is discoverable in every checkout without embedding a self-referential commit hash:

```sh
git log --diff-filter=A --format='%H %s' -- PARALLEL_DEVELOPMENT.md
```

Record that full hash as the worker's base commit before editing. Run `pwd`, `git branch --show-current`, and `git status --short` at the start of every task; use only the assigned checkout. These are Git worktrees sharing repository metadata, not copied repositories. Unexpected work or divergence must be reported; never reset, clean, stash, discard, or overwrite it automatically.

## Ownership

**Coordinator:** Protect main, review architecture and worker output, detect conflicts, authorize or centrally implement shared changes, update shared contracts, integrate completed work, run comprehensive regression checks, and preserve release readiness. Main is the integration authority; do not casually implement feature work directly on main. This setup permits only its coordination-document commit on main and does not authorize pushing it.

**Profile:** Profile identity, layout, stats/presentation using existing data, existing Share My Top 3 entry-point presentation, profile components, and focused tests. The current Profile screen is `StayGrubby/Accounts/AccountView.swift`. Its account state, sign-out, sync Retry, fresh-restore check, ranking lookup and development-library behavior are existing contracts to preserve. It does not own ranking, backend/schema, sync, authentication implementation, global navigation, shared models/persistence, onboarding or renderer internals. Coordinate with Sharing before changing their shared Top 3 action; its placement in AccountView belongs to Profile.

**Onboarding:** Onboarding, first-launch presentation, native Sign in with Apple presentation, authentication loading/setup/error/retry UI, components and focused tests. Its primary screen is `StayGrubby/Accounts/AuthenticationGateView.swift`. Preserve Open → onboarding/auth → native Sign in with Apple → Supabase auth → permanent StayGrubby account → account store ready → app. Preserve native Apple control lifetime and existing callback/nonce/token semantics; presentation ownership does not authorize changing auth behavior. It does not own auth architecture, account models/schema, sync, ranking, Profile or renderer internals.

**Sharing:** Existing sharing/result/celebration presentation, individual and Top 3 presentation, components and focused tests. Primary files are `StayGrubby/Views/Cooking/CookingRankingResultView.swift` and the presentation/action files in `StayGrubby/Sharing/`. Existing rendering is physically approved: build on it; do not redesign or replace it without explicit direction. It does not own ranking, unlock calculations, persistence/sync, schema, Profile generally or onboarding/auth.

Sharing must preserve official **#stayGRUBBY** branding; individual photo exports at **1080 × 1350 (4:5)**; no-photo fallback at **1080 × 1080**; Top 3 at **1080 × 1350**; official brand-red exported scores regardless of in-app score band; private global rank only in-app; permanent Share My Top 3 after scores unlock; optional Updated Top 3 only after a genuine new #1; and native image sharing. Preserve existing eligibility, achievement, privacy and local-media validation behavior.

## Shared collision points

The following boundaries are identified from this repository. Do not treat ownership of a screen as ownership of the services it calls.

| Files/directories | Boundary / coordination required |
| --- | --- |
| `StayGrubby/StayGrubbyApp.swift`, `StayGrubby/ContentView.swift`, `StayGrubby/Accounts/AccountApplicationRoot.swift` | App root, navigation, ready-account gating, development fixtures and sync lifecycle; Coordinator-owned. |
| `StayGrubby/DesignSystem/`, `StayGrubby/Assets.xcassets/` | Global theme/components/header and official brand assets; shared primitives require explicit authorization. |
| `StayGrubby.xcodeproj/` including `project.pbxproj`, scheme and `Package.resolved`; `StayGrubby/StayGrubby.entitlements`, `PrivacyInfo.xcprivacy`, `Configuration/` | Project, package, signing, release/privacy configuration; preserve StayGrubby product/module/test identity and `com.guyrettig.StayGrubby`. File-system-synchronized source groups already exist; do not automatically edit project configuration for ordinary new source files. |
| `StayGrubby/Models/`, `StayGrubby/RankingEngine/`, `StayGrubby/Item.swift` | Shared domain, ranking mathematics/evidence/score behavior; outside worker scope. |
| `StayGrubby/Cooking/`, especially `AppPersistence.swift`, `CookingStore.swift`, `CookingLibrary.swift`, `CookingAttempt.swift`, `LocalPhotoStore.swift`, `CookingMedia.swift` | Shared persistence/domain/media and workflow contracts; outside worker scope. |
| `StayGrubby/Accounts/` except the assigned presentation portions of AccountView/AuthenticationGateView | AccountSessionCoordinator, AccountLibraryAccess, SupabaseAccountBackend, AppleSignInSecurity, VerifiedAccountCache and development access; shared auth/account contracts. |
| `StayGrubby/Sync/`, `Backend/`, `supabase/` | Sync, photo transport, schema, migrations and backend tests; no worker backend/migration/hosted-data changes without explicit authorization. |
| `StayGrubby/Sharing/ScoreUnlockPolicy.swift` | Eligibility, unlock calculations, milestone receipts and shared score UI; its location does not grant Sharing ownership of the policy. |
| `StayGrubby/Sharing/ShareCardRenderer.swift`, `ShareCardModel.swift`, `ShareCardView.swift`, `TopThreeShareCard.swift`, `DishShareAction.swift`, `TopThreeShareAction.swift`, `NativeDishShareSheet.swift` | Common renderer/models/actions reused by Profile, results and Detail. Sharing owns assigned presentation work while preserving approved rendering and contracts; cross-screen/API/renderer changes require Coordinator coordination. TopThreeShareCard.swift also contains milestone UI. |
| `StayGrubby/Views/Cooking/AttemptDetailView.swift`, `AddCookingView.swift`, `ReRankView.swift`, `StayGrubby/Views/HomeView.swift` | Shared entry points for detail sharing, results, ranking and milestones; document dependencies instead of changing unrelated flows. |
| `StayGrubbyUITests/StayGrubbyUITestHelpers.swift`, existing mixed-scope test files and architecture/review documents | Shared fixtures/helpers and regressions; prefer separate workstream-specific tests, coordinate unavoidable edits. |

Before editing, list expected owned files and unavoidable shared files. If an unassigned shared change is needed, stop that portion and report the dependency to the Coordinator. The Coordinator decides whether to make it centrally or explicitly authorize the worker. Continue independent authorized work. No opportunistic refactors, broad formatting changes or behavior changes outside scope.

## Worker and integration protocol

1. Other sessions may be active. Stay in your own checkout and branch. Never merge into main, rewrite another worker's branch, or discard another session's work. Workers do not push or merge unless explicitly instructed; integrating into main remains Coordinator-only.
2. Implement only an explicitly assigned task within the ownership boundaries. Preserve existing behavior, contracts and approved sharing. Add/update focused tests for feature work.
3. Use a distinct DerivedData directory per worktree. Coordinate simulator/device use: checkouts still share Simulator services, Keychain and device data. Use existing isolated test stores/media fixtures; never seed or overwrite the preserved development or real-account library. Do not run concurrent UI tests on the same simulator or change hosted data.
4. Commit coherent completed work only to your own feature branch. Report blockers/shared dependencies before modifying shared boundaries.
5. Coordinator reviews the commit/file inventory and tests, compares against the reported base, resolves shared dependencies centrally, and integrates approved commits one workstream at a time. Do not automatically merge main into worker branches; arrange baseline updates with Coordinator and report the new base explicitly.
6. Coordinator runs appropriate focused tests plus comprehensive regression/build/release-readiness checks for integrated product changes, using existing review documents. Preserve authentication, ranking, score unlock, export privacy, sync/media and release configuration. Pushes require explicit user direction.

Every worker completes each task with this integration report:

```text
Workstream / task:
Branch:
Base commit (full hash):
Commits created (hashes and subjects):
Files changed:
Shared files touched (or NONE; include authorization):
Tests run (exact commands/configuration and results, failures/skips):
Dependencies discovered:
Migrations/backend changes (normally NONE):
Known issues:
Integration instructions for Coordinator:
```

Existing references: `UI_ARCHITECTURE.md`, `ACCOUNT_ARCHITECTURE.md`, `V1_SHARING_ARCHITECTURE.md`, `SYNC_ARCHITECTURE.md`, `MEDIA_SYNC_ARCHITECTURE.md`, `TESTFLIGHT_READINESS_REVIEW.md`. Their historical sections are not authorization to weaken current contracts.
