# Stage-0 preregistration: FIML interval admission study (DRAFT)

**Status: UNFROZEN DRAFT, 2026-11-08, ready for independent review. Not preregistered, not approved, not
authorized.** Nothing here runs, submits or authorizes a study, a Hopper job, a push, a PR or a release. The
maintainer (Davood) owns scope, budget, freeze and every authorization. Values that the sources do not fix are
listed under "Open decisions for the maintainer" and are marked **[OPEN-n]** where they occur; none was chosen
by this draft.

Sources (all in this repository): `planning/studies/fiml-stage0-hopper/` (README with QA findings, `cells.R`,
`run-chunk.R`, `shared-refits.R`, `parity-check.R`, `check-complete.R`, `stage0.sbatch`, `env-setup.sh`),
`planning/studies/fiml-admission-design/` (README, `power.R`, `power.csv`),
`planning/PLAN-FIML-statistical-admission-2026-11-01.md`,
`planning/PLAN-FIML-stage0-release-guard-2026-11-01.md`,
`planning/GRILL-next-release-FIML-2026-11-07.md` (G1-G8), `planning/studies/fiml-timing-pilot/REPORT.md`.
Where this draft restates a number, it comes from one of these files. Authority for the thresholds is Q8-Q13
of `planning/PLAN-FIML-inference-and-observed-models-2026-10-31.md`, as quoted in the plan above; this draft
does not change them.

## 1. Aims and estimands

**Aim.** Assess interval availability and coverage of the two implemented source-fit interval methods for the
random-X, continuous Gaussian simple mediation model (X -> M -> Y), fitted with FIML
(`fit_sem(..., missing = "fiml", fixed_x = FALSE)`):

- `nonparametric`: row bootstrap of retained rows, B = 999 row refits, type-7 2.5% and 97.5% quantiles; an
  interval is withheld after any required failed refit (strict all-refit rule).
- `parametric`: 20,000 joint Gaussian draws from the fitted covariance, type-7 2.5% and 97.5% quantiles.

**Estimands.** Scalar, unstandardized NIE = a*b, NDE = c, TE = c + a*b, as statistical model effects (no
broader causal claim). The target is **conditional on retaining nonempty records**, at fixed retained sample
size n. Study claims are limited to observed-X, retained-row regimes (maintainer selection, 2026-11-01).

**Decision.** Admit, fail or inconclusive for the complete first stage (Section 5). Admission of stage 0 does
not authorize release, public default changes, broader model claims, or any of the eleven later variants
(Q13; each later variant needs its own implementation, oracles, frozen stage and decision).

## 2. Design: 60 cells, truths, data generation

Data-generating model per retained record: `X ~ N(0,1)`, `M = a X + eM`, `Y = c X + b M + eY`, with `eM`, `eY`
independent standard normal, zero intercepts. Fitted model: `M ~ a*X`, `Y ~ b*M + cp*X` (free direct path) or
`Y ~ b*M + 0*X` (direct path exactly fixed at zero).

Grid (`cells.R`): 2 n x 5 path regimes x 3 missingness regimes x 2 direct-path specifications = **60 cells**.

| Factor | Values |
| --- | --- |
| Retained n | 200, 500 |
| Regime (a, b) | `nonzero` (.4, .4); `b_null` (.4, 0); `a_null` (0, .4); `joint_null` (0, 0); `local` (1/sqrt(n), 1/sqrt(n)) |
| Missingness | `mcar`, `mar`, `empty` |
| Direct path | free, true c = .2; fixed, c = 0 |

Cell index (`expand.grid` order, first factor fastest): `cell = 1 + (n index 0..1) + 2*(regime index 0..4) +
10*(missingness index 0..2) + 30*(direct index: free = 0, fixed = 1)`, with regimes ordered as in the table
and missingness ordered `mcar`, `mar`, `empty`. Cells 1-30 are free-direct, 31-60 fixed-direct. The reviewer
should regenerate the table from `cells.R` rather than trust this formula.

Truths: `truth_nie = a*b`, `truth_nde = c`, `truth_te = c + a*b`, stored per row.

