# T5: pilot go/no-go memo

Plan: `planning/PLAN-few-clusters-design-study-2026-11-16.md`, task T5. Date 2026-11-17.
Environment: R 4.6.2, lavaan 0.7.3, medfit 0.18.0.9000 installed from worktree SHA `1fab2871` into a scratch library
(`sessionInfo.txt`). RNG L'Ecuyer-CMRG, seed `cell_id * 1e5 + rep`. Harness: `tests/sim/twolevel-few-clusters-lib.R`
and `tests/sim/twolevel-few-clusters.R`; tests `tests/testthat/test-twolevel-few-clusters-harness.R` (35 tests,
220 expectations, 0 failed). Outputs: `T5-cells.csv` (one row per cell), `T5-bootstrap-timing.csv` (probe timings and
the per-cell projection inputs), `T5-manifest-sha256.txt` (hashes of the 120 row files, the probes, the scripts and
the snapshot of the harness the runs used). The per-dataset rows stay outside git.

## Scope run

| Arm | Planned (P2X §8) | Run |
|---|---|---|
| Delta and MC (MC B = 2000; corrected 2026-11-23, note below) | all 120 cells, R = 500 | done: 60,000 datasets, 0 lavaan errors |
| Cluster bootstrap | 6 cells (1001, 1002, 1004, 1021, 1022, 1024), R = 300, B = 499 | 6 of 6 done (1024, 1022, 1004, 1002, 1021 locally; 1001 on Hopper, below) |
| Timing probe for S2 | not in P2X | 13 cells at 4 datasets x B = 50, the other 107 at 2 x B = 25 |
| P1 (floor arm) | 4 cells | not run (below) |

Correction note (2026-11-23, T8): this table said "MC B = 1000"; the run used B = 2000 (plan section 6 and the 2026-11-17
decision). Evidence: the T5 manifest records no `MC_B` value, but its snapshot of the driver
(`tests/sim/twolevel-few-clusters.R`, sha256 `3c1b5f36...`, the file at commit `cd243264`) documents "MC_B ... T5 uses
2000", and `T6-manifest-sha256.txt` / the T6 runner use `MC_B = 2000`. Cross-check (INFERENCE; the two runs used
different machines): the median ratio of MC time to fit time per cell is .078 in T5 (`T5-cells.csv`, `mc_s` / `fit_s`)
and .095 in T6 (`T6-cells.csv`, `mc_s_median` / `fit_s_median`, B = 2000), a ratio of 1.10 where B = 1000 in T5 would
give about 2. The T5 cost figure in "T6 and T7 cost" (MC .05 s per dataset) is for B = 2000.

## Verdicts

| Rule | Verdict | Evidence |
|---|---|---|
| S1 mutant passes / closure differs | not fired | T3 and T4 PASS (both mutants caught in all 120 (cell, estimand) pairs); T5 tests pass |
| S2 bootstrap above 5,000 core-h | **fires** | 9,160 core-h at the plan scope, 5,171 at the M2 cut scope |
| S3 NIE_B coverage spread below 4 MCSE | not fired: go | spread .956 against 4 MCSE = .049 |
| S4 adapter defect | not fired on the coded rule | 0 mismatches; ICC-source question for the maintainer (below) |
| S5 neither floor binds | not fired | T2: the syntax floor binds |
| S6 lavaan or medfit changes | not fired | lavaan 0.7.3 and SHA `1fab2871` throughout |

**Decision: go for T6 (delta and MC). No-go for T7 (bootstrap) until M2 is decided**: S2 fires under both the plan
scope and the cut scope, so by the rule the bootstrap arm is reported as not run unless a cluster allocation or a
smaller scope is authorized.

## S2: bootstrap projection

Seconds per bootstrap replicate were measured per cell (`T5-bootstrap-timing.csv`) and multiplied by R x B.

| Scope | Core-h (probe mean) | Core-h (probe max) | ICC .05, J >= 30 | J <= 20 |
|---|---|---|---|---|
| Plan: R = 1000, B = 999 at J >= 30; R = 500, B = 499 at J <= 20 | 9,160 | 11,444 | 4,857 | 2,606 |
| M2 cut: B = 499; R = 250 at J = 10, n = 5 | 5,171 | 6,583 | 2,426 | 1,897 |

