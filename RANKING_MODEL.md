# Grub Ranked ranking system — technical specification

Status: local native MVP, hardened October 2, 2026. Ranking logic lives in
`Grub Ranked/RankingEngine`, uses Foundation and Apple's Accelerate, and has no
SwiftUI, SwiftData, network, or domain/category dependency. SwiftData adapters live
in `Models`. Existing insertion choices, stopping thresholds, and score scaling
are retained. There is no Improve Ranking UI yet.

## 1. Evidence and authoritative state

An observation is `(first UUID, second UUID, outcome, timestamp)`.
Outcome is 1 for a first-item win, 0 for a loss, and 0.5 for Too Tough.
Each persisted `Comparison` has its own UUID: repeated comparisons of the same
pair are separate, equally weighted observations. A contradictory answer does not
replace an earlier one. Too Tough is one fractional observation, not two wins.
Skip never enters the preference evidence.

Timestamps are captured when answering and preserved through persistence, loading,
replay, and refinement. All current likelihood weights are exactly 1; there is no
preference decay. Future weighting can use the original timestamps without a
schema change, but would require recalibrating inference and uncertainty.

Each list owns its own items and comparison history. The evidence is authoritative;
item strengths and uncertainties are replaceable caches. Every committed answer
batch/refinement recomputes the entire list from all retained observations. Scores
and positions are not frozen at insertion. Disconnected components remain
mathematically independent under the prior. Cross-list evidence is rejected at the
persistence API; the fitter ignores malformed/self/unknown-ID evidence and reports
the ignored count. Valid outcomes are exactly 0, 0.5, and 1.

## 2. Bradley–Terry point estimates

For strengths θᵢ and θⱼ:

```
p(i beats j | θ) = sigmoid(θᵢ − θⱼ)
sigmoid(x) = 1 / (1 + exp(−x))
log posterior = Σ[y log p + (1−y) log(1−p)] − (0.25 / 2) Σ θᵢ² + constant
```

The independent prior is N(0, 4), with precision λ = 0.25. All items use the same
prior. Initial reactions never enter this objective. The proper prior resolves
translation indeterminacy, prevents unbounded all-win/all-loss fits, and makes the
objective strictly concave. Cycles and opposite outcomes have a finite compromise
solution; no graph edge is treated as a mandatory ordering constraint.

The existing deterministic coordinate-Newton solver starts at zero, visits IDs in
UUID order, clips each step to ±1, and stops when the largest coordinate step is
less than 1e−8. A 250-pass optimizer safety limit is unrelated to the number of
questions. After fitting, `FitDiagnostics` reports iterations, the maximum absolute
full-gradient residual, ignored observations, and convergence (residual < 1e−6).
Refinement returns no suggestion if convergence is not established. Callers can
inspect diagnostics to distinguish this from a lack of useful questions.

## 3. Joint uncertainty, pairwise confidence, and rank ranges

`BradleyTerryModel.analyze(ids:evidence:)` returns a `RankingAnalysis` containing
point estimates and a joint Gaussian/Laplace approximation at the MAP:

```
H = λI + Σ p(1−p) (eᵢ−eⱼ)(eᵢ−eⱼ)ᵀ
Σ = H⁻¹
strengthSD(i) = sqrt(Σᵢᵢ)
differenceVariance(i,j) = Σᵢᵢ + Σⱼⱼ − 2Σᵢⱼ
P(θᵢ > θⱼ) ≈ Φ((θᵢ−θⱼ) / sqrt(differenceVariance))
```

The previous cache used `1/sqrt(Hᵢᵢ)`, a conditional error that ignored other items'
uncertainty. New recomputation uses marginal uncertainty from the full inverse.
Off-diagonal covariance propagates transitive relationships and is essential to
estimating differences. Existing caches from an older build should be recomputed
before interpreting their uncertainty; the analysis/refinement API always fits
fresh evidence. The score point estimates are unchanged by this covariance step.

`relationship(a,b)` exposes both order confidence and approximate predictive choice
probability. They mean different things: `P(θa > θb)` expresses parameter
uncertainty; `sigmoid(d / sqrt(1 + πv/8))` approximates a future choice averaged over
parameter uncertainty. A well-established near-tie can have uncertain order but
little left to learn.