Missingness mechanisms (X always observed; `run-chunk.R` `gen()`):

- **MCAR:** M and Y each independently missing with probability .20.
- **MAR on observed X:** M and Y each independently missing with probability `plogis(log(.2/.8) + .5*X)`;
  marginal rates are not exactly .20.
- **All-empty MCAR (`empty`):** each record is first marked entirely empty with probability .10; otherwise the
  MCAR mechanism applies. Records are collected one at a time until n nonempty records are retained. Both the
  collected and the retained count are recorded. Independent rows and independent whole-row deletion make the
  retention normalization parameter-independent, so the retained full-data distribution is unchanged in this
  cell. This argument is not extended to value-dependent deletion or MNAR. Positivity, identification,
  ignorability and parameter distinctness are to be reviewed explicitly (checklist item R3).

**Regularity classification** (by the true functional gradient, never estimated paths; pending independent
review). The decision family has 360 method/quantity/cell combinations (60 cells x 3 effects x 2 methods):

| Class | Count | Members |
| --- | ---: | --- |
| Regular, gated | 228 | free c: (3 NIE + 5 NDE + 5 TE) x 2 n x 3 mechanisms x 2 methods = 156; fixed c: (3 NIE + 3 TE) x 2 x 3 x 2 = 72 |
| Characterization (reported separately, no new threshold) | 72 | NIE at `joint_null` and `local` (free and fixed c); TE at `joint_null` and `local` (fixed c) |
| Structural zero (contract check) | 60 | NDE in the 30 fixed-direct cells x 2 methods |

Any change to this classification changes the family and requires recalculation and approval.

## 3. Counts, cost and cap (current proposals)

| Quantity | Proposal | Source status |
| --- | --- | --- |
| M, attempted datasets per cell | 2,500 (provisional; 150,000 datasets in total) | design README: "M=2500 remains provisional" |
| B, row refits per dataset | 999 | design README, plan |
| Parameter draws per dataset | 20,000 | design README, plan |
| Methods and effects | both methods x NIE, NDE, TE, one complete stage | maintainer selection, 2026-11-01 |
| Compute venue and cap | UNM CARC Hopper, **250 core-day cap**, full design | GRILL G7 (supersedes G6) |
| Cost control | study-only shared-refit patch (Section 8) | GRILL G8 |
| Estimated cost | about 187-208 core-days (about 2 min per dataset, 1 core) | Hopper README, `stage0.sbatch`, pilot report |

Cost basis: pilot refit calls 101-123 s at B = 999 (mean 114 s over 28 clean calls; not dependent on n), draw
call 3.63 s, clean FIML fit 0.16 s. Without sharing, three refit sets per dataset would cost about 590-600
core-days (over the cap). With sharing, the first effect call took 96 s locally at B = 999 and the other two
about 0.3 s each. Raw volume: 149,850,000 row refits (150,000 datasets x 999) and 3 x 10^9 parameter draws if
one set is shared.

Caveats that a reviewer must weigh: pilot timings are from the local machine (R 4.6.2, source `3826c9ac`); Hopper
(R 4.4.0, another commit and BLAS) is unmeasured. The estimate leaves about 20% under the cap and a core 1.2x
slower breaches it. The pilot did not cover the fixed-zero all-empty cells (pilot cells 11-12 untimed) and one
timing was contaminated by laptop sleep and excluded (85 valid timed units). **[OPEN-5]** (what happens at the
cap).

Execution layout (`stage0.sbatch`): 6,000 tasks = 60 cells x 100 chunks of 25 datasets, one core and 4 GB
each, throttle 96, `--time=02:00:00`, per-task wall-clock budget `STAGE0_BUDGET_S` (default 6,000 s).
Mapping: with T = task id - 1, `cell = T %/% 100 + 1`, datasets `(T %% 100)*25 + 1` to `(T %% 100)*25 + 25`.
`MaxArraySize` must be checked before submission (default 1001 would reject 6,000 tasks).

## 4. Decision gates and power

**Regular decisions (228).** For each, all three gates use one-sided exact 95% binomial lower bounds (Q10):