Median seconds per replicate (both n and balance pooled; P2X assumed 0.03):

| J | ICC .05 | ICC .20 | ICC .40 |
|---|---|---|---|
| 10 | 2.41 | .77 | .22 |
| 20 | .75 | .25 | .15 |
| 30 | .89 | .15 | .057 |
| 50 | .27 | .086 | .048 |
| 100 | .36 | .062 | .048 |

The P2X lower bound (3,200 core-h) times 2.5 to 4 gives 8,000 to 12,800; the measured 9,160 falls inside that range,
so the x2.5 to x4 factor is already spent and is not applied again to the measured figures. Low-ICC cells dominate:
replicates that land near the boundary iterate longer. At the laptop's about 2,350 core-h a week the plan scope is
about 4 weeks of full use, the cut scope about 2.2.

Caveats: the probes ran under 14 to 18 concurrent processes (times mildly inflated); B = 25 or 50 per dataset is
small; 10 cells had no usable probe dataset (every probe fit failed the adapter: 1031, 1032, 1041, 1042, 1091,
1092, 1093, 1096, 1101, 1106) and are costed at the mean of their (J, n, ICC) slice.

## S3: NIE_B delta coverage

Unconditional coverage (a failed or within-only fit counts as a miss) ranges from .044 to 1.000 across the 120 cells,
spread .956. The median cell MCSE is .0122, so 4 MCSE = .049 (4 sqrt(2) MCSE = .069 for a difference of two cells).
Conditional on an interval existing (115 cells with at least 100 intervals) coverage ranges from .884 to 1.000,
spread .116; the lowest cell (1058, .884, 500 intervals) has MCSE .014 and the highest has MCSE 0, so the spread is
about 8 MCSE of the difference. The largest MCSE of any unconditional coverage is .022. Go for the decision table.

| Estimand | Delta cov. min / median / max | Conditional min / median / max | MC cov. min / median / max |
|---|---|---|---|
| NIE within | .060 / .932 / .966 | .892 / .942 / .980 | .060 / .934 / .964 |
| NIE between | .044 / .918 / 1.000 | .884 / .990 / 1.000 | .044 / .940 / .992 |
| NIE contrast | .044 / .924 / .996 | .898 / .986 / 1.000 | .044 / .939 / .988 |
| c' within | .062 / .936 / .972 | .911 / .948 / .984 | |
| c' between | .044 / .907 / .968 | .870 / .954 / 1.000 | |

The low unconditional minima are failure-driven (unequal n = 5 cells, below), not interval-driven.

## Failure rates

Per-cell rates are in `T5-cells.csv` (`lavaan_error`, `nonconverged`, `adapter_error`, `within_only`,
`inadmissible`, `neg_l2_var`, warnings, `mc_fail_*`). A fit that lavaan reports as not converged is refused by the adapter, so it is counted in `adapter_error`, not in
`nonconverged` (0 in every cell by construction; the S4 check "identified implies converged" is therefore vacuous on
those rows). Summary across cells: lavaan error 0; adapter error median .008,
max .934; within-only median .009, max .572; inadmissible median .044, max .804. 18 cells have adapter error above .2
and 20 cells within-only above .2. Means by J and balance:

| J | Balance | Adapter error | Within-only | Inadmissible | NIE_B coverage |
|---|---|---|---|---|---|
| 10 | equal | .072 | .216 | .440 | .698 |
| 20 | equal | .042 | .141 | .280 | .789 |
| 30 | equal | .030 | .106 | .198 | .837 |
| 50 | equal | .019 | .078 | .141 | .873 |
| 100 | equal | .008 | .047 | .089 | .918 |
| 10 | unequal | .480 | .025 | .098 | .483 |
| 20 | unequal | .242 | .040 | .112 | .695 |
| 30 | unequal | .118 | .051 | .132 | .801 |
| 50 | unequal | .051 | .054 | .108 | .866 |
| 100 | unequal | .012 | .048 | .088 | .911 |

The six bootstrap cells:

| Cell | J | n | ICC | Adapter error | Within-only | Inadmissible | NIE_B cov. | Conditional | MC |
|---|---|---|---|---|---|---|---|---|---|
| 1001 | 10 | 5 | .05 | .176 | .572 | .804 | .252 | 1.000 | .252 |
| 1002 | 20 | 5 | .05 | .152 | .528 | .790 | .320 | 1.000 | .318 |
| 1004 | 50 | 5 | .05 | .088 | .390 | .724 | .518 | .992 | .522 |
| 1021 | 10 | 5 | .40 | .032 | .048 | .294 | .894 | .972 | .914 |
| 1022 | 20 | 5 | .40 | 0 | .006 | .038 | .920 | .926 | .974 |
| 1024 | 50 | 5 | .40 | 0 | 0 | .002 | .934 | .934 | .938 |

**Unequal-cluster non-convergence.** In the unequal n = 5 cells the adapter errors are lavaan non-convergence
("the optimizer warns that a solution has NOT been found"), passed on correctly by the adapter (cell 1031: adapter
error .934, lavaan convergence about .07). Raising `iter.max` to 20000 changed nothing in 20 datasets (convergence .10,
about 119 iterations either way), so this is a stopping condition, not an iteration cap. This is a lavaan or design
finding, not an adapter defect; whether small clusters (size 2) cause it is open.

## S4: identification consistency and the ICC source

On the coded rule (within-only when an ICC is below .01, the between V6 is not PD or finite, or the fit did not
converge; weak warning when identified and an ICC is below .05) there were 0 mismatches over 60,000 datasets.

The shipped `.twolevel_icc()` uses the model-implied ICC; `lavInspect(fit, "icc")` uses the unrestricted (h1) EM
estimate. They stay close when no level-2 variance is negative (largest difference .018) and diverge when one is:
the largest difference is .363. **Correction:** an earlier note in this study said the two sources give the same
values because the model is saturated; that is false on fits with a negative level-2 variance, and only approximate
otherwise. Swapping the source would change the
within-only call in a median .003 and a maximum .300 of datasets per cell, almost all in the direction "shipped
within-only, h1 identified" (max .300; the reverse at most .002). The contract does not say which source applies, so
S4 does not fire; the choice is a new maintainer decision.

## P1

Not run. The plan's T5 row asks for P1 in 4 cells; P2X day 9 schedules the `fixed.x` comparison instead, so the two
documents disagree on what the P1 pilot is. On the M7 trigger (inadmissible rate above 10%), 49 of 120 cells qualify,
so P1 in T6 covers 49 cells at the current cutoff.

## T6 and T7 cost

- T6 delta and MC: measured 13.9 core-h for 60,000 datasets at R = 500 (fit .79 s, MC .05 s per dataset), so about
  28 core-h at R = 1000; 70 to 111 under the x2.5 to x4 range. P1 adds about one more fit per dataset in 49 cells.
- T7 bootstrap: 9,160 core-h (plan scope) or 5,171 (cut scope), measured; both above the S2 limit. Under the x2.5 to
  x4 range: 22,900 to 36,640 (plan) and 12,930 to 20,680 (cut). The measured plan figure already sits inside the P2X
  band (3,200 x 2.5 to 4), so the measured figures are the central estimate and the stacked range an upper bound.

## Bootstrap arm status

The six-cell run (`_agents_workspace/fc-t5/run-boot6.sh`, R = 300, B = 499, 14 cores, order 1024, 1022, 1004, 1002,
1021, 1001) began cell 1024 at about 02:16 on 2026-11-17. Cells 1024, 1022 and 1004 finished (wall 485 s, 2,008 s and
10,562 s, `logs/boot-progress.txt`). A machine restart at about 12:31 stopped it during cell 1002, which wrote no rows.
The rerun resumed at 1002: cells 1002 and 1021 finished (wall 25,764 s and 12,852 s; 1021 ended 2026-11-18 07:13), and
1001 (J = 10, ICC .05) ran locally until 2026-11-18, when it was stopped with no rows written and moved to Hopper:
array 4360586, 30 tasks of 10 replicates (`REP_START`), same seeds `cell_id * 1e5 + rep`, B = 499, lavaan 0.7.3, medfit
from `f3e5e967` (the T6 install). The R version differs (4.4.0 on Hopper, 4.6.2 locally). All 30 tasks completed (the
last ended about 01:13 MST on 2026-11-19; 1 h 41 min to 2 h 51 min per task on 10 cores); the 30 chunks combine to
`rows/boot/cell-1001.csv`, 300 rows, replicates 1 to 300 once each, sha256 `b9ac250f5433382e09d672558a72603afda5b7615d08d0d571b83fbff7e5312f`.
The results below cover all six cells (n = 5, equal clusters). Kept is the mean number of the 499 refits a replicate kept for that effect; coverage is
over the replicates with a percentile interval, with its MCSE; widths are medians, with the delta interval for the
same replicates beside them.

