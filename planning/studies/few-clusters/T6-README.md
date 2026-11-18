# T6: main delta and MC run, R = 1000, and P1 on its subset

Task T6 of `planning/PLAN-few-clusters-design-study-2026-11-16.md`, run under the 2026-11-17 decisions (plan section
12): scope S2 (no cluster bootstrap; M2 open, T7 no-go), P1 on the 49 cells whose T5 P0 inadmissible rate exceeds
10% (M7, `eps` = 1e-3), decision-table cutoffs fixed before the run (M8: failure 5% and 20%, kept/B below .9; design
choices, not literature), unequal n = 5 cells kept and their non-convergence reported.

## Files

| File | Role |
|---|---|
| `T6-p1-cells.csv` | P1 cell list (committed; `tests/sim/twolevel-few-clusters-t6-p1.R` regenerates it from `T5-cells.csv`); cell 1106 (T5 rate .102, within one MCSE of the cutoff) is provisional and reported as borderline in T8 |
| `T6-cells.csv` | one row per cell, arm, interval (`delta`, `mc`) and estimand (written after the run) |
| `T6-parametrization.csv` | P0 against P1 on the P1 cells, paired by dataset (written after the run) |
| `T6-manifest-sha256.txt` | hashes of every per-cell row file, the scripts, the outputs and the installed SHA |

Per-dataset rows stay outside git (`_agents_workspace/fc-t6/rows/`, plan section 7).

## Run

```sh
cd <worktree>
REP_START=501 REPS=1000 CORES=10 nohup tests/sim/twolevel-few-clusters-t6.sh > _agents_workspace/fc-t6/logs/run.out 2>&1 &
# replicates 501 to 1500 (the runner's defaults, spelled out)
# resumable: rerun the same command after an interruption; finished cells are skipped
Rscript tests/sim/twolevel-few-clusters-t6-aggregate.R   # after logs/done-R1000 exists
```

The runner's defaults give replicates 501 to 1500 (`REP_START = 501`, `REPS = 1000`); seeds are `cell_id * 1e5 + rep`
(L'Ecuyer-CMRG), so no T6 dataset is a T5 pilot dataset (replicates 1 to 500 chose the P1 cells; plan section 12).
The first launch writes `W/manifest-R<REPS>.txt` (SHA, `rep_start`, `mc_b`, `eps`, medfit and lavaan versions); a
resume with another `REP_START`, `MC_B`, `EPS` or install refuses, and the aggregation reads `rep_start` and the
expected versions from it. To refresh the install, delete `W/lib`: the runner then clears `W/src`, `W/snap`,
`W/install-sha.txt` and `W/snap-sha256.txt` and reinstalls HEAD, and refuses to go on while rows of another SHA
remain.

## Failure categories

Each dataset and arm falls in exactly one of: `lavaan_error`, `nonconverged`, `adapter_error` (a refusal of a
converged fit), `within_only`, `inadmissible`, `clean`. The aggregation stops when a cell is short of R rows or its
categories do not sum to R. `inadmissible_t5` keeps the T5 pilot's overlapping rate for comparison.

## Metrics and MCSE

Coverage counts a missing interval as a miss (MCSE `sqrt(p (1 - p) / R)`); conditional coverage is over clean fits
with an interval and is `NA` below 100 of them; bias MCSE is `sd(est - truth) / sqrt(n_est)`, with
`n_est` the datasets with an estimate; the SE ratio is the
median delta SE over the empirical SD (T5 used the mean); the P0/P1 coverage difference has MCSE
`sd(I_p1 - I_p0) / sqrt(R)`; P1's sensitivity coverage counts an at-bound fit (variance within 10 `eps` of the floor)
as a miss.

The median width and the SE ratio have no MCSE in the tables: plan section 6 attaches MCSE to bias and coverage
only. Both can be computed later from the retained rows.