1. Conditional coverage among returned intervals >= 92.5%.
2. Availability (interval returned) among all attempted datasets >= 95%.
3. Joint usable-and-covering among all attempted datasets >= 90%.

Zero returned intervals cannot pass. An unavailable interval is never counted as covered. At M = 2,500,
availability needs at least 2,394 returned intervals.

**Structural-zero contract (60 NDE decisions).** The availability gate (lower bound >= .95, all attempted
datasets as denominator) applies, and every returned NDE estimate and both interval endpoints must be exactly
zero. A returned nonzero or nonfinite value fails the contract. This is a correctness check for a constant
functional, not an inference claim. (If all returned intervals are exactly zero, the other two gates pass
once availability passes.)

**Characterization (72).** Reported with limitations and Monte Carlo uncertainty; no new numerical threshold,
subject to the correctness hold; no uniform-validity claim.

**Power targets (Q12).** At reference conditional coverage .95 and availability .98: at least .90 per regular
decision and at least .80 for the complete stage. Deterministic results (`power.R`, no model fits):

| M | Per-decision pass probability | 228-decision lower bound |
| ---: | ---: | ---: |
| 500 | .646571 | 0 |
| 1,000 | .929267 | 0 |
| 2,000 | .998245 | .599895 |
| 2,500 | .999766 | .946622 |
| 3,000 | .999970 | .993114 |

Sensitivity at M = 2,500 (per-decision pass probability; not additional high-power guarantees):

| Conditional coverage | availability .97 | .98 | .99 |
| ---: | ---: | ---: | ---: |
| .93 | .086468 | .227319 | .229932 |
| .94 | .637240 | .897183 | .900953 |
| .95 | .983665 | .999766 | .999799 |
| .96 | .999744 | ~1 | ~1 |

With the maintainer's 98% structural-zero availability reference, adding the 60 structural-zero availability
decisions gives a conditional stage lower bound of about .946622 (structural-zero failure probability about
9.21e-13 per decision). This bound assumes completeness, correctness and the review decision pass; it is **not**
an unconditional complete-stage power guarantee and not independent QA sign-off. The union bound needs no
independence across methods, quantities or cells; the per-decision calculation assumes independent datasets and
common category probabilities within a cell, which are assumptions to justify. The reference values
(a = .98, c = .95) are design assumptions, not observed performance. Increasing B may lower availability under
the strict all-refit rule. Q12 is not yet satisfied for the exact frozen stage (**[OPEN-7]**).

## 5. Stage decision rule

- **Admit** only if all 228 regular decisions meet all three gates, the structural-zero contract passes, the
  expected-record and source checks pass, and the characterization results and limitations are reported and
  reviewed.
- **Fail** if any regular gate is unmet or any structural-zero violation occurs (blocks admission).
- **Inconclusive** if evidence is missing, a structural-zero combination returns no interval, a deviation is
  unresolved, or the ledger is incomplete.
- Nothing is pooled away, no cell is dropped, thresholds are not relaxed, and no failed or incomplete cell is
  hidden by aggregation. The maintainer records the stage decision after independent QA.
- If M = 2,500 proves unaffordable, defer admission pending a separately reviewed budget or pre-outcome design
  decision; do not silently weaken thresholds or drop cells.
- If the stage is failed, inconclusive or deferred, source-fit intervals stay out of the release tree and Q13
  keeps expanded-model inference unadmitted (release guard design).

Reported quantities per cell, effect and method, with explicit denominators: bias, interval width, both tail
misses, conditional coverage, availability, joint usable-and-covering, failure probabilities (by category),
Monte Carlo uncertainty, and the three exact lower bounds with pass or fail. Marginal availability averages
over dataset-specific failure probabilities; `(1 - q)^B` is only an IID illustration and availability is not
inferred from pooled refit failure rates.

## 6. Expected-record ledger and completeness

**Unit.** One attempted dataset = one seed in one cell: generate the retained records (up to the collection
cap), fit, then run six interval calls (NIE, NDE, TE x nonparametric, parametric).

