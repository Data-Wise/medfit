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
| Delta and MC (MC B = 1000) | all 120 cells, R = 500 | done: 60,000 datasets, 0 lavaan errors |
| Cluster bootstrap | 6 cells (1001, 1002, 1004, 1021, 1022, 1024), R = 300, B = 499 | running (below) |
| Timing probe for S2 | not in P2X | 13 cells at 4 datasets x B = 50, the other 107 at 2 x B = 25 |
| P1 (floor arm) | 4 cells | not run (below) |

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
1021, 1001) waited for the delta/MC run and the timing probe to free their cores, began cell 1024 at about 02:16 on
2026-11-17 with 14 workers busy, each dataset taking about 25 s (B = 499 at the probe's .048 s per replicate); projected about 290 core-h, about 20 h
wall. Rows go to `_agents_workspace/fc-t5/rows/boot/`, progress to `logs/boot-progress.txt`, completion to
`logs/boot-done`. Rerunning the script skips finished cells. Its kept fraction and coverage are reported when it
finishes; they do not change the S2 verdict, which rests on the timing probes.

## Open for the maintainer

1. M2: cluster allocation, the cut scope, or no bootstrap arm (S2 fires either way).
2. ICC source for the identification rule (model-implied, as shipped, or h1).
3. Unequal n = 5 non-convergence: keep the cells, as a finding, or change the design.
4. P1 pilot: the plan/P2X mismatch; M7 at 10% puts 49 cells in P1.
