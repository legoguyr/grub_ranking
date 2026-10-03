# Ranking simulation results

Deterministic Swift Testing run on iPhone 17 / iOS 26.5 Simulator, October 2, 2026.

Each size includes seven scenarios × four seeds × top/middle/bottom insertion: 84 sessions per size, 420 total. Established histories contain local and long-range comparisons (five observations per item). Opponents are selected by the production engine against its fitted order; simulation randomness affects responses only. No production comparison budget was introduced.

| Existing items | Consistent mean | Noisy mean | Cyclic mean | All-scenario mean | Maximum | Maximum / size |
|---:|---:|---:|---:|---:|---:|---:|
| 25 | 4.67 | 4.42 | 4.33 | 3.49 | 6 | 24.0% |
| 50 | 5.67 | 5.25 | 5.33 | 4.14 | 7 | 14.0% |
| 100 | 7.00 | 7.33 | 6.33 | 5.23 | 17 | 17.0% |
| 250 | 8.00 | 9.08 | 12.67 | 7.24 | 15 | 6.0% |
| 500 | 9.00 | 11.25 | 13.67 | 7.68 | 22 | 4.4% |

## Complete histories

Additional simulations build entire rankings sequentially from empty, recomputing all estimates after every insertion. These include the cheap first few items; their means should not be compared directly with the established-list insertion means above.

| Final item count | Mean comparisons per insertion | Maximum | Total evidence records |
|---:|---:|---:|---:|
| 25 | 3.320 | 5 | 83 |
| 50 | 4.360 | 6 | 218 |
| 100 | 5.290 | 11 | 529 |
| 250 | 6.896 | 14 | 1724 |
| 500 | 8.014 | 17 | 4007 |

A 20× increase in final size increased average insertion questions by about 2.41×. No meaningful-evidence session compared the new item with all existing items. This is empirical evidence for these workloads, not a worst-case sublinear guarantee for arbitrary adversarial answers.

## Scenario details

- Consistent: a single underlying strict ordering.
- Noisy: independently flip 15% of strict preferences.
- Cyclic: three-group rock-paper-scissors relationships, with within-group order.
- Frequent ties: 55% of responses become Too Tough.
- Close clusters: five clusters, mostly ties and otherwise noisy within each cluster.
- Separated tiers: five strictly ordered tiers, ties within a tier.
- Wrong reaction: consistent choices with deliberately misleading initial reactions.

| Size | Scenario | Mean | Maximum | Mean max-slot probability | Mean slot SD |
|---:|---|---:|---:|---:|---:|
| 25 | consistent | 4.67 | 5 | 0.979 | 0.566 |
| 25 | noisy | 4.42 | 5 | 0.967 | 0.726 |
| 25 | cyclic | 4.33 | 5 | 0.954 | 1.457 |
| 25 | frequentTies | 1.50 | 4 | 0.493 | 0.887 |
| 25 | closeClusters | 2.50 | 4 | 0.572 | 0.574 |
| 25 | separatedTiers | 1.67 | 2 | 0.488 | 0.722 |
| 25 | wrongReaction | 5.33 | 6 | 0.988 | 0.169 |
| 50 | consistent | 5.67 | 6 | 0.965 | 1.342 |
| 50 | noisy | 5.25 | 6 | 0.975 | 0.563 |
| 50 | cyclic | 5.33 | 6 | 0.931 | 2.167 |
| 50 | frequentTies | 2.00 | 5 | 0.525 | 1.553 |
| 50 | closeClusters | 2.42 | 5 | 0.487 | 1.006 |
| 50 | separatedTiers | 1.67 | 2 | 0.483 | 1.357 |
| 50 | wrongReaction | 6.67 | 7 | 0.990 | 0.168 |
| 100 | consistent | 7.00 | 7 | 0.993 | 0.327 |
| 100 | noisy | 7.33 | 17 | 0.965 | 1.021 |
| 100 | cyclic | 6.33 | 7 | 0.978 | 0.345 |
| 100 | frequentTies | 3.50 | 7 | 0.712 | 0.892 |
| 100 | closeClusters | 2.75 | 6 | 0.638 | 1.316 |
| 100 | separatedTiers | 2.00 | 2 | 0.640 | 1.383 |
| 100 | wrongReaction | 7.67 | 8 | 0.993 | 0.092 |
| 250 | consistent | 8.00 | 8 | 0.991 | 1.133 |
| 250 | noisy | 9.08 | 13 | 0.976 | 0.533 |
| 250 | cyclic | 12.67 | 15 | 0.985 | 0.189 |
| 250 | frequentTies | 4.25 | 6 | 0.711 | 1.439 |
| 250 | closeClusters | 4.67 | 12 | 0.882 | 0.793 |
| 250 | separatedTiers | 2.67 | 3 | 0.961 | 0.801 |
| 250 | wrongReaction | 9.33 | 10 | 0.990 | 0.146 |
| 500 | consistent | 9.00 | 9 | 0.990 | 3.101 |
| 500 | noisy | 11.25 | 22 | 0.969 | 2.832 |
| 500 | cyclic | 13.67 | 16 | 0.955 | 1.944 |
| 500 | frequentTies | 3.42 | 10 | 0.883 | 2.512 |
| 500 | closeClusters | 3.42 | 6 | 0.882 | 2.073 |
| 500 | separatedTiers | 2.67 | 3 | 0.961 | 2.178 |
| 500 | wrongReaction | 10.33 | 11 | 0.983 | 0.341 |

## Assertions and interpretation

Tests assert finite strengths/uncertainties/scores, 1–10 score bounds, converged optimization, bounded rank intervals, strong-evidence ordering, evidence-only reproducibility, valid refinement confidence/utility, and a generous logarithmic question envelope. Aggregate means must remain below half the list size; the 500/25 sequential mean ratio must remain below four. They deliberately avoid exact-count assertions.

Small comparison counts with ties do not prove fine-grained ordering accuracy. The maximum-slot probabilities are acquisition heuristics conditional on the existing order. Their high values under 15% noise and cycles must not be interpreted as empirical accuracy or calibrated confidence. Joint posterior uncertainty is reported separately. The current test matrix validates computational/model invariants and efficiency; human preference calibration remains an open product requirement.

All workloads are reproducible in `Grub RankedTests/RankingSimulationTests.swift`. `SIMULATION|` and `HISTORY|` lines in Xcode test logs contain raw measurements.
