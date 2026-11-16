# Plan: the few-clusters design study (U4)

**Date:** 2026-11-16 · **Status:** planning only. The plan is the deliverable; running the campaign needs the
maintainer's authorization (decision **M1** below). No package code changes, no release, no CRAN.

**Sources.** Item 1 of "Order if work is authorized" and unblock condition U4 in
`planning/PLAN-multilevel-implementation-gaps-2026-11-11.md`; gaps G2, G7, idea I4 and sections 5.0, 5.3 of
`planning/specs/LIT-multilevel-sem-gaps-2026-11-11.md`; the proposal in the private book repository (read only):
`research/multilevel-sem/PROPOSAL-2-EXPANDED-2026-11-11.md` (cited below as "P2X §n") and section 2 of
`research/multilevel-sem/PROPOSALS-2026-11-11.md`. This plan points to P2X sections instead of copying them.
Labels: claims drawn from a file cite it; **INFERENCE** marks this plan's own reading.

## 1. Goal

Measure the shipped lavaan two-level (1-1-1) adapter at small J, low ICC and unbalanced cluster sizes, and supply
the U4 reliability grid that IG1 (native two-level ML, S4) waits on, including a level-2 variance parametrization
experiment (floor versus unconstrained) run in lavaan.

Uses only shipped code: `extract_mediation()` on two-level lavaan fits (`TwoLevelMediationData`,
`TwoLevelParallelMediationData`), `tidy()` delta intervals, `twolevel_statistic()` and `bootstrap_mediation()`
(parametric and cluster). Files: `R/extract-lavaan-twolevel.R`, `R/twolevel-statistic.R`.

**Non-goals.** No S4 code and no change to the native solver (`tests/sim/risk-files.txt` files untouched); no
change to the adapter or its defaults (the evidence on them is an output, section 7); no release, no CRAN; no
Bayesian or few-cluster-robust arm (I4 needs S6; P2X §3 ideas 6 to 7); no random slopes (Q3); no gate registration
in this study (decision **M6**).

## 2. Standing decisions, stated

- **Q8** (grill ledger `planning/GRILL-multilevel-mediation-2026-11-10.md`, row Q8, on branch
  `claude/restore-b0bd19`; restated in LIT §5.0): "Native `fit_sem()` errors (classed, ADR D-11); adapter flags
  `admissible = FALSE` with a warning", because "a flag only protects consumers that check it".