`rankEstimates(sampleCount:seed:)` draws correlated strengths from N(θ,Σ) using
L⁻ᵀz, where H = LLᵀ. It uses a deterministic local PRNG (default seed 0x47525542),
512 draws by default, and at least 32. It reports one-based expected rank (computed
analytically as 1 + Σ P(other stronger)), a sampled rank SD, and empirical 95% rank
bounds. Sampling is for diagnostics, not random opponent selection. Bounds have
Monte Carlo error and should not be presented as calibrated user accuracy.

Strength and score intervals are model-conditional approximations. Sparse data,
nonstationary preferences, repeated correlated answers, and an inadequate
one-dimensional preference model can all make them overconfident. A tie contributes
the curvature of one fractional Bernoulli observation; a learned tie-propensity
model is not implemented.

## 4. Existing insertion acquisition policy (preserved)

`RankingEngine` is a value-type session with a frozen strongest-to-weakest snapshot
of existing IDs and a new item ID. It has a separate distribution over n+1 insertion
slots. This is an acquisition approximation conditional on the existing ordering,
not the joint Bradley–Terry posterior.

The initial slot weight at normalized position x is:

```
0.25 + exp(−0.5 * ((x − reactionCenter) / 0.35)²)
reactionCenter: liked = 0.2, fine = 0.5, disliked = 0.8
```

The floor keeps every slot possible. Answer likelihoods are 0.995 for slots
consistent with a win/loss and 0.005 for inconsistent slots. Too Tough uses
`0.001 + exp(−0.5 * ((slot − opponentIndex − 0.5) / 0.5)²)`, retaining positions
immediately before and after the opponent. Weights normalize after every evidence
answer. Skip changes only the set of available opponents, with no normalization
or preference update. Undo removes the latest active answer, including a skip,
and replay restores the previous opponent and probability distribution exactly.

The next unused opponent maximizes binary entropy of the cumulative slot mass at
that boundary. Ties in utility use the existing order deterministically. This asks
near the uncertain boundary and exploits the old ranking instead of redundantly
asking about every weaker/stronger item. The current insertion routine does not
repeat an opponent; global refinement may revisit that pair later.

## 5. Exact stopping rules and instrumentation

The first matching rule wins:

| Stop reason | Condition | Interpretation |
|---|---|---|
| `firstItem` | No existing items | No comparison is possible; neutral score |
| `singleSlotConfidence` | At least one evidence answer and maximum slot mass ≥ 0.90 | Conditional insertion concentration |
| `adjacentTieConfidence` | Tie evidence exists and some adjacent slot pair has mass ≥ 0.95 | Nearby/tie placement, no invented strict distinction |
| `opponentsExhausted` | No unused opponents remain | Provisional, **not** confidence |
| `lowInformation` | Best remaining boundary entropy < 0.08 bits | Little acquisition value under this approximation; provisional |

There is no fixed question budget. The second item usually needs only one answer.
Skipping everything can visit every opponent but contributes zero comparisons;
that is user-requested skipping, not an engine requirement for meaningful evidence.

`session.diagnostics(analysis:rank:)` exposes comparison/evidence count, skip count,
total answer actions (including later-undone ones), undo count, start time,
reaction, old list size, stop reason, maximum slot probability, slot mean/SD/95%
bounds/entropy, and—when a fitted model is supplied—strength SD, score interval,
model rank interval, and fit convergence/residual. Slot positions are zero-based;
model ranks are one-based. `RankingStore.save` persists a versioned JSON snapshot
in an optional `RankedItem.sessionDiagnosticsData` field. These snapshots describe
the time of insertion; refinement does not rewrite historical diagnostics. They
are internal data, with no primary UI addition or telemetry transmission.

### Stopping audit

The manually validated behavior and sublinear simulation results justify retaining
this acquisition policy for now. **The 0.5% violation assumption is optimistic**:
it is not a measured human error rate. A high slot probability does not establish
the same confidence in the displayed Bradley–Terry rank or numerical score. Noisy
or cyclic preferences can concentrate this approximate posterior around an
incorrect position. Large close clusters and ties also violate the idea of a
single strict insertion slot. Do not expose “90% certain” product claims from it.
The new joint uncertainty and refinement API provide a path to investigating these
cases without changing the current fast insertion experience.