**Expected rows.** 60 cells x 2,500 datasets x 3 effects x 2 methods = **900,000 rows**, each key
(cell, dataset, effect, method) exactly once, failures included. Fixed 21-column schema (`run-chunk.R`):
`cell, dataset, seed, effect, method, status, reason, seconds, estimate, lo, hi, requested, successful, failed,
interrupted, unattempted, collected, retained, truth, medfit_commit, fingerprint_sha256`. A dataset-level
failure expands to all six rows with a failure status and a reason; the truth, collected and retained columns
are NA on generation failures (and truth NA on fit failures).

Statuses written by the harness: the inference object's own `status` for a completed call, `error` (call raised),
`fit_failed`, `generation_failed`, `unattempted_budget`. The exact status strings that count as a returned
interval must be enumerated from the pinned source and frozen before the analysis script is written
(prerequisite P7).

**Checker** (`check-complete.R <outdir> 60 2500`): reads every `cell*_*.csv`, reports missing, duplicated and
unexpected keys, requires exactly one `medfit_commit` and one `fingerprint_sha256` across all rows, prints the
method-by-status table, and exits nonzero unless COMPLETE. It distinguishes an incomplete ledger from a complete
one that contains documented failures. It does **not** yet check seeds against the formula, `retained == n`,
truth values, nonfinite or nonzero values in purported successes, count consistency (`requested`, `successful`,
`failed`), or that `unattempted_budget` rows are absent; these are reviewer items (R8) and freeze
prerequisites (P8). An incomplete run supports diagnosis only and cannot receive an admission decision.

## 7. Collection cap, failure and denominator policy

**All-empty collection cap.** The current harness stops collecting an `empty` dataset when `coll >= 10*n`
(**placeholder**; the design README states the cap is unresolved). For scale, under the stated .10 empty
probability, about n / .9 records are expected to be collected per retained dataset, so 10n is far above
expectation. **What a cap hit counts as is [OPEN-3].** The current harness behavior is: raise an error, write
`generation_failed` for all six rows of that dataset (no replacement dataset, no reseed), which keeps it in the
denominator of availability as no returned interval.

**Failure and denominator rules (from the plan; all hold regardless of OPEN-3):**

- Denominator for availability and joint gates: all attempted datasets (2,500 per cell); conditional coverage
  uses returned intervals only.
- A failed required refit withholds the interval (strict rule); an unavailable interval is never coverage.
- Dataset-level failures (generation, FIML fit, call error) stay in the ledger and the attempted denominator.
- No silent retry, no replacement of failures, no reseeding until an interval appears, no optional reruns.
- Per-replicate warnings and failure conditions are recorded (and replayed identically by the shared-refit
  patch, Section 8).
- A budget stop (`unattempted_budget`: the task reached `STAGE0_BUDGET_S`) writes a row for every remaining
  dataset. Its treatment is **[OPEN-4]**. The harness has no per-call timeout or fork-kill; the budget stops
  cleanly only between datasets, so a hung call is not interrupted before the 2 h Slurm limit.

## 8. Shared-refit patch, parity evidence and limits

`shared-refits.R` wraps `medfit:::.bootstrap_fiml_refit` in-process with a cache keyed by
`hash(source@data)` and the hash of the resampled rows, so the NIE, NDE and TE nonparametric calls of one
dataset, which use identical resamples (they depend on seed, B and n only), share one set of refits. A failed
refit's condition is cached and re-signalled, and warnings are replayed on cache hits. The cache is reset
between datasets, and the key omits model, information, `n_starts` and control because those are constant
within a dataset. All six calls of a dataset use bootstrap seed `seed + 5,000,000`. The patch is study-only: it
never enters `R/`, `dev`, `main` or a release branch, and the preregistration names it with the pinned commit.
The guard override (`.fiml_source_inference_admitted` forced to `TRUE`) is likewise in-process and gated on the
fingerprint file; the package source on Hopper stays guarded.