| Cell | J | ICC | Effect | Kept / 499 (min) | Intervals | Coverage (MCSE) | Width: boot / delta |
|---|---|---|---|---|---|---|---|
| 1024 | 50 | .40 | NIE_W | 498.9 (496) | 300 | .943 (.013) | 0.173 / 0.179 |
| 1024 | 50 | .40 | NIE_B | 498.8 (489) | 300 | .943 (.013) | 0.575 / 0.493 |
| 1022 | 20 | .40 | NIE_W | 490.1 (373) | 300 | .900 (.017) | 0.284 / 0.289 |
| 1022 | 20 | .40 | NIE_B | 475.3 (193) | 298 | .997 (.003) | 2.141 / 0.913 |
| 1004 | 50 | .05 | NIE_W | 456.2 (346) | 278 | .950 (.013) | 0.176 / 0.177 |
| 1004 | 50 | .05 | NIE_B | 310.8 (125) | 168 | 1.000 (.000) | 19.91 / 4.068 |
| 1002 | 20 | .05 | NIE_W | 424.8 (282) | 261 | .927 (.016) | 0.276 / 0.290 |
| 1002 | 20 | .05 | NIE_B | 264.1 (81) | 102 | .980 (.014) | 16.87 / 10.97 |
| 1021 | 10 | .40 | NIE_W | 456.0 (317) | 289 | .907 (.017) | 0.393 / 0.407 |
| 1021 | 10 | .40 | NIE_B | 382.8 (110) | 277 | 1.000 (.000) | 7.293 / 1.886 |
| 1001 | 10 | .05 | NIE_W | 413.2 (257) | 248 | .907 (.018) | 0.383 / 0.411 |
| 1001 | 10 | .05 | NIE_B | 239.3 (61) | 79 | .987 (.013) | 11.17 / 9.316 |

The contrast matches NIE_B in kept refits and nearly in coverage (.943, .983, 1.000, .980, 1.000, .987 in table order).
Replicates without a between interval: in 1004, 110 within-only (by design) and 22 adapter errors; in 1002, 159 and 39;
in 1021, 12 and 11; in 1001, 169 and 52. Mean failed refits per replicate: 74.2 in 1002, 43.0 in 1021, 85.8 in 1001.

Reading: at J = 50 and ICC .40 the bootstrap is near nominal for both levels. Where the between level is weak
(J = 20 or 10, or ICC .05) refits are dropped and the between interval is over-wide: coverage near 1 there comes
from width (1.5 to 5 times the delta interval), not accuracy. NIE_W under-covers at J = 20 and 10 (.900, .927, .907, .907).
At ICC .05 and J = 20 (1002) only 102 of 300 replicates give a between interval, and at J = 10 (1001) only 79, so
their .980 and .987 are selected subsets; in 1001 the bootstrap interval is about 1.2 times the delta interval.
These six cells do not change the S2 verdict, which rests on the timing probes; they support the plan's T7 no-go
until M2 is decided.

## Open for the maintainer

1. M2: cluster allocation, the cut scope, or no bootstrap arm (S2 fires either way).
2. ICC source for the identification rule (model-implied, as shipped, or h1). **Decided 2026-11-22: h1** on both
   routes (branch `feature/twolevel-icc-h1`). The lavaan route reads `lavInspect(fit, "icc")`; the native route
   estimates the saturated moments by EM. Accepted consequence: the two routes can differ on the within-only or
   weak call in about 2% of boundary-heavy datasets near the .01 and .05 cuts, because lavaan's default h1 EM stops
   early; documented, with the workaround of tightening lavaan's EM (`em.h1.args = list(tol = 1e-10, max_iter =
   100000L)`).
3. Unequal n = 5 non-convergence: keep the cells, as a finding, or change the design.
4. P1 pilot: the plan/P2X mismatch; M7 at 10% puts 49 cells in P1.