## 6. Global refinement API

```swift
let analysis = BradleyTerryModel.analyze(ids: itemIDs, evidence: history)
if let suggestion = analysis.nextRefinement(excluding: skippedPairs) {
    // Present suggestion.pair; collect a win/loss/Too Tough observation.
    // RankingStore.record(observation, in: list, context: context)
}
```

All unordered pairs are candidates, including previously compared pairs. For a
pair with difference variance v and current MAP win probability p, utility is:

```
approximate information gain = 0.5 * log2(1 + p(1−p) * v)
```

This is the local expected Gaussian entropy reduction from one Bernoulli
observation (rank-one Hessian update / determinant lemma), not exact Bayesian
mutual information. It rewards uncertain, competitive pairs. Unlike raw choice
entropy it gives low value to a tie already known precisely. Candidates with
order confidence ≥ 0.975 or utility < 0.01 bits are omitted. Greatest utility wins;
UUID order breaks ties. `excluding` is symmetric and session-local. Skip does not
change stored evidence. A nil result can mean no eligible comparison, fewer than
two items, or an unconverged fit; inspect fit diagnostics.

`RankingStore.record` validates list membership and appends a fresh `Comparison`,
then refits every item and explicitly saves. Contradictory/repeated observations
remain in history. Completion undo refuses to delete a session if later refinement
has added evidence involving that item, preventing accidental loss of new history.

## 7. Score scaling audit

The unchanged display transform is:

```
score = 1 + 9 * sigmoid(strength / 2)
```

Zero strength maps to 5.5. Temperature 2 controls contrast; a stronger regularizer
also reduces contrast by shrinking strengths. There is no use of current rank,
list count, minimum, maximum, or percentile. The top item need not be 10 and the
bottom need not be 1. Adding an unconnected item leaves established scores exactly
unchanged. Connected new evidence may appropriately move all affected estimates.
These are preference-strength scores anchored to the model's fixed zero prior,
not universal quality measurements comparable across arbitrary independent lists.

A score at or above 9.95 rounds to 10.0 with one decimal. Solving the transform
requires `strength ≥ 2 * ln(179) ≈ 10.374771612`. For finite real strengths the exact
mathematical score is strictly inside (1,10); floating-point saturation can reach
the endpoints for extreme inputs. Both are distinct from forcing #1 to 10.

**Manual-test clarification:** the user confirmed that 10.0 was not actually
observed; that statement in the hardening brief was mistaken. A read-only audit of
the available simulator store found 14 items and 34 comparisons, with maximum
cached strength 2.795364881337627: score approximately 8.216 within the current
transform, displayed 8.2. No scaling change is warranted by this report.

95% score intervals transform `strength ± 1.96 * strengthSD` through the same
bounded function. They are asymmetric near the ends. One decimal is formatting,
not evidence that 0.1 differences are statistically meaningful.

## 8. Persistence and reproducibility

SwiftData lists own items and comparisons with cascade relationships. A draft is
saved only on completion; cancellation leaves no evidence. Save errors roll back.
Explicit completion undo removes only the inserted item/session evidence, refits
the remaining history, and reopens the previous question. Drafts are not restored
after relaunch. The legacy starter `Item` remains for store compatibility. The
new diagnostics field is optional so existing stores can migrate additively.

Timestamp round trips, repeated observations, JSON diagnostics, disk reopening,
list isolation, and replay consistency are tested. Engine types are explicitly
nonisolated so they do not inherit the app target's default MainActor isolation.
Persistence and current save orchestration remain on MainActor. App code can later
send immutable evidence to a worker without importing SwiftUI into the model.

Ranking ties use quantized strength keys (1e−7), then creation time and UUID. This
replaces a non-transitive epsilon comparator: pairwise `abs(a−b) < epsilon` is not
a valid sorting equivalence relation for three very close values. The change
only affects numerical near-ties, not meaningful preference gaps.

## 9. Complexity and operational limits