Parity evidence (`parity-check.R`, local): shared run identical to the unpatched run (estimates, intervals,
status, counts, full per-replicate records including warnings) for all three effects in **12 of 12** scenarios
(free and fixed-zero direct x MAR and MCAR fixture x no injection, injected refit failures, injected refit
warnings; B = 40; 6 of 40 failures observed in the injected-failure case); the warning case is asserted
non-vacuous; a planted defect (cache key ignoring the rows) is caught, 0 of 12 identical. Cache size at most
B = 40 entries is asserted. The README review item 1 and GRILL G8 still quote an earlier 8/8; the current
script has 12 scenarios and the README's QA section records 12/12.

Limits: parity was run at B = 40, nonparametric only (parametric makes no refits), on the local machine and not
in the pinned Hopper environment; the patch changes the studied code path; equivalence presumes the refit is a
deterministic function of the resampled rows (no RNG use inside a refit), which the parity run supports only at
B = 40; memory was about 0.5 GB RSS at B = 999 (4 GB requested). The parity re-run in the pinned Hopper
environment is a gating job (P4). Independent QA must also compare the study tree with the guarded candidate
and account for every difference (release-guard design).

## 9. Seed policy

- Confirmatory dataset seed: `7,000,000 + cell*10,000 + dataset` (cells 1-60, datasets 1-2,500), range
  7,010,001 to 7,602,500; unique because dataset < 10,000.
- Bootstrap and draw seed: dataset seed + 5,000,000 (12,010,001 to 12,602,500).
- Pilot seeds 9,100,101 to 9,101,203 are disjoint from both ranges. Pilot and confirmatory streams must be
  disjoint and pilot seeds cannot enter the confirmatory ledger.
- Seeds are fixed by formula before any outcome. No reseeding to obtain an interval. Fresh seeds for the
  remediation round are **[OPEN-2]**.

## 10. Pre-registered remediation round (GRILL G3)

Decided in the grill: **one** pre-registered remediation round, declared before any stage-0 outcome exists,
with fresh seeds, the failed cells kept as evidence, and deferral if the round also fails. "The rule must not
be stretched": no second round, no post-outcome change of the family, labels, thresholds or denominators.
The **remediation method is not decided** and must be declared here before any stage-0 outcome exists
(**[OPEN-1]**, with the trigger definition and cost cap in OPEN-1 and OPEN-2).

## 11. Environment pinning

- R 4.4.0 spack module `r/4.4.0-fyqw` with `gcc/8.5.0-lpgx`; the R module's bundled OpenBLAS (0.3.26, gcc 8.5.0)
  with `OPENBLAS_NUM_THREADS = OMP_NUM_THREADS = 1`; system cmake 3.26.5 for `nloptr`. A second R build
  (`-ytj2`) exists on Hopper; the README flags a BLAS-difference risk, so module hashes must be confirmed.
- Packages from the dated Posit Package Manager snapshot `https://packagemanager.posit.co/cran/2026-11-01`
  (`devtools, S7, checkmate, generics, MASS, nloptr, numDeriv, testthat, withr, rlang`; the script comment says
  the snapshot was verified reachable, while the README still lists "snapshot exists" as open; confirm at setup).
  Versions are recorded in the fingerprint.
- `env-setup.sh <40-char commit>` writes `env-fingerprint.txt` (commit, `module list`, cmake, gcc, kernel,
  `sessionInfo()`, BLAS, installed package versions) and `env-fingerprint.txt.sha256` (overwritten, not
  appended). The source tree is checked out at the pinned commit and must be clean.
- Equality checks: `stage0.sbatch` verifies the sha256, a clean tree including ignored files, and
  `git rev-parse HEAD` equal to the fingerprinted commit; `run-chunk.R` re-checks the commit, requires one-thread
  settings and the fingerprint file, and records commit and fingerprint hash in every row; `check-complete.R`
  requires a single commit and a single fingerprint across all rows.
- The pinned commit must contain the final harness files (the checks compare `HEAD` to the fingerprint), so any
  later edit to the harness or this document's referenced scripts changes the commit and reopens review. The
  commit itself is not yet named (P1).
- Results from a BLAS other than the local OpenBLAS runner need the stated parity check (P4); the pilot used
  R 4.6.2, so cluster timings and numerics are unmeasured on Hopper.

## 12. Out of scope