- **D-11** (`planning/specs/ADR-native-solver-and-engines-2026-10-23.md`, line 165): "A partial branch result is an
  error (PR #303)": a dropped zero-product branch is a classed error, not a fit carrying a flag.
- **INFERENCE:** D-11 itself is about partial branch results; Q8 applies its error-not-flag principle to Heywood
  cases. The gaps plan's paraphrase ("Q8 and ADR D-11 (native fits error on a Heywood case)") merges the two. The
  study changes neither: the floor arm (section 5) measures how a fit reaches a solution, it does not replace the
  error or the flag (LIT §5.3 item 2).
- Q3 (fixed slopes, `sigma_ab = 0`) and Q4 (the contrast is descriptive) hold (LIT §5.0).

## 3. What the adapter does at the edges (the behavior under test)

From `R/extract-lavaan-twolevel.R` (defaults at line 14, overridable by `options()`):

| Condition | Adapter behavior | Class |
|---|---|---|
| J < 50 (`min_clusters`) | warns, returns estimates | `medfit_warning_twolevel_few_clusters` |
| `post.check` FALSE (negative variance, non-PD) | warns, `admissible = FALSE`, estimates kept | `medfit_warning_twolevel_inadmissible` |
| treatment or any mediator ICC < .01 (`icc_error`), non-finite or non-PD path block, or non-converged | within-only object, `between_identified = FALSE` | `medfit_between_unidentified` |
| identified but X or M ICC < .05 (`icc_warn`) | warns, between results kept | `medfit_warning_between_weak` |

From `R/twolevel-statistic.R` (lines 30 to 36, 204 to 245): a refit that errors, does not converge, warns, or
has X or M ICC below `icc_error` (between or contrast effects) is a failed replicate; an inadmissible refit is kept
(`check.post = FALSE`); refits use `se = "none"`, `test = "none"`. The stored call is re-evaluated with only `data`,
`se`, `test` and `check.post` replaced, so model-syntax floors and `control = list(iter.max = )` carry into refits
(INFERENCE from the code; answers P2X §9's open `iter.max` question).

## 4. Estimands and design

**Estimands** (P2X §2): `NIE_W = a_w b_w`, `NIE_B = a_b b_b`, the contrast `Delta` (shipped row `nie_contrast`,
within minus between; bias and coverage only, Q4). Secondary: `c'_w`, `c'_b`. **Optional (M4):** two parallel
mediators, total NIE per level, under the IG5 D2 all-or-nothing ICC rule, on six reduced cells
(`planning/PLAN-IG5-twolevel-parallel-2026-11-15.md`: T1 to T4 shipped, T5 docs pending; P2X §5.3's line tying
several mediators to S5 is stale).

**DGP:** P2X §4.1 (the O8 oracle population; truths `NIE_W = .20`, `NIE_B = .18`, `Delta = -.02`; between
variances scaled by `s`). `ICC_X = .7s / (.7s + 1)`, so `s = ICC_X / (.7 (1 - ICC_X))`:

| target ICC_X | s | implied ICC_M |
|---|---|---|
| .05 | .075 | .039 |
| .10 | .159 | .079 |
| .20 | .357 | .161 |
| .40 | .952 | .338 |

(INFERENCE: arithmetic from P2X §4.1; `ICC_M = .563 s / (.563 s + 1.05)`; T1 recomputes from the implied
covariances.) At ICC_X = .05 the mediator ICC sits below `icc_warn` (.05), so most fits there raise
`medfit_warning_between_weak`; that is intended.

**Grid (main = P2X §5.2 reduced grid).** Thresholds come from mediation-specific evidence, per the G2 caution
(LIT §4 G2: "Cluster thresholds for medfit's reliability grid must come from mediation-specific cells ..., not from
the Hox range"). [Hox2012] is not used.

| Factor | Levels | Source for the levels |
|---|---|---|
| J | 10, 20, 30, 50, 100 | Hox et al. 2014 (2-1-1-1 CRT, full text): 5 to 50 clusters per arm, ML convergence problems below 25; [Preacher2011] (2-1-1, supplement tables): J from 20; [McNeish2017] (MSEM mediation, abstract in part): about 100 needed, published median 44; the adapter's 50 warning. All via P2X §6.1 |
| n (mean) | 5, 20 | [Preacher2011] n 5, 20, 50; Hox et al. 2014 n 5 or 10 (P2X §6.1) |
| ICC_X | .05, .20, .40 | [Preacher2011] ICC .05 to .40 (P2X §6.1) |
| balance | equal; unequal (CV about .5, same mean) | INFERENCE (P2X §4.2); no mediation source read sets a CV |
| between effect | `NIE_B = .18`; `NIE_B = 0` (`b_b = 0`) | P2X §4.2 |

5 x 2 x 3 x 2 x 2 = 120 cells. Caveat: every source above is 2-1-1 or 2-1-1-1, not 1-1-1 (P2X §6.2); the 1-1-1
gap is why the study exists. **M3:** add ICC_X = .10 (and a cell near `icc_error`, e.g. ICC_X = .02) to bracket the
adapter thresholds.

**Replications.** Coverage MCSE `sqrt(p (1 - p) / R)`: R = 1000 gives .0069 at p = .95, so the (0.925, 0.975) band
half-width is 3.6 MCSE (P2X §4.5). Bootstrap arm at J <= 20: R = 500 (MCSE .0097), B = 499. Conditional coverage
uses the realized denominator for its MCSE and reports NA below 100 fits (INFERENCE; MCSE about .022 at 100).

## 5. Level-2 variance parametrization experiment (lavaan only)

**What "unconstrained" means here.** The gaps plan says "floor versus unconstrained"; LIT §5.3 item 2 frames the S4
choice as an SLSQP floor versus an unconstrained *parametrization* (log-Cholesky, [Pinheiro1996]). In lavaan the
study can compare only:

- **P0 unconstrained optimization:** lavaan defaults; level-2 variances may go negative (`admissible = FALSE`).
- **P1 floor:** the same model with each level-2 residual variance labeled and bounded below, `v > eps`, in model
  syntax (or `bounds = "pos.var"` if T2 shows it binds at level 2).

A log-Cholesky arm needs OpenMx (`mxAlgebra`) or S4 and is not in this study (**M5**). The proposals file places the
floor side study "once S4 exists" (`PROPOSALS-2026-11-11.md` §2); the lavaan arm is a proxy for that question and
does not settle the native choice. Neither arm changes the adapter: both fits go through `extract_mediation()`.

**Probe (2026-11-16, this machine, 3 replicates per cell; weak evidence).** lavaan 0.7.3, J = 10, n = 5, s = .1:
`bounds = "pos.var"` left 0 of 3 fits admissible (default arm also 0 of 3); the syntax floor (`eps = .001`)
converged 3 of 3 but took a median 5.6 s against 0.40 s by default (about 14 times). At J = 20 and 50 with s = 1 all
arms took 0.24 to 0.28 s.

**Design consequences.** A floored fit passes `post.check` by construction, so its inadmissible rate is not
comparable; P1 reports an **at-bound rate** (any level-2 variance within `10 eps` of `eps`) and a sensitivity
coverage that counts at-bound fits as inadmissible. P1 runs on the same datasets as P0 (paired), delta and MC arms
only, in cells where P0's inadmissible rate exceeds 10% (cutoff **M7**); no P1 bootstrap unless authorized.
Outcomes: paired differences in bias, coverage, SE ratio, failure and at-bound rates, fit time.

## 6. Metrics and failure accounting

Per cell, arm and estimand (P2X §4.4): bias, median relative bias (not where truth is 0), MCSE; SE ratio (median SE
over empirical SD, band [0.9, 1.1]); coverage with MCSE, left and right miss rates; median width; interval
availability. Rates: lavaan error, any lavaan warning, non-convergence, `between_identified = FALSE`,
`admissible = FALSE`, negative level-2 variance (read from the lavaan fit, separately from `post.check`), each adapter
warning class in section 3, bootstrap kept fraction `@n_boot / B`. Coverage twice: **unconditional** (every attempted
dataset; no interval counts as a miss) and **conditional** (converged, identified, admissible). No dataset is
regenerated after a failure (P2X §4.4).

Intervals: delta (`tidy(conf_int = TRUE)`), parametric MC (`bootstrap_mediation(method = "parametric")`,
B = 2000), cluster-bootstrap percentile (`method = "nonparametric", cluster = "id"`, B = 999, or 499 at J <= 20).

## 7. Outputs and what feeds U4

- `tests/sim/twolevel-few-clusters.R` (driver; `MUTANT=` switches) and `tests/sim/twolevel-few-clusters-lib.R`
  (DGP, unequal n, one-refit three-effect closure).
- Results under `planning/studies/few-clusters/` in the layout of `planning/studies/fiml-inference-gates/`: README,
  per-cell CSVs (`cells.csv`, `parametrization.csv`, `bootstrap.csv`), a `sha256` manifest, `sessionInfo.txt`.
  Per-dataset rows (under 1 GB, P2X §5.2) stay outside git; their hashes go in the manifest. Not the `qc-results`
  branch, which holds the monthly QC history (`.github/workflows/qc-monthly.yaml`).
- **The U4 package:** (a) the per-cell table with small-J, low-ICC and unbalanced cells; (b) the P0/P1 comparison;
  (c) evidence on the adapter thresholds (50 clusters, ICC .01 and .05) without changing them; (d) the decision table
  (use / caution / do not fit) with cutoffs fixed before the main run (P2X §4.5 proposes 5% and 20% failure and
  kept/B < .9; these are design choices, not literature: **M8**); (e) a short entry in the gaps plan marking U4 met
  or not.

## 8. Compute budget and where it runs

- Fit time: P2X §5.1 measured 0.09 to 0.15 s per full fit (M5 Pro); this plan's probe measured 0.24 to 0.40 s
  (section 5). Use a x2.5 to x4 sensitivity range on P2X's figures.
- Delta and MC arms, 120 cells x R = 1000: P2X §5.2 gives about 0.9 core-s per dataset, about 30 core-hours; x4 is
  120. P1 on its subset adds roughly the same again at small J (14 times slower fits there).
- Cluster bootstrap on the reduced grid: about 3,200 core-hours (P2X §5.2, a lower bound; low-ICC cost at J >= 30
  unmeasured), 8,000 to 13,000 under the sensitivity range. Laptop: about 2,350 core-hours a week (P2X §5.2).
- **Where:** the pilot (T1 to T5) and the delta/MC arms run locally; the bootstrap arm needs a cluster allocation or
  a cut scope (**M2**). GitHub runners are not used.
- No further timing was run for this plan (about 3 minutes of runtime spent on the probe).

## 9. Seeds and reproducibility

- medfit installed from the `dev` source at a recorded SHA into a scratch library (the installed library holds
  medfit 0.7.0, without the two-level classes); lavaan pinned at 0.7.3; `sessionInfo()` saved with the results.
- Seed per dataset `cell_id * 1e5 + rep`, `RNGkind("L'Ecuyer-CMRG")` for parallel streams; cell ids disjoint from the
  P2X §4.6 mini-pilot so the main study runs on fresh seeds (P2X §2: H1 is tested on fresh seeds).
- Two cells rerun at the end of the campaign must reproduce bit for bit.

## 10. Tasks

| ID | Task | Depends | Verification |
|---|---|---|---|
| T1 | Harness: DGP (equal and unequal n), `s` from target ICC, driver writing one row per dataset and arm | M1 | implied ICC_X, ICC_M match section 4 to 1e-3; the O8 likelihood oracle agrees with lavaan on 3 seeds |
| T2 | Floor mechanics: which level-2 variances `bounds = "pos.var"` and the syntax floor bind; whether a fit at the bound raises a lavaan warning (which would fail every bootstrap refit) | T1 | a planted negative-variance dataset ends at `eps` under P1; warning behavior recorded |
| T3 | Three-effect cluster-bootstrap closure (one refit, three statistics) | T1 | identical to three runs of the shipped `twolevel_statistic()` callback on 20 seeds (exact equality) |
| T4 | Harness QA: planted mutants (truth +.05; delta CI narrowed 20%) and metamorphic rescale (X x 10) | T1, T3 | both mutants move J = 100 coverage outside the band; rescale leaves coverage indicators unchanged |
| T5 | Pilot (P2X §8 scope): delta and MC on all 120 cells at R = 500; bootstrap in 6 cells; P1 in 4 cells | T2 to T4 | go/no-go memo against the stop rules; projected bootstrap cost |
| T6 | Main delta and MC arms, R = 1000, plus P1 on its subset | T5 go, M2 | every cell has R rows; failure rates add up; MCSE reported |
| T7 | Bootstrap arm at the authorized scope | T5 go, M2 | kept fraction per cell; reruns of 2 cells reproduce |
| T8 | Aggregate, decision table, U4 package, README and manifest; update the gaps plan's U4 line | T6, T7 | sha256 manifest verifies; each table row traces to CSV rows |

## 11. Stop rules

- **S1** A planted mutant passes, or the closure differs from the shipped callback (T3, T4): stop, fix the harness.
- **S2** Projected bootstrap cost above 5,000 core-hours without a cluster allocation (P2X §8 go rule 3): run only
  the delta/MC and P1 arms and report the bootstrap arm as not run.
- **S3** Delta coverage of `NIE_B` varies across pilot cells by less than 4 MCSE (P2X §8 go rule 4): write a short
  note instead of a decision table.
- **S4** The study finds an adapter defect (misclassified identification, wrong key rows, a refit that should
  count): stop the campaign, open an issue; fix it in its own PR through the orchestrator, then rerun.
- **S5** T2 shows neither floor binds level-2 variances in lavaan: drop P1, record the finding, keep U4's
  parametrization item open.
- **S6** lavaan or medfit changes mid-campaign: rerun the affected cells or stop.

## 12. Open decisions for the maintainer

- **M1** Authorize the campaign (pilot T1 to T5 first, then T6 to T8 on the go memo).
- **M2** Bootstrap scope and compute: cluster allocation for the reduced grid, or a cut scope (B = 499 everywhere;
  R = 250 at J = 10, n = 5), or no bootstrap arm.
- **M3** Add ICC_X .10 and a near-`icc_error` cell (about .02), or keep three levels.
- **M4** Include the two-mediator reduced cells.
- **M5** Keep the experiment to lavaan default versus floor, or add a log-Cholesky arm through OpenMx.
- **M6** Whether the grid later becomes a registered gate (`gates.csv` and `structures.csv` rows); `gates.csv` is on
  `risk-files.txt`, so that is its own high-risk PR.
- **M7** P1 trigger cutoff (inadmissible rate above 10%) and `eps`.
- **M8** Decision-table cutoffs (failure 5% and 20%, kept/B .9), fixed before T6.
- **M9** Whether the gaps plan's Q8/D-11 wording should be corrected to section 2's reading.