Point fitting uses up to 250 O(n+m) coordinate passes with O(n+m) sparse edge data.
The full covariance adds O(n²) memory and O(n³) factorization/inversion using
Apple Accelerate LAPACK. Each dense Double matrix occupies ~2 MB at n=500.
Refinement scans O(n²) pairs. Rank sampling costs O(samples × n²) for a batched
BLAS triangular solve plus per-draw sorting; it is not called for every insertion
question, only when explicitly requested or recording completion diagnostics.

[Apple's Accelerate documentation](https://developer.apple.com/documentation/accelerate)
describes the native BLAS/LAPACK foundation. The app target opts into modern LAPACK
headers with `-Xcc -DACCELERATE_NEW_LAPACK`. There is no third-party dependency.

At substantially larger scales, move analysis off MainActor and consider sparse
covariance queries or selected-rank sampling. Do not treat the dense 500-item test
as proof of production latency at tens of thousands of items. Invalid precision
factorization is an internal invariant failure: the positive λI and validated
finite evidence should make the matrix positive definite.

## 10. Validation and tuning

See `RANKING_SIMULATIONS.md` for reproducible workloads and measured comparison
counts. Tests cover the original MVP, analytical covariance, marginal versus
conditional uncertainty, pairwise confidence, deterministic joint rank intervals,
refinement in intentionally uncertain regions, known-tie saturation, repeated and
contradictory evidence, timestamp neutrality/round trips, global propagation,
diagnostics/undo, invalid evidence, fixed score scaling, and near-tie sorting.

Parameters to tune with real usage: λ=0.25; display temperature=2; half-win tie
semantics; insertion prior floor=0.25/width=0.35/centers=0.2,0.5,0.8; violation
floor=0.005; tie floor=0.001/width=0.5 slots; stopping masses=0.90/0.95;
boundary entropy floor=0.08 bits; refinement confidence ceiling=0.975 and gain
floor=0.01 bits; posterior sample count=512. Diagnostics version 2 identifies the
current configuration; these constants should be versioned when behavior changes.

Before confidence is surfaced in product UI, evaluate empirical coverage and
ordering accuracy on real noisy/tied sessions. More simulation samples do not fix
a misspecified likelihood. Repeated observations are statistically treated as
independent even when a human repeats an answer from memory. No temporal drift,
individual tie propensity, multidimensional preferences, or active-selection bias
correction is modeled.

### Final verification

The complete existing/new suite passed on iPhone 17 / iOS 26.5 Simulator:
**25 reported tests, zero failures, zero skips**, in approximately 142 seconds.
This comprises 23 Swift Testing engine/persistence/simulation test functions,
including the five-size parameterized matrix, the end-to-end UI flow, and launch
coverage in four UI configurations. The test build reported no warnings/errors.
Final simulation output matched the measurements in `RANKING_SIMULATIONS.md`.

The UI flow verifies list creation, two item insertions, final-answer undo, changed
preference, and persisted ordering after app relaunch. The latest failure was
traced to a native SwiftUI alert not exposing its TextField accessibility identifier;
the test now scopes to the native alert field. Unique debug-only test store paths
prevent UI tests from adding data to the user's rankings and remain consistent
across each test's relaunch. Working ranking behavior was not altered for the test.

Reproduce using Xcode's Grub Ranked scheme / Test action, or:

```sh
xcodebuild -project 'Grub Ranked.xcodeproj' -scheme 'Grub Ranked' \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test
```

The result bundle for the final run is
`~/Library/Developer/XcodeBuildMCP/workspaces/Grub-Ranked-c2d28c43fd9c/result-bundles/test_sim_2026-10-02T22-32-32-069Z_pid17143_d0bde3c4.xcresult`.

## Phase 3B synchronization boundary

RankingEngine, BradleyTerryModel, RankingAnalysis, score scaling and all acquisition/uncertainty policies remain unchanged. Persistence adapters can now journal committed account mutations alongside their existing saves; disabled/unbound guest stores do not journal. Transfer/hydration preserves RankedItem and Comparison UUIDs, repeated/tie observations, timestamps, diagnostic bytes and full-precision cached state. Hydration neither re-runs insertion nor averages caches. Any future accepted change in underlying evidence must be fitted by this same local engine; there is no cloud fitter or social input. See SYNC_ARCHITECTURE.md.