- The eleven later variants (two covariate, six parallel, three serial), latent or non-Gaussian models,
  standardized effects, value-dependent deletion, MNAR, unobserved-X regimes.
- Any change to `R/`, `tests/`, the release guard, dev or main; releasing or changing public defaults.
- Other timing pilots, screening designs, smaller grids, relaxed thresholds, dropped cells.
- Using this study to infer admission for the guarded release candidate without tree parity.
- Statistical admission of anything beyond the stage-0 decision; CRAN submission (on hold).

## Open decisions for the maintainer

None of these is chosen here. Each must be closed, and the draft edited, before freeze.

| ID | Decision | Options and consequences |
| --- | --- | --- |
| OPEN-1 | Remediation method for the one round (G3) and its trigger | (a) Rerun only failed cells with fresh seeds: cheapest (cost proportional to failed cells), but selective rerun of failures needs a rule that avoids picking favorable outcomes. (b) Rerun the whole stage with fresh seeds: cleanest provenance, about one more full study (187-208 core-days), likely beyond the 250 cap if the cap is total. (c) A pre-specified design or method amendment (for example a different B): addresses a diagnosed cause but changes the studied method, so its power and cost need new review. Also define what counts as a "marginal miss" that triggers it and whether a structural-zero violation or incomplete ledger can trigger it (a correctness failure is arguably not remediable by rerun). |
| OPEN-2 | Cap scope and remediation seeds | Is 250 core-days per study or total across stage 0 and the remediation round, and what is the wall-clock cap (G4 requires one; none is set for Hopper)? Fresh seed block value for the round: must be disjoint from 7,010,001-7,602,500, 12,010,001-12,602,500 and 9,100,101-9,101,203. |
| OPEN-3 | Collection cap value and classification of a cap hit | Cap value (placeholder 10n). A hit may count as (a) generation failure in the attempted denominator, no interval (current harness; conservative, never helps a gate), (b) a design violation making the stage inconclusive, or (c) excluded from the denominator (changes the estimand and is not recommended by the plan, which keeps failures in denominators). |
| OPEN-4 | Treatment of `unattempted_budget` rows | (a) Count as unavailable (conservative, but a time-limit artifact then fails the stage), (b) rerun the same seeds under a pre-stated rule (no new seeds; keeps estimand, costs extra, must be declared as non-retry of failures), (c) treat as an incomplete ledger so the stage is inconclusive until rerun. Related: implement a per-call timeout (not present) and its classification. |
| OPEN-5 | Action at cap or slow-core breach | The estimate leaves about 20% under 250 core-days. Options: stop and record inconclusive; rebudget explicitly (G4); defer. Decide before submission, including whether a timing chunk on Hopper is required first. |
| OPEN-6 | Final M | M = 2,500 is provisional. If affordability or the timing check fails, defer or rebudget through a reviewed pre-outcome decision; no silent reduction. |
| OPEN-7 | Complete-stage power argument | Q12 needs a bound that includes structural-zero, completeness and correctness checks, with dependence handled; the .946622 bound is conditional on those passing and on the 98% reference. The maintainer and independent QA must accept the assumptions or require more. |
| OPEN-8 | Pinned study source | Commit to pin (must include the final harness), and whether the in-process guard override plus shared-refit patch suffices or the release-guard plan's private study-only source with an accounted tree diff is required. |
| OPEN-9 | Environment choices | R module hash (`-fyqw` versus `-ytj2`), confirmation that the 2026-11-01 snapshot is reachable, and whether a Hopper parity re-run at B = 40 is enough or a larger B is required. |
| OPEN-10 | Retention and MAR argument | Acceptance of the retained-row estimand and the .10 empty probability, and the regularity classification (228 / 72 / 60). |

Also resolve before freeze: the README says tasks are about 4 h while `stage0.sbatch` requests 2 h with a
6,000 s budget (the script is the controlling file; the README sentence should be corrected), and the
seeds, statuses and nonfinite checks listed in Section 6.

## Review checklist for the independent reviewer

Independence from the design author (Codex) and the harness author must be recorded with the reviewer's name.

- [ ] R1. Regenerate the 60-cell table from `cells.R`; confirm n, regimes, truths, cell indexing and the 228 / 72 / 60
  split against Section 2.
