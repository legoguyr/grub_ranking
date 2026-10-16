# StayGrubby development workflow

## Default: one primary Codex workflow on main

The temporary Onboarding / Profile / Sharing experiment is complete. Parallel feature worktrees are **not** the default. Implementation, testing and integration normally stay together with one primary agent in the original checkout, on `main`:

`/Users/guyrettig/Documents/Grub Rankings/Grub Ranked`

Use **one Simulator/UI-test lane at a time**. Do not create new feature worktrees or parallel workers unless the user explicitly requests them. Future genuinely independent social/backend/moderation work may justify parallelization, with shared contracts and Simulator ownership agreed first. Inspect branch/status before work; never reset, clean, discard or overwrite unexpected changes. Physical approval and distribution remain separate gates.

The repository remains `legoguyr/grub_ranking`; this checkout is not renamed or moved.

## Completed experiment and retained history

The release checkpoint `067c7b69b223ea60067297132a765a0ccd352238` follows V1 checkpoint `9968390465658c2a118d2668ee44a0958ea1ec1b`. All three workers branched from `97b1bc3b0f041cc2bbf38b19bde1b1354f7c9953` (Establish StayGrubby parallel development contract).

| Workstream | Branch | Completed commit | Retained checkout |
| --- | --- | --- | --- |
| Onboarding | `feature/onboarding` | `4d6b60d02bc24ef36efeb3a6687864e1ff0cba84` | `/Users/guyrettig/Documents/StayGrubby-Worktrees/onboarding` |
| Profile | `feature/profile` | `778615ab6a9f5f57f6e141e6b1b0ed57b5761cb0` | `/Users/guyrettig/Documents/StayGrubby-Worktrees/profile` |
| Sharing | `feature/sharing` | `79792a6e7fe9d50d6b196b7e507f5cbc998ba57e` | `/Users/guyrettig/Documents/StayGrubby-Worktrees/sharing` |

Integration preserves the three worker commits as ancestors. [V1_INTEGRATION_REVIEW.md](V1_INTEGRATION_REVIEW.md) records combined verification and the physical-review gate. Independent worker reports do not approve the combined product. Historical ownership rules remain available with `git show 97b1bc3:PARALLEL_DEVELOPMENT.md`.

Do **not** delete worker branches/worktrees during integration. They are eligible for later cleanup only after their exact commits are confirmed ancestors of main and their checkouts are clean; preserve any subsequent work.

## Continuing contracts

- Preserve ranking math/evidence, score visibility, independent versions and true global ranks.
- Preserve account readiness, ownership, structured/photo sync, tombstones and official assets/renderers.
- Use isolated test stores/media; never reset/seed the real account or preserved demo library as test fixtures.
- Keep development controls compile-time excluded from Release; never embed privileged credentials.
- Verify the combined application after cross-surface changes. Stop and diagnose process exhaustion; do not start more Simulators.
- No automatic upload, tester changes or submission. Version 1.0 (1) already uploaded Internal Only; a later build follows physical review and explicit distribution approval.

The canonical future plan is [STAYGRUBBY_MASTER_ROADMAP.md](STAYGRUBBY_MASTER_ROADMAP.md); specialized architecture documents remain authoritative for implementation contracts.