- [ ] R2. Check the generator against Section 2 (MCAR, MAR formula, empty mechanism, X always observed, zero
  intercepts, `c` handling, fitted model text for fixed c).
- [ ] R3. Review positivity, identification, ignorability, parameter distinctness and the retention argument for
  the `empty` cell, including that only whole-row empties are removed.
- [ ] R4. Reproduce `power.R` independently (critical counts, linked gates with the shared numerator, the table
  values and the 228 + 60 union bound); check boundary cases and that availability >= 2,394 at M = 2,500.
- [ ] R5. Confirm that Q12 (.90 per decision, .80 stage) is or is not met by the exact frozen stage, with the
  dependence argument (OPEN-7).
- [ ] R6. Review the shared-refit patch: cache key completeness, reset between datasets, failure and warning
  replay, same seed for all six calls, no RNG inside refits; re-run `parity-check.R` and its mutant in the pinned
  Hopper environment; plant a second defect (for example a key omitting `source@data`).
- [ ] R7. Compare the study tree with the guarded candidate; account for every difference; confirm out-of-scope
  variants still refuse and the guard override is in-process only.
- [ ] R8. Test `check-complete.R` with planted defects: a missing key, a duplicate, an unexpected key, mixed
  commits, mixed fingerprints, a nonfinite or nonzero NDE success, a wrong seed, `retained != n`, and
  `unattempted_budget` rows; extend it where it is silent (P8).
- [ ] R9. Verify the sbatch arithmetic: 6,000 tasks, cell and dataset mapping covers every (cell, dataset)
  exactly once; throttle, memory, time limit and `MaxArraySize`.
- [ ] R10. Verify environment pinning end to end: module list, snapshot reachability, fingerprint contents,
  sha256 check, commit equality at setup, in the sbatch and in the runner.
- [ ] R11. Check the cost estimate (187-208 core-days), the 250 cap margin and the effect of a 1.2x slower core;
  require one timed chunk on Hopper before any array submission.
- [ ] R12. Check the seed ranges are disjoint from the pilot and from each other, and that the remediation seed
  block, once chosen, is too.
- [ ] R13. Confirm every decision rule (Sections 4-5, 7, 10) is stated before outcomes and that no clause lets
  outcomes change the family, thresholds, cells or denominators.
- [ ] R14. Confirm out-of-scope items and that the pilot's limits (contaminated unit, uncovered cells, R 4.6.2)
  are disclosed and not used to alter the design.
- [ ] R15. Flag any statement here not traceable to a listed source.

## Freeze prerequisites

All must hold before this draft is frozen; freezing does not authorize submission, which is a separate
maintainer approval of the exact files.

- [ ] P1. Pinned study commit named, containing the final harness; no later edits without review.
- [ ] P2. Every OPEN-1 to OPEN-10 closed by the maintainer and this document edited to the final values.
- [ ] P3. Independent QA review of design, power, harness and this draft completed, reviewer and independence
  recorded; findings resolved.
- [ ] P4. `parity-check.R` (and its planted-defect run) passes in the pinned Hopper environment.
- [ ] P5. Environment built by `env-setup.sh`, fingerprint and sha256 recorded, module hashes and snapshot
  confirmed.
- [ ] P6. One chunk timed on Hopper, cost and cap margin re-estimated, `MaxArraySize` checked, and the cap
  action (OPEN-5) set.
- [ ] P7. Exact status strings and the definition of a returned interval enumerated from the pinned source.
- [ ] P8. Checker extended to cover the items in Section 6 and tested with planted defects; the analysis script
  written against the frozen rules and tested on synthetic ledgers with known answers.
- [ ] P9. Source-tree parity with the guarded candidate shown, or the reviewed study-only source prepared
  (OPEN-8); the patch and its hashes preserved.
- [ ] P10. Maintainer approval of this preregistration and budget, with approver, date and scope recorded, and
  separate explicit authorization to run the confirmatory study.
- [ ] P11. Branch state reconciled (the draft files are committed; nothing pushed or merged by this drafting).
